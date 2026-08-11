import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PAYSTACK_SUBACCOUNT_CODE = Deno.env.get("PAYSTACK_SUBACCOUNT_CODE") ?? "";
const PAYSTACK_CURRENCY = (Deno.env.get("PAYSTACK_CURRENCY") ?? "ZAR").toUpperCase();

function response(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (request: Request) => {
  if (request.method !== "POST") return response({ error: "Method Not Allowed" }, 405);
  if (!PAYSTACK_SECRET_KEY) return response({ error: "Paystack is not configured." }, 503);

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return response({ error: "Unauthorized" }, 401);

    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) return response({ error: "Unauthorized" }, 401);

    const payload = (await request.json()) as { booking_id?: string };
    const bookingId = String(payload.booking_id ?? "").trim();
    if (!bookingId) return response({ error: "booking_id is required." }, 400);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: booking, error: bookingError } = await adminClient
      .from("long_distance_bookings")
      .select("id, passenger_id, amount_paid, payment_status, payment_reference")
      .eq("id", bookingId)
      .maybeSingle();
    if (bookingError) throw bookingError;
    if (!booking || booking.passenger_id !== userData.user.id) return response({ error: "Booking not found." }, 404);
    if (!booking.payment_reference) return response({ error: "Payment has not been initialized." }, 409);
    if (booking.payment_status === "paid") return response({ status: "paid", reference: booking.payment_reference });
    if (booking.payment_status === "cancelled") return response({ status: "cancelled", reference: booking.payment_reference });

    const verifyResponse = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(booking.payment_reference)}`,
      { headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` } },
    );
    const verifyResult = await verifyResponse.json();
    const payment = verifyResult?.data;
    const subaccount = typeof payment?.subaccount === "string"
      ? payment.subaccount
      : payment?.subaccount?.subaccount_code;
    const verified =
      verifyResponse.ok &&
      verifyResult?.status === true &&
      payment?.status === "success" &&
      Number(payment?.amount) === Math.round(Number(booking.amount_paid) * 100) &&
      String(payment?.currency ?? "").toUpperCase() === PAYSTACK_CURRENCY &&
      (!PAYSTACK_SUBACCOUNT_CODE || String(subaccount ?? "") === PAYSTACK_SUBACCOUNT_CODE);

    if (!verified) {
      const failedStatuses = ["failed", "abandoned", "reversed", "cancelled"];
      if (failedStatuses.includes(String(payment?.status ?? "").toLowerCase())) {
        await adminClient.rpc("settle_long_distance_booking", {
          p_booking_id: booking.id,
          p_status: "failed",
          p_reference: booking.payment_reference,
        });
        return response({ status: "failed", reference: booking.payment_reference });
      }
      return response({ status: "unverified", reference: booking.payment_reference });
    }

    const { data: settledStatus, error: settleError } = await adminClient.rpc("settle_long_distance_booking", {
      p_booking_id: booking.id,
      p_status: "paid",
      p_reference: booking.payment_reference,
    });
    if (settleError) {
      // Payment succeeded but no seat may be available anymore. Keep the
      // settlement error explicit so operations can refund/reconcile it.
      throw settleError;
    }

    return response({ status: settledStatus ?? "paid", reference: booking.payment_reference });
  } catch (error) {
    console.error("[paystack-long-distance-verify] Error:", error);
    return response({ error: "Payment verification failed." }, 500);
  }
});
