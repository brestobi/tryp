import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GetObjectCommand, S3Client } from "https://esm.sh/@aws-sdk/client-s3@3.873.0";
import { getSignedUrl } from "https://esm.sh/@aws-sdk/s3-request-presigner@3.873.0";

const endpoint = Deno.env.get("R2_ENDPOINT") ?? "https://01867980af2a323a01f48976d38894ea.r2.cloudflarestorage.com";
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
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method Not Allowed" }, 405);

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: request.headers.get("Authorization") ?? "" } } },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return json({ error: "Unauthorized" }, 401);

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("role, admin_role")
      .eq("id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;

    const payload = await request.json() as { objectKey?: string };
    const objectKey = payload.objectKey;
    if (!objectKey || objectKey.includes("..") || objectKey.startsWith("/")) {
      return json({ error: "Invalid object key" }, 400);
    }

    const isAdmin = profile?.role === "admin" || profile?.role === "super_admin";
    const ownsObject = objectKey.startsWith(`drivers/${user.id}/`) || objectKey.startsWith(`passengers/${user.id}/`);
    if (!isAdmin && !ownsObject) return json({ error: "Forbidden" }, 403);

    const downloadUrl = await getSignedUrl(r2, new GetObjectCommand({ Bucket: bucket, Key: objectKey }), { expiresIn: 600 });
    return json({ downloadUrl, expiresIn: 600 });
  } catch (error) {
    console.error("[create-r2-download]", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
