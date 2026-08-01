import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const FROM_EMAIL = "onboarding@tryp.app";
const FROM_NAME = "TRYP";

interface WelcomePayload {
  type: "INSERT";
  table: string;
  record: {
    id: string;
    email: string;
    raw_user_meta_data?: {
      full_name?: string;
      role?: string;
    };
  };
}

function buildWelcomeEmail(fullName: string, email: string): string {
  const firstName = fullName?.split(" ")[0] || "there";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Welcome to TRYP</title>
</head>
<body style="margin:0;padding:0;background-color:#f4f4f5;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f5;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;">

          <!-- Header -->
          <tr>
            <td align="center" style="padding-bottom:24px;">
              <table cellpadding="0" cellspacing="0">
                <tr>
                  <td style="background-color:#FFD700;border-radius:100px;padding:10px 22px;">
                    <span style="font-size:22px;font-weight:900;letter-spacing:3px;color:#111111;">TRYP</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Hero Card -->
          <tr>
            <td style="background-color:#111111;border-radius:24px 24px 0 0;padding:48px 40px 32px;text-align:center;">
              <p style="margin:0 0 16px;font-size:48px;">🚗</p>
              <h1 style="margin:0 0 12px;font-size:32px;font-weight:900;color:#ffffff;letter-spacing:-0.5px;">
                Welcome to TRYP, ${firstName}!
              </h1>
              <p style="margin:0;font-size:17px;color:#aaaaaa;line-height:1.6;">
                South Africa's smarter, safer way to ride.<br/>
                Your account is ready. Let's get you moving.
              </p>
            </td>
          </tr>

          <!-- Body Card -->
          <tr>
            <td style="background-color:#ffffff;padding:36px 40px;border-radius:0 0 24px 24px;">

              <!-- What you can do -->
              <h2 style="margin:0 0 20px;font-size:18px;font-weight:800;color:#111111;">What you can do with TRYP</h2>

              <!-- Feature 1 -->
              <table cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:16px;">
                <tr>
                  <td width="48" valign="top">
                    <div style="width:40px;height:40px;background-color:#FFD700;border-radius:12px;text-align:center;line-height:40px;font-size:20px;">🗺️</div>
                  </td>
                  <td style="padding-left:14px;" valign="top">
                    <p style="margin:0;font-size:15px;font-weight:700;color:#111111;">Book rides instantly</p>
                    <p style="margin:4px 0 0;font-size:14px;color:#777777;line-height:1.5;">Request TRYP Go, Comfort, XL, or Exec across major SA cities.</p>
                  </td>
                </tr>
              </table>

              <!-- Feature 2 -->
              <table cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:16px;">
                <tr>
                  <td width="48" valign="top">
                    <div style="width:40px;height:40px;background-color:#FFD700;border-radius:12px;text-align:center;line-height:40px;font-size:20px;">📍</div>
                  </td>
                  <td style="padding-left:14px;" valign="top">
                    <p style="margin:0;font-size:15px;font-weight:700;color:#111111;">Track your driver live</p>
                    <p style="margin:4px 0 0;font-size:14px;color:#777777;line-height:1.5;">Real-time GPS tracking from pickup to drop-off.</p>
                  </td>
                </tr>
              </table>

              <!-- Feature 3 -->
              <table cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:32px;">
                <tr>
                  <td width="48" valign="top">
                    <div style="width:40px;height:40px;background-color:#FFD700;border-radius:12px;text-align:center;line-height:40px;font-size:20px;">💳</div>
                  </td>
                  <td style="padding-left:14px;" valign="top">
                    <p style="margin:0;font-size:15px;font-weight:700;color:#111111;">Pay your way</p>
                    <p style="margin:4px 0 0;font-size:14px;color:#777777;line-height:1.5;">Cash, card via Paystack, or your TRYP Wallet balance.</p>
                  </td>
                </tr>
              </table>

              <!-- CTA Button -->
              <table cellpadding="0" cellspacing="0" width="100%">
                <tr>
                  <td align="center">
                    <a href="https://tryp.app" style="display:inline-block;background-color:#111111;color:#FFD700;text-decoration:none;font-size:16px;font-weight:800;letter-spacing:0.5px;padding:16px 40px;border-radius:100px;">
                      Book Your First Ride →
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Divider -->
              <hr style="border:none;border-top:1px solid #eeeeee;margin:32px 0;" />

              <!-- Support -->
              <p style="margin:0;font-size:14px;color:#999999;text-align:center;line-height:1.6;">
                Questions? Reply to this email or reach us at
                <a href="mailto:support@tryp.app" style="color:#111111;font-weight:700;text-decoration:none;">support@tryp.app</a>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td align="center" style="padding:24px 0 0;">
              <p style="margin:0;font-size:12px;color:#aaaaaa;">
                You're receiving this because you signed up at tryp.app<br/>
                © ${new Date().getFullYear()} TRYP — South Africa
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

serve(async (req: Request) => {
  // Allow Supabase webhook (POST) only
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    if (!RESEND_API_KEY) {
      throw new Error("RESEND_API_KEY environment variable is not set.");
    }

    const payload: WelcomePayload = await req.json();

    // Only handle new user INSERT events from auth.users
    if (payload.type !== "INSERT" || !payload.record?.email) {
      return new Response(JSON.stringify({ skipped: true, reason: "Not a new user INSERT event" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { email, raw_user_meta_data } = payload.record;
    const fullName = raw_user_meta_data?.full_name ?? "";

    const htmlBody = buildWelcomeEmail(fullName, email);

    // Send via Resend API (REST — more reliable than SMTP in Deno edge)
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: `${FROM_NAME} <${FROM_EMAIL}>`,
        to: [email],
        subject: `Welcome to TRYP, ${fullName?.split(" ")[0] || "there"}! 🚗`,
        html: htmlBody,
        tags: [
          { name: "category", value: "welcome" },
          { name: "platform", value: "tryp" },
        ],
      }),
    });

    const result = await resendResponse.json();

    if (!resendResponse.ok) {
      throw new Error(`Resend API error: ${JSON.stringify(result)}`);
    }

    console.log(`[send-welcome-email] Sent to ${email} | Resend ID: ${result.id}`);

    return new Response(JSON.stringify({ success: true, email_id: result.id }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[send-welcome-email] Error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
