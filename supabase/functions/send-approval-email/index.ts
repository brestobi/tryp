import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const FROM_EMAIL = "noreply@updates.illdoit.space";
const SUPPORT_EMAIL = "support@illdoit.space";

function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

serve(async (request: Request) => {
  if (request.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  try {
    if (!RESEND_API_KEY) throw new Error("RESEND_API_KEY is not configured.");
    const expectedSecret = Deno.env.get("APPROVAL_EMAIL_WEBHOOK_SECRET");
    if (expectedSecret && request.headers.get("x-tryp-approval-secret") !== expectedSecret) {
      return new Response("Unauthorized", { status: 401 });
    }
    const payload = await request.json() as {
      email?: string;
      name?: string;
      accountType?: "driver" | "passenger";
    };
    if (!payload.email) throw new Error("email is required.");

    const isDriver = payload.accountType === "driver";
    const name = escapeHtml(payload.name || "there");
    const heading = isDriver ? "Your driver account is approved" : "Your identity verification is approved";
    const message = isDriver
      ? "Your TRYP driver account has been approved. You can now go online and start accepting rides."
      : "Your TRYP identity verification has been approved. You can now request rides.";

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: `TRYP <${FROM_EMAIL}>`,
        reply_to: SUPPORT_EMAIL,
        to: [payload.email],
        subject: `TRYP · ${isDriver ? "Account approved" : "Verification approved"}`,
        html: `<!doctype html><html><body style="margin:0;background:#f4f4f5;font-family:Arial,sans-serif;color:#111"><div style="max-width:560px;margin:32px auto;background:#fff;border-radius:20px;overflow:hidden"><div style="padding:28px 32px;background:#111;color:#ffd400;font-size:24px;font-weight:900;letter-spacing:3px">TRYP</div><div style="padding:32px"><h1 style="margin:0 0 16px;font-size:26px">${heading}</h1><p style="font-size:16px;line-height:1.6">Hi ${name},</p><p style="font-size:16px;line-height:1.6">${message}</p><div style="margin-top:24px;padding:16px;border-radius:12px;background:#ffd400;font-weight:700">Approved</div><p style="margin-top:24px;color:#777;font-size:13px">If you need help, contact ${SUPPORT_EMAIL}.</p></div></div></body></html>`,
      }),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(`Resend API error: ${JSON.stringify(result)}`);

    return new Response(JSON.stringify({ success: true, id: result.id }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[send-approval-email] Error:", error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
