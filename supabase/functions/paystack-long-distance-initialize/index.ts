import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const PAYSTACK_API = "https://api.paystack.co";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
const PAYSTACK_SUBACCOUNT_CODE = Deno.env.get("PAYSTACK_SUBACCOUNT_CODE") ?? "";
const PAYSTACK_CURRENCY = (Deno.env.get("PAYSTACK_CURRENCY") ?? "ZAR").toUpperCase();
const PAYSTACK_BEARER = Deno.env.get("PAYSTACK_BEARER") ?? "account";
const PAYSTACK_CALLBACK_URL = Deno.env.get("PAYSTACK_CALLBACK_URL") ?? "https://standard.paystack.co/close";

function response(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

type Payload = { booking_id?: string };

type PaystackResponse = {
  status?: boolean;
  message?: string;
  data?: {
    authorization_url?: string;
    access_code?: string;
    reference?: string;
  };
};

serve(async (request: Request) => {
  if (request.method !== "POST") return response({ error: "Method Not Allowed" }, 405);
  if (!PAYSTACK_SECRET_KEY || !PAYSTACK_SUBACCOUNT_CODE) {
    return response({ error: "Paystack live payment configuration is incomplete." }, 503);
  }

  let reserved = false;
  let bookingId = "";
  let reference = "";
  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return response({ error: "Unauthorized" }, 401);

    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) return response({ error: "Unauthorized" }, 401);

    const payload = (await request.json()) as Payload;
    bookingId = String(payload.booking_id ?? "").trim();
    if (!bookingId) return response({ error: "booking_id is required." }, 400);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: booking, error: bookingError } = await adminClient
      .from("long_distance_bookings")
      .select("id, passenger_id, seats, amount_paid, status, payment_status, payment_reference, long_distance_trips(origin, destination, departure_at)")
      .eq("id", bookingId)
      .maybeSingle();
    if (bookingError) throw bookingError;
    if (!booking || booking.passenger_id !== userData.user.id) return response({ error: "Booking not found." }, 404);
    if (booking.status !== "pending") return response({ error: "This booking is no longer payable." }, 409);
    if (booking.payment_status === "paid") return response({ error: "This booking is already paid." }, 409);

    const amount = Math.round(Number(booking.amount_paid) * 100);
    if (!Number.isSafeInteger(amount) || amount <= 0) return response({ error: "Booking has an invalid payment amount." }, 422);
    const email = userData.user.email;
    if (!email) return response({ error: "Passenger account has no email address." }, 422);

    reference = `LD-${bookingId}-${Date.now()}`;
    const { error: reservationError } = await adminClient.rpc("begin_long_distance_payment", {
      p_booking_id: bookingId,
      p_reference: reference,
    });
    if (reservationError) throw reservationError;
    reserved = true;

    const transactionBody: Record<string, unknown> = {
      email,
      amount,
      currency: PAYSTACK_CURRENCY,
      reference,
      subaccount: PAYSTACK_SUBACCOUNT_CODE,
      bearer: PAYSTACK_BEARER,
      callback_url: PAYSTACK_CALLBACK_URL,
      metadata: { booking_id: bookingId, source: "tryp_long_distance" },
    };
    const transactionCharge = Deno.env.get("PAYSTACK_TRANSACTION_CHARGE");
    if (transactionCharge) {
      const charge = Number(transactionCharge);
      if (Number.isSafeInteger(charge) && charge >= 0) transactionBody.transaction_charge = charge;
    }

    const paystackResponse = await fetch(`${PAYSTACK_API}/transaction/initialize`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(transactionBody),
    });
    const paystackResult = (await paystackResponse.json()) as PaystackResponse;
    const returnedReference = paystackResult.data?.reference ?? reference;
    if (!paystackResponse.ok || !paystackResult.status || !paystackResult.data?.authorization_url || returnedReference !== reference) {
      await adminClient.rpc("settle_long_distance_booking", {
        p_booking_id: bookingId,
        p_status: "failed",
        p_reference: reference,
      });
      reserved = false;
      return response({ error: "Paystack could not initialize this payment." }, 502);
    }

    return response({
      authorization_url: paystackResult.data.authorization_url,
      access_code: paystackResult.data.access_code ?? null,
      reference: returnedReference,
      callback_url: PAYSTACK_CALLBACK_URL,
    });
  } catch (error) {
    console.error("[paystack-long-distance-initialize] Error:", error);
    if (reserved && bookingId) {
      await createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY).rpc("settle_long_distance_booking", {
        p_booking_id: bookingId,
        p_status: "failed",
        p_reference: reference,
      });
    }
    return response({ error: "Payment initialization failed." }, 500);
  }
});
