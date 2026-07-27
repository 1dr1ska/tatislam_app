// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts";
import { AwsClient } from "aws4fetch";

console.log("delete-media function started");

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getYandexConfig(): Record<string, string> | { error: string } {
  const accessKey = Deno.env.get("YANDEX_ACCESS_KEY");
  const secretKey = Deno.env.get("YANDEX_SECRET_KEY");
  const bucket = Deno.env.get("YANDEX_BUCKET");
  const region = Deno.env.get("YANDEX_REGION");
  const endpoint = Deno.env.get("YANDEX_ENDPOINT");

  if (!accessKey || !secretKey || !bucket || !region || !endpoint) {
    return { error: "Missing Yandex Object Storage configuration" };
  }

  return { accessKey, secretKey, bucket, region, endpoint };
}

function decodeJWT(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = parts[1];
    const decoded = atob(payload.replace(/-/g, "+").replace(/_/g, "/"));
    return JSON.parse(decoded);
  } catch {
    return null;
  }
}

async function fetchUserRole(userId: string, userJwt: string): Promise<string | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !anonKey) return null;

  const response = await fetch(
    `${supabaseUrl}/rest/v1/profiles?select=role&id=eq.${userId}`,
    {
      headers: {
        "apikey": anonKey,
        "Authorization": `Bearer ${userJwt}`,
        "Content-Type": "application/json",
      },
    }
  );

  if (!response.ok) {
    console.error(`[delete-media] Failed to fetch profile: status=${response.status}`);
    return null;
  }

  const data = await response.json();
  if (!Array.isArray(data) || data.length === 0) return null;

  return data[0].role ?? null;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  try {
    // ---- 1. Extract and validate JWT -------------------------------------
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return Response.json({ error: "Authentication required" }, { status: 401 });
    }

    const token = authHeader.slice(7);
    const payload = decodeJWT(token);
    if (!payload || !payload.sub) {
      return Response.json({ error: "Authentication required" }, { status: 401 });
    }

    const userId = payload.sub as string;
    console.log(`[delete-media] Request started. user_id=${userId}`);

    // ---- 2. Admin check --------------------------------------------------
    const role = await fetchUserRole(userId, token);
    if (!role) {
      console.error(`[delete-media] Failed to fetch profile for user ${userId}`);
      return Response.json({ error: "Forbidden" }, { status: 403 });
    }

    if (role !== "admin") {
      console.warn(`[delete-media] Non-admin user ${userId} attempted delete`);
      return Response.json({ error: "Forbidden" }, { status: 403 });
    }

    console.log(`[delete-media] Admin check passed for user ${userId}`);

    // ---- 3. Parse request body -------------------------------------------
    let body: { key?: string };
    try {
      body = await req.json();
    } catch {
      return Response.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const key = body.key;
    if (!key || typeof key !== "string") {
      return Response.json(
        { error: "Missing or invalid 'key' field. Expected a string." },
        { status: 400 }
      );
    }

    console.log(`[delete-media] Request to delete key: ${key}`);

    // ---- 4. Read Yandex config -------------------------------------------
    const config = getYandexConfig();
    if ("error" in config) {
      console.error("[delete-media] Missing Yandex configuration");
      return Response.json({ error: "Server configuration error" }, { status: 500 });
    }

    const { accessKey, secretKey, bucket, region, endpoint } = config;

    // ---- 5. Delete from Yandex Object Storage via S3 API ------------------
    const aws = new AwsClient({
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
      region,
      service: "s3",
    });

    console.log(`[delete-media] Starting S3 delete: bucket=${bucket}, key=${key}`);

    const response = await aws.fetch(
      `${endpoint}/${bucket}/${key}`,
      {
        method: "DELETE",
      }
    );

    // S3 returns 204 No Content on successful delete
    // If the object doesn't exist, S3 returns 204 as well (idempotent)
    if (response.status === 204 || response.status === 404) {
      console.log(`[delete-media] Delete successful: key=${key}, s3_status=${response.status}`);
      return Response.json({ deleted: true }, { status: 200 });
    }

    // Any other status is an error
    const errorText = await response.text();
    console.error(`[delete-media] S3 delete failed: status=${response.status}, body=${errorText}`);
    return Response.json(
      { error: `Failed to delete file: ${response.statusText}` },
      { status: 500 }
    );
  } catch (error) {
    console.error("[delete-media] Unexpected error:", error);
    return Response.json(
      { error: error instanceof Error ? error.message : "Internal server error" },
      { status: 500 }
    );
  }
});