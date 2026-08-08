import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FROM_EMAIL = "noreply@illdoit.space";
const SUPPORT_EMAIL = "support@illdoit.space";
const FROM_NAME = "TRYP Billing";
const CLAIM_TIMEOUT_MINUTES = 10;
const MAX_ATTEMPTS = 6;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

type InvoicePayload = { ride_id?: string };

function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatDate(value: unknown): string {
  if (!value) return "—";
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("en-ZA", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Africa/Johannesburg",
  }).format(date);
}

function formatAmount(value: unknown): string {
  const amount = Number(value ?? 0);
  return `R${Number.isFinite(amount) ? amount.toFixed(2) : "0.00"}`;
}

function buildInvoiceEmail(ride: Record<string, unknown>, invoiceId: string): string {
  const driver = (ride.driver ?? {}) as Record<string, unknown>;
  const fare = formatAmount(ride.fare);
  const distance = Number(ride.distance_km ?? 0);
  const vehicle = escapeHtml(
    [driver.vehicle_color, driver.vehicle_make, driver.vehicle_model]
      .filter(Boolean)
      .join(" ") || "TRYP vehicle",
  );
  const plate = escapeHtml(driver.vehicle_plate ?? "");

  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /><title>TRYP trip invoice</title></head>
<body style="margin:0;background:#f4f4f5;color:#111;font-family:Arial,Helvetica,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:32px 12px;background:#f4f4f5;"><tr><td align="center">
    <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width:600px;width:100%;background:#fff;border-radius:20px;overflow:hidden;">
      <tr><td style="padding:28px 32px;background:#111;color:#fff;"><div style="font-size:22px;font-weight:900;letter-spacing:3px;color:#ffd400;">TRYP</div><div style="margin-top:20px;font-size:28px;font-weight:800;">Trip invoice</div><div style="margin-top:6px;color:#bdbdbd;font-size:14px;">Thank you for riding with us.</div></td></tr>
      <tr><td style="padding:28px 32px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td style="color:#6b6b6b;font-size:13px;">Invoice number</td><td align="right" style="font-size:13px;font-weight:700;">${escapeHtml(invoiceId)}</td></tr><tr><td colspan="2" style="height:8px;"></td></tr><tr><td style="color:#6b6b6b;font-size:13px;">Completed</td><td align="right" style="font-size:13px;font-weight:700;">${escapeHtml(formatDate(ride.completed_at))}</td></tr></table>
        <hr style="border:0;border-top:1px solid #e5e5e5;margin:24px 0;" />
        <div style="font-size:13px;color:#6b6b6b;margin-bottom:8px;">Route</div><div style="font-size:15px;font-weight:700;line-height:1.6;">${escapeHtml(ride.origin ?? "Pickup location")}<br /><span style="color:#6b6b6b;font-weight:400;">to</span><br />${escapeHtml(ride.destination ?? "Destination")}</div>
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-top:24px;">
          <tr><td style="padding:10px 0;color:#6b6b6b;">Ride type</td><td align="right" style="padding:10px 0;font-weight:700;">${escapeHtml(ride.ride_type ?? "TRYP Go")}</td></tr>
          <tr><td style="padding:10px 0;color:#6b6b6b;">Distance</td><td align="right" style="padding:10px 0;font-weight:700;">${Number.isFinite(distance) ? distance.toFixed(1) : "0.0"} km</td></tr>
          <tr><td style="padding:10px 0;color:#6b6b6b;">Driver</td><td align="right" style="padding:10px 0;font-weight:700;">${escapeHtml(driver.full_name ?? "TRYP driver")}</td></tr>
          <tr><td style="padding:10px 0;color:#6b6b6b;">Vehicle</td><td align="right" style="padding:10px 0;font-weight:700;">${vehicle}${plate ? ` (${plate})` : ""}</td></tr>
          <tr><td style="padding:10px 0;color:#6b6b6b;">Payment</td><td align="right" style="padding:10px 0;font-weight:700;">${escapeHtml(ride.payment_method ?? "Cash")} · ${escapeHtml(ride.payment_status ?? "pending")}</td></tr>
        </table>
        <div style="margin-top:18px;padding:20px;border-radius:14px;background:#ffd400;"><table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td style="font-size:16px;font-weight:800;">Total fare</td><td align="right" style="font-size:24px;font-weight:900;">${fare}</td></tr></table></div>
        <p style="margin:24px 0 0;color:#777;font-size:12px;line-height:1.6;">Keep this email for your records. For questions, contact ${SUPPORT_EMAIL} and include the invoice number above.</p>
      </td></tr>
    </table>
    <div style="padding:20px;color:#999;font-size:11px;">© ${new Date().getFullYear()} TRYP · South Africa</div>
  </td></tr></table>
</body>
</html>`;
}

async function updateDelivery(invoiceId: string, values: Record<string, unknown>): Promise<void> {
  const { error } = await supabase.from("invoice_deliveries").update(values).eq("id", invoiceId);
  if (error) console.error("[send-invoice-email] Delivery update failed:", error);
}

serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  let invoiceId: string | undefined;
  let attemptNumber = 1;
  try {
    if (!RESEND_API_KEY) throw new Error("RESEND_API_KEY is not configured.");

    const payload = (await req.json()) as InvoicePayload;
    if (!payload.ride_id) throw new Error("ride_id is required.");

    // The ride is the source of truth. Never trust passenger_id from a webhook.
    const { data: ride, error: rideError } = await supabase
      .from("rides")
      .select("*, driver:driver_id(full_name, vehicle_make, vehicle_model, vehicle_color, vehicle_plate)")
      .eq("id", payload.ride_id)
      .single();
    if (rideError) throw rideError;
    if (ride.status !== "completed") throw new Error("Invoice can only be sent for completed rides.");

    const passengerId = ride.passenger_id as string;
    let currentAttempts = 0;
    const { data: existing, error: existingError } = await supabase
      .from("invoice_deliveries")
      .select("id, status, attempts, last_attempt_at, next_attempt_at")
      .eq("ride_id", ride.id)
      .maybeSingle();
    if (existingError) throw existingError;

    if (existing) {
      invoiceId = existing.id;
      currentAttempts = existing.attempts ?? 0;
      if (existing.status === "sent" || existing.status === "delivered") {
        return new Response(JSON.stringify({ skipped: true, status: existing.status }), { status: 200 });
      }
      if (existing.status === "abandoned" || existing.status === "bounced" || existing.status === "complained") {
        return new Response(JSON.stringify({ skipped: true, status: existing.status }), { status: 200 });
      }
      if (existing.attempts >= MAX_ATTEMPTS) {
        await updateDelivery(existing.id, { status: "abandoned", next_attempt_at: null });
        return new Response(JSON.stringify({ skipped: true, status: "abandoned" }), { status: 200 });
      }
      if ((existing.status === "pending" || existing.status === "failed") && existing.next_attempt_at) {
        const nextAttemptAt = new Date(existing.next_attempt_at).getTime();
        if (Number.isFinite(nextAttemptAt) && nextAttemptAt > Date.now()) {
          return new Response(JSON.stringify({ skipped: true, reason: "Retry is scheduled" }), { status: 200 });
        }
      }
      if (existing.status === "sending" && existing.last_attempt_at) {
        const ageMs = Date.now() - new Date(existing.last_attempt_at).getTime();
        if (ageMs < CLAIM_TIMEOUT_MINUTES * 60 * 1000) {
          return new Response(JSON.stringify({ skipped: true, reason: "Delivery is already in progress" }), { status: 200 });
        }
      }
    } else {
      const { data: inserted, error: insertError } = await supabase
        .from("invoice_deliveries")
        .insert({ ride_id: ride.id, passenger_id: passengerId, status: "pending" })
        .select("id, status, attempts")
        .single();
      if (insertError && insertError.code !== "23505") throw insertError;
      if (inserted) {
        invoiceId = inserted.id;
        currentAttempts = inserted.attempts ?? 0;
      } else {
        const { data: raced, error: racedError } = await supabase
          .from("invoice_deliveries")
          .select("id, status, attempts, last_attempt_at, next_attempt_at")
          .eq("ride_id", ride.id)
          .single();
        if (racedError) throw racedError;
        invoiceId = raced.id;
        currentAttempts = raced.attempts ?? 0;
        if (raced.status === "sent" || raced.status === "delivered") {
          return new Response(JSON.stringify({ skipped: true, status: raced.status }), { status: 200 });
        }
        if (raced.status === "abandoned" || raced.status === "bounced" || raced.status === "complained") {
          return new Response(JSON.stringify({ skipped: true, status: raced.status }), { status: 200 });
        }
      }
    }

    if (!invoiceId) throw new Error("Invoice delivery record could not be created.");

    // Claim pending/failed deliveries and reclaim only stale sending leases.
    const staleBefore = new Date(Date.now() - CLAIM_TIMEOUT_MINUTES * 60 * 1000).toISOString();
    const { data: claimed, error: claimError } = await supabase
      .from("invoice_deliveries")
      .update({
        status: "sending",
        attempts: currentAttempts + 1,
        last_attempt_at: new Date().toISOString(),
        last_error: null,
      })
      .eq("id", invoiceId)
      .lt("attempts", MAX_ATTEMPTS)
      .or(`status.in.(pending,failed),and(status.eq.sending,last_attempt_at.lt.${staleBefore})`)
      .select("id")
      .maybeSingle();
    if (claimError) throw claimError;
    if (!claimed) return new Response(JSON.stringify({ skipped: true, reason: "Already claimed or retry limit reached" }), { status: 200 });

    attemptNumber = currentAttempts + 1;
    const { data: authUser, error: userError } = await supabase.auth.admin.getUserById(passengerId);
    if (userError || !authUser.user) throw new Error("Passenger account was not found.");
    const { data: profile } = await supabase.from("profiles").select("email").eq("id", passengerId).maybeSingle();
    const email = profile?.email ?? authUser.user.email;
    if (!email) throw new Error("Passenger has no email address.");

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
        // One logical invoice keeps the same provider idempotency key across retries.
        "Idempotency-Key": invoiceId,
      },
      body: JSON.stringify({
        from: `${FROM_NAME} <${FROM_EMAIL}>`,
        reply_to: SUPPORT_EMAIL,
        to: [email],
        subject: `Your TRYP invoice · ${formatAmount(ride.fare)} · ${formatDate(ride.completed_at)}`,
        html: buildInvoiceEmail(ride, invoiceId),
        tags: [{ name: "category", value: "trip-invoice" }, { name: "ride_id", value: String(ride.id) }],
      }),
    });
    const resendResult = await resendResponse.json();
    if (!resendResponse.ok) throw new Error(`Resend API error: ${JSON.stringify(resendResult)}`);

    await updateDelivery(invoiceId, {
      status: "sent",
      sent_at: new Date().toISOString(),
      provider_message_id: resendResult.id ?? null,
      next_attempt_at: null,
      last_error: null,
    });
    return new Response(JSON.stringify({ success: true, invoice_id: invoiceId, email_id: resendResult.id }), { status: 200 });
  } catch (error) {
    console.error("[send-invoice-email] Error:", error);
    if (invoiceId) {
      const message = error instanceof Error ? error.message : String(error);
      const exhausted = attemptNumber >= MAX_ATTEMPTS;
      const retryDelayMinutes = Math.min(60, 5 * 2 ** Math.max(0, attemptNumber - 1));
      await updateDelivery(invoiceId, {
        status: exhausted ? "abandoned" : "failed",
        next_attempt_at: exhausted
          ? null
          : new Date(Date.now() + retryDelayMinutes * 60 * 1000).toISOString(),
        last_error: message,
      });
    }
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), { status: 500 });
  }
});
