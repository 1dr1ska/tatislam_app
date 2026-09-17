// =============================================================================
// notify-new-publication — push-уведомление при ПЕРВОЙ ПУБЛИКАЦИИ.
//
// Вызывается после успешного сохранения публикации в статусе "published":
//   - импортёром (сразу после INSERT, PUBLICATION_STATUS=published по умолчанию);
//   - админ-редактором приложения (PublicationSaveJob) — при создании
//     опубликованной публикации или переходе черновик → опубликовано;
//   POST {SUPABASE_URL}/functions/v1/notify-new-publication
//   Authorization: Bearer <project JWT: anon или service_role>
//   body: { "publication_id": "uuid" }
//
// Семантика «первая публикация» и идемпотентность:
//   1. Если публикация ещё НЕ в статусе published (черновик) — функция
//      возвращает skipped, ничего не резервируя. Уведомление уйдёт при первом
//      вызове уже после публикации.
//   2. При published вызывается RPC claim_publication_notification(): строка в
//      publication_notifications вставляется ON CONFLICT (publication_id)
//      DO NOTHING. Только первый вызов отправляет push; повторные возвращают
//      duplicate (даже если импортёр/редактор случайно вызовутся дважды).
//   3. Сама публикация не дублируется при повторном импорте — уникальный
//      индекс publications.telegram_message_id (миграция 0027).
//
// Credentials Firebase НЕ живут в приложении и НЕ коммитятся в Git:
//   А. service account JSON лежит в секрете Edge Function
//      FIREBASE_SERVICE_ACCOUNT_JSON (Dashboard → Edge Functions → Secrets);
//   Б. отправка идёт по протоколу FCM HTTP v1 (не legacy /fcm/send).
// =============================================================================

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const SERVICE_ACCOUNT_SECRET = "FIREBASE_SERVICE_ACCOUNT_JSON";

const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";
const FIREBASE_MESSAGING_SCOPE =
  "https://www.googleapis.com/auth/firebase.messaging";
const FCM_V1_BASE_URL = "https://fcm.googleapis.com/v1/projects";

// Текст уведомления. Можно переопределить через секреты Edge Function
// (NOTIFICATION_TITLE, NOTIFICATION_BODY_PREFIX).
const DEFAULT_NOTIFICATION_TITLE = "Новая публикация";
const DEFAULT_NOTIFICATION_BODY_PREFIX =
  "В приложение добавлена новая публикация: ";

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function supabaseFetch(
  supabaseUrl: string,
  serviceKey: string,
  path: string,
  init: RequestInit = {}
): Promise<Response> {
  const headers: Record<string, string> = {
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
    "Content-Type": "application/json",
    ...(init.headers as Record<string, string> | undefined),
  };
  return fetch(`${supabaseUrl}${path}`, { ...init, headers });
}
// ---------------------------------------------------------------------------
// FCM HTTP v1 — OAuth2 через service account (JWT RS256, Web Crypto)
// ---------------------------------------------------------------------------

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64UrlDecode(input: string): Uint8Array {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function parseServiceAccount(raw: string): {
  clientEmail: string;
  privateKey: string;
  projectId: string;
} {
  const json = JSON.parse(raw);
  if (!json.client_email || !json.private_key || !json.project_id) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_JSON must contain client_email, private_key and project_id"
    );
  }
  return {
    clientEmail: json.client_email,
    privateKey: json.private_key,
    projectId: json.project_id,
  };
}

async function signRsaSha256(
  data: Uint8Array,
  privateKeyPem: string
): Promise<Uint8Array> {
  const pemBody = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyData = base64UrlDecode(
    pemBody.replace(/-/g, "+").replace(/_/g, "/")
  );

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, data);
  return new Uint8Array(signature);
}

