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

const jsonHeaders = { "Content-Type": "application/json" };

type InitPayload = { ride_id?: string };

type PaystackInitializeResponse = {
  status?: boolean;
  message?: string;
  data?: {
    authorization_url?: string;
    access_code?: string;
    reference?: string;
  };
};

function response(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

serve(async (request: Request) => {
  if (request.method !== "POST") return response({ error: "Method Not Allowed" }, 405);
  if (!PAYSTACK_SECRET_KEY || !PAYSTACK_SUBACCOUNT_CODE) {
    return response({ error: "Paystack live payment configuration is incomplete." }, 503);
  }

  let paymentReserved = false;
  let reservedReference = "";
  let reservedRideId = "";
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return response({ error: "Unauthorized" }, 401);

    // Validate the caller's Supabase access token before using the service role.
    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) return response({ error: "Unauthorized" }, 401);

    const payload = (await request.json()) as InitPayload;
    if (!payload.ride_id) return response({ error: "ride_id is required." }, 400);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: ride, error: rideError } = await adminClient
      .from("rides")
      .select("id, passenger_id, fare, payment_method, payment_status, payment_reference")
      .eq("id", payload.ride_id)
      .maybeSingle();
    if (rideError) throw rideError;
    if (!ride || ride.passenger_id !== userData.user.id) return response({ error: "Ride not found." }, 404);
    if (String(ride.payment_method).toLowerCase() === "cash") {
      return response({ error: "This ride does not require online payment." }, 400);
    }
    if (ride.payment_status === "paid") return response({ error: "This ride is already paid." }, 409);
    const amount = Math.round(Number(ride.fare) * 100);
    if (!Number.isSafeInteger(amount) || amount <= 0) {
      return response({ error: "Ride has an invalid payment amount." }, 422);
    }

    const email = userData.user.email;
    if (!email) return response({ error: "Passenger account has no email address." }, 422);

    const reference = `TRYP_${ride.id.replaceAll("-", "").slice(0, 16)}_${Date.now()}`;
    const { error: reservationError } = await adminClient.rpc("begin_ride_payment", {
      p_ride_id: ride.id,
      p_reference: reference,
    });
    if (reservationError) throw reservationError;
    paymentReserved = true;
    reservedReference = reference;
    reservedRideId = ride.id;

    const transactionBody: Record<string, unknown> = {
      email,
      amount,
      currency: PAYSTACK_CURRENCY,
      reference,
      subaccount: PAYSTACK_SUBACCOUNT_CODE,
      bearer: PAYSTACK_BEARER,
      metadata: { ride_id: ride.id, source: "tryp_passenger_app" },
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
    const paystackResult = (await paystackResponse.json()) as PaystackInitializeResponse;
    const returnedReference = paystackResult.data?.reference ?? reference;
    if (!paystackResponse.ok || !paystackResult.status || !paystackResult.data?.authorization_url || returnedReference !== reference) {
      console.error("[paystack-initialize] Paystack rejected initialization", {
        status: paystackResponse.status,
        message: paystackResult.message,
      });
      await adminClient.rpc("set_ride_payment_status", {
        p_ride_id: ride.id,
        p_status: "failed",
        p_reference: reference,
      });
      paymentReserved = false;
      return response({ error: "Paystack could not initialize this payment." }, 502);
    }

    return response({
      authorization_url: paystackResult.data.authorization_url,
      access_code: paystackResult.data.access_code ?? null,
      reference: returnedReference,
    });
  } catch (error) {
    console.error("[paystack-initialize] Error:", error);
    if (paymentReserved && reservedRideId) {
      await createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY).rpc("set_ride_payment_status", {
        p_ride_id: reservedRideId,
        p_status: "failed",
        p_reference: reservedReference,
      });
    }
    return response({ error: "Payment initialization failed." }, 500);
  }
});
