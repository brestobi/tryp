import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const WEBHOOK_SECRET = Deno.env.get("SUSPENSION_WEBHOOK_SECRET");

serve(async (request) => {
  if (request.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (WEBHOOK_SECRET && request.headers.get("x-tryp-suspension-secret") !== WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    if (!RESEND_API_KEY) throw new Error("RESEND_API_KEY is not configured.");
    const payload = await request.json() as { email?: string; name?: string; reason?: string; role?: string };
    if (!payload.email) throw new Error("email is required.");

    const reason = payload.reason?.trim() || "Your account has been suspended pending review.";
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify({
        from: "TRYP <noreply@updates.illdoit.space>",
        reply_to: "support@illdoit.space",
        to: [payload.email],
        subject: "TRYP account suspended",
        html: `<div style="font-family:Arial,sans-serif;max-width:560px;margin:32px auto;color:#111"><h1>TRYP account suspended</h1><p>Hello ${String(payload.name ?? "there")},</p><p>Your ${payload.role ?? "TRYP"} account has been suspended.</p><p><strong>Reason:</strong> ${reason}</p><p>Please contact support if you believe this was a mistake.</p></div>`,
      }),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(`Resend API error: ${JSON.stringify(result)}`);
    return new Response(JSON.stringify({ success: true }), { headers: { "Content-Type": "application/json" } });
  } catch (error) {
    console.error("[notify-account-suspension]", error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