async function getAccessToken(serviceAccount: {
  clientEmail: string;
  privateKey: string;
  projectId: string;
}): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.clientEmail,
    scope: FIREBASE_MESSAGING_SCOPE,
    aud: OAUTH_TOKEN_URL,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };

  const signingInput =
    `${base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)))}.` +
    base64UrlEncode(new TextEncoder().encode(JSON.stringify(claims)));

  const signature = await signRsaSha256(
    new TextEncoder().encode(signingInput),
    serviceAccount.privateKey
  );
  const assertion = `${signingInput}.${base64UrlEncode(signature)}`;

  const form = new URLSearchParams();
  form.set("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer");
  form.set("assertion", assertion);

  const response = await fetch(OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form,
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OAuth token failed (${response.status}): ${text}`);
  }
  const data = await response.json();
  if (!data.access_token) {
    throw new Error("OAuth token response contains no access_token");
  }
  return data.access_token;
}

async function sendFcmV1(
  accessToken: string,
  projectId: string,
  message: Record<string, unknown>
): Promise<{ ok: boolean; status?: string; detail?: string }> {
  const response = await fetch(`${FCM_V1_BASE_URL}/${projectId}/messages:send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });

  if (response.ok) {
    return { ok: true };
  }
  // FCM v1 error body: { "error": { "status": "UNREGISTERED", ... } }
  let status: string | undefined;
  let detail: string | undefined;
  try {
    const body = await response.json();
    status = body?.error?.status;
    detail = body?.error?.message ?? JSON.stringify(body);
  } catch {
    detail = await response.text();
  }
  return { ok: false, status, detail };
}
// ---------------------------------------------------------------------------
// Supabase data access (service_role bypasses RLS)
// ---------------------------------------------------------------------------

async function claimPublication(
  supabaseUrl: string,
  serviceKey: string,
  publicationId: string
): Promise<boolean> {
  const response = await supabaseFetch(
    supabaseUrl,
    serviceKey,
    "/rest/v1/rpc/claim_publication_notification",
    {
      method: "POST",
      body: JSON.stringify({ p_publication_id: publicationId }),
    }
  );
  if (!response.ok) {
    throw new Error(`claim RPC failed (${response.status}): ${await response.text()}`);
  }
  return await response.json();
}

async function fetchPublication(
  supabaseUrl: string,
  serviceKey: string,
  publicationId: string
): Promise<{ title: string; type: string; status: string | null } | null> {
  const encoded = encodeURIComponent(publicationId);
  const response = await supabaseFetch(
    supabaseUrl,
    serviceKey,
    `/rest/v1/publications?id=eq.${encoded}&select=id,title,type,status`
  );
  if (!response.ok) {
    throw new Error(`publications fetch failed (${response.status}): ${await response.text()}`);
  }
  const rows = await response.json();
  return Array.isArray(rows) && rows.length > 0
    ? {
        title: rows[0].title ?? "",
        type: rows[0].type ?? "article",
        status: rows[0].status ?? null,
      }
    : null;
}

async function fetchActiveTokens(
  supabaseUrl: string,
  serviceKey: string
): Promise<string[]> {
  const response = await supabaseFetch(
    supabaseUrl,
    serviceKey,
    "/rest/v1/notification_devices?is_active=eq.true&select=fcm_token"
  );
  if (!response.ok) {
    throw new Error(
      `notification_devices fetch failed (${response.status}): ${await response.text()}`
    );
  }
  const rows = await response.json();
  return Array.isArray(rows) ? rows.map((row) => row.fcm_token as string) : [];
}

async function deactivateTokens(
  supabaseUrl: string,
  serviceKey: string,
  tokens: string[]
): Promise<void> {
  for (const token of tokens) {
    try {
      await supabaseFetch(
        supabaseUrl,
        serviceKey,
        `/rest/v1/notification_devices?fcm_token=eq.${encodeURIComponent(token)}`,
        {
          method: "PATCH",
          body: JSON.stringify({ is_active: false }),
        }
      );
    } catch (error) {
      // Лучше не ронять рассылку из-за одной невалидной записи.
      console.error(`[notify-new-publication] deactivate failed for token`, error);
    }
  }
}

