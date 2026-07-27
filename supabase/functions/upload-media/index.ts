// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts";
import { AwsClient } from "aws4fetch";

console.log("upload-media function started");

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const ALLOWED_FOLDERS = ["images", "audio", "videos"] as const;

const FOLDER_SIZE_LIMITS: Record<string, number> = {
  images: 20 * 1024 * 1024,   // 20 MB
  audio: 200 * 1024 * 1024,   // 200 MB
  videos: 100 * 1024 * 1024,  // 100 MB
};

const FOLDER_MIME_PREFIXES: Record<string, string> = {
  images: "image/",
  audio: "audio/",
  videos: "video/",
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getExtension(filename: string): string {
  const dotIndex = filename.lastIndexOf(".");
  if (dotIndex === -1) return "";
  return filename.slice(dotIndex);
}

function validateFolder(folder: string | null): string | null {
  if (!folder || !ALLOWED_FOLDERS.includes(folder as typeof ALLOWED_FOLDERS[number])) {
    return null;
  }
  return folder;
}

function validateFileSize(folder: string, size: number): string | null {
  const limit = FOLDER_SIZE_LIMITS[folder];
  if (size > limit) {
    const mb = (limit / (1024 * 1024)).toFixed(0);
    return `File size exceeds the ${mb} MB limit for '${folder}' folder`;
  }
  return null;
}

function validateMimeType(folder: string, mimeType: string): string | null {
  const expectedPrefix = FOLDER_MIME_PREFIXES[folder];
  if (!mimeType.startsWith(expectedPrefix)) {
    return `Invalid file type '${mimeType}' for '${folder}' folder. Expected ${expectedPrefix}*`;
  }
  return null;
}

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
    console.error(`[upload-media] Failed to fetch profile: status=${response.status}`);
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
  const startTime = Date.now();

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
    console.log(`[upload-media] Request started. user_id=${userId}`);

    // ---- 2. Admin check --------------------------------------------------
    const role = await fetchUserRole(userId, token);
    if (!role) {
      console.error(`[upload-media] Failed to fetch profile for user ${userId}`);
      return Response.json({ error: "Forbidden" }, { status: 403 });
    }

    if (role !== "admin") {
      console.warn(`[upload-media] Non-admin user ${userId} attempted upload`);
      return Response.json({ error: "Forbidden" }, { status: 403 });
    }

    console.log(`[upload-media] Admin check passed for user ${userId}`);

    // ---- 3. Parse folder from query params --------------------------------
    const url = new URL(req.url);
    const folder = validateFolder(url.searchParams.get("folder"));

    if (!folder) {
      return Response.json(
        { error: `Invalid or missing 'folder' parameter. Allowed: ${ALLOWED_FOLDERS.join(", ")}` },
        { status: 400 }
      );
    }

    // ---- 4. Parse multipart form data -------------------------------------
    const formData = await req.formData();
    const file = formData.get("file");

    if (!file || !(file instanceof File)) {
      return Response.json(
        { error: "Missing 'file' field in form data" },
        { status: 400 }
      );
    }

    console.log(`[upload-media] Received file: folder=${folder}, size=${file.size}, type=${file.type}, original_name=${file.name}`);

    // ---- 5. Validate file size --------------------------------------------
    const sizeError = validateFileSize(folder, file.size);
    if (sizeError) {
      console.warn(`[upload-media] Size limit exceeded: user=${userId}, folder=${folder}, size=${file.size}`);
      return Response.json({ error: sizeError }, { status: 413 });
    }

    // ---- 6. Validate MIME type --------------------------------------------
    const mimeType = file.type;
    if (!mimeType) {
      console.warn(`[upload-media] Missing Content-Type: user=${userId}, folder=${folder}, file=${file.name}`);
      return Response.json(
        { error: "File must have a Content-Type (MIME type)" },
        { status: 400 }
      );
    }
    const mimeError = validateMimeType(folder, mimeType);
    if (mimeError) {
      console.warn(`[upload-media] Invalid MIME type: user=${userId}, folder=${folder}, type=${mimeType}`);
      return Response.json({ error: mimeError }, { status: 400 });
    }

    // ---- 7. Read Yandex config --------------------------------------------
    const config = getYandexConfig();
    if ("error" in config) {
      console.error("[upload-media] Missing Yandex configuration");
      return Response.json({ error: "Server configuration error" }, { status: 500 });
    }

    const { accessKey, secretKey, bucket, region, endpoint } = config;

    // ---- 8. Generate unique key -------------------------------------------
    const ext = getExtension(file.name);
    const uuid = crypto.randomUUID();
    const key = `${folder}/${uuid}${ext}`;

    console.log(`[upload-media] Generated key: ${key}`);

    // ---- 9. Upload to Yandex Object Storage via S3 API --------------------
    const aws = new AwsClient({
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
      region,
      service: "s3",
    });

    const fileBuffer = await file.arrayBuffer();

    console.log(`[upload-media] Starting S3 upload: bucket=${bucket}, key=${key}, size=${fileBuffer.byteLength}`);

    const response = await aws.fetch(
      `${endpoint}/${bucket}/${key}`,
      {
        method: "PUT",
        headers: {
          "Content-Type": mimeType,
          "x-amz-acl": "public-read",
        },
        body: fileBuffer,
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`[upload-media] S3 upload failed: status=${response.status}, body=${errorText}`);
      return Response.json(
        { error: `Failed to upload file: ${response.statusText}` },
        { status: 500 }
      );
    }

    // ---- 10. Build response -----------------------------------------------
    const publicUrl = `${endpoint}/${bucket}/${key}`;
    const elapsed = Date.now() - startTime;

    console.log(`[upload-media] Upload successful: user=${userId}, key=${key}, size=${file.size}, duration=${elapsed}ms`);

    return Response.json(
      {
        url: publicUrl,
        key,
        size: file.size,
        contentType: mimeType,
      },
      { status: 201 }
    );
  } catch (error) {
    console.error("[upload-media] Unexpected error:", error);
    return Response.json(
      { error: error instanceof Error ? error.message : "Internal server error" },
      { status: 500 }
    );
  }
});