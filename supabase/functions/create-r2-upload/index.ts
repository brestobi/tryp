import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { S3Client, PutObjectCommand } from "https://esm.sh/@aws-sdk/client-s3@3.873.0";
import { getSignedUrl } from "https://esm.sh/@aws-sdk/s3-request-presigner@3.873.0";

const endpoint = Deno.env.get("R2_ENDPOINT") ?? `https://${Deno.env.get("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com`;
const bucket = Deno.env.get("R2_BUCKET_NAME") ?? "tryp";
const r2 = new S3Client({
  region: "auto",
  endpoint,
  credentials: {
    accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID") ?? "",
    secretAccessKey: Deno.env.get("R2_SECRET_ACCESS_KEY") ?? "",
  },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method Not Allowed" }, 405);

  try {
    if (!Deno.env.get("R2_ACCESS_KEY_ID") || !Deno.env.get("R2_SECRET_ACCESS_KEY")) {
      return json({ error: "R2 credentials are not configured." }, 500);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: request.headers.get("Authorization") ?? "" } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "Unauthorized" }, 401);

    const payload = await request.json() as {
      kind?: string;
      fileName?: string;
      contentType?: string;
      folder?: string;
    };
    const kind = (payload.kind ?? "document").replace(/[^a-zA-Z0-9_-]/g, "_");
    const fileName = (payload.fileName ?? "upload").split(/[\\/]/).pop()!.replace(/[^a-zA-Z0-9._-]/g, "_");
    const contentType = payload.contentType ?? "application/octet-stream";
    const folder = (payload.folder ?? "documents").replace(/[^a-zA-Z0-9_-]/g, "_");
    const objectKey = `${folder}/${user.id}/${kind}_${crypto.randomUUID()}_${fileName}`;

    const uploadUrl = await getSignedUrl(r2, new PutObjectCommand({
      Bucket: bucket,
      Key: objectKey,
      ContentType: contentType,
    }), { expiresIn: 600 });

    return json({ uploadUrl, objectKey, expiresIn: 600 });
  } catch (error) {
    console.error("[create-r2-upload]", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