async function setNotificationStatus(
  supabaseUrl: string,
  serviceKey: string,
  publicationId: string,
  status: "sent" | "failed",
  lastError: string | null = null,
  attempts = 1
): Promise<void> {
  await supabaseFetch(
    supabaseUrl,
    serviceKey,
    `/rest/v1/publication_notifications?publication_id=eq.${encodeURIComponent(publicationId)}`,
    {
      method: "PATCH",
      body: JSON.stringify({ status, last_error: lastError, attempts }),
    }
  );
}
// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const serviceAccountRaw = Deno.env.get(SERVICE_ACCOUNT_SECRET);

  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "Server misconfigured" }, 500);
  }
  if (!serviceAccountRaw) {
    return jsonResponse(
      {
        error:
          "FIREBASE_SERVICE_ACCOUNT_JSON secret is not set for this Edge Function",
      },
      500
    );
  }

  try {
    const body = await req.json();
    const publicationId = body?.publication_id;
    if (typeof publicationId !== "string" || publicationId.length === 0) {
      return jsonResponse({ error: "publication_id is required" }, 400);
    }

    // ---- 1. Публикация должна быть действительно опубликована. --------------
    // Статус проверяется ДО claim: создание со статусом draft (вспомогательный)
    // не «сжигает» право на уведомление — push уйдёт при первом переходе в
    // published (создание сразу опубликованным или черновик → опубликовано).
    const publication = await fetchPublication(
      supabaseUrl,
      serviceKey,
      publicationId
    );
    if (!publication) {
      return jsonResponse({ ok: false, error: "publication_not_found" }, 404);
    }

    if (publication.status !== "published") {
      // Черновик/архив: не рассылаем и НЕ резервируем уведомление — поздний
      // вызов (после публикации) сможет отправить его.
      return jsonResponse(
        { ok: true, skipped: true, reason: `status=${publication.status}` },
        200
      );
    }

    // ---- 2. Идемпотентный «замок»: только первый вызов для этой публикации
    // отправляет push, повторные возвращают duplicate. ------------------------
    const claimed = await claimPublication(
      supabaseUrl,
      serviceKey,
      publicationId
    );
    if (!claimed) {
      return jsonResponse(
        { ok: true, duplicate: true, message: "already_notified" },
        200
      );
    }

    // ---- 3. Получатели. -----------------------------------------------------
    const tokens = await fetchActiveTokens(supabaseUrl, serviceKey);
    if (tokens.length === 0) {
      await setNotificationStatus(supabaseUrl, serviceKey, publicationId, "sent");
      return jsonResponse({ ok: true, sent: 0 }, 200);
    }

    // ---- 4. Отправка через FCM HTTP v1. ------------------------------------
    const serviceAccount = parseServiceAccount(serviceAccountRaw);
    const accessToken = await getAccessToken(serviceAccount);

    const title =
      Deno.env.get("NOTIFICATION_TITLE") ?? DEFAULT_NOTIFICATION_TITLE;
    const bodyPrefix =
      Deno.env.get("NOTIFICATION_BODY_PREFIX") ?? DEFAULT_NOTIFICATION_BODY_PREFIX;

    let sent = 0;
    const invalidTokens: string[] = [];
    let lastError: string | null = null;

    for (const token of tokens) {
      const message = {
        token,
        notification: {
          title,
          body: `${bodyPrefix}${publication.title}`,
        },
        data: {
          type: "new_publication",
          publication_id: publicationId,
          publication_type: publication.type,
          publication_title: publication.title,
        },
        android: {
          priority: "HIGH",
        },
      };

      const result = await sendFcmV1(accessToken, serviceAccount.projectId, message);
      if (result.ok) {
        sent++;
      } else if (
        result.status === "UNREGISTERED" ||
        result.status === "NOT_FOUND" ||
        result.status === "INVALID_ARGUMENT"
      ) {
        // Токен больше невалиден — выключаем устройство (требование backend).
        console.warn(
          `[notify-new-publication] deactivating invalid token (${result.status})`
        );
        invalidTokens.push(token);
        lastError = result.status;
      } else {
        console.error(
          `[notify-new-publication] send failed: status=${result.status ?? "unknown"} detail=${result.detail ?? ""}`
        );
        lastError = `${result.status ?? "unknown"}: ${result.detail ?? ""}`;
      }
    }

    if (invalidTokens.length > 0) {
      await deactivateTokens(supabaseUrl, serviceKey, invalidTokens);
    }

    await setNotificationStatus(
      supabaseUrl,
      serviceKey,
      publicationId,
      "sent",
      lastError,
      1
    );

    return jsonResponse({ ok: true, sent, invalid: invalidTokens.length }, 200);
  } catch (error) {
    console.error("[notify-new-publication] unexpected error:", error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : "internal error" },
      500
    );
  }
});