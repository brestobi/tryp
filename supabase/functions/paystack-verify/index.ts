import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PAYSTACK_SUBACCOUNT_CODE = Deno.env.get("PAYSTACK_SUBACCOUNT_CODE") ?? "";
const PAYSTACK_CURRENCY = (Deno.env.get("PAYSTACK_CURRENCY") ?? "ZAR").toUpperCase();

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "Method Not Allowed" }, 405);
  if (!PAYSTACK_SECRET_KEY) return json({ error: "Paystack is not configured." }, 503);

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);

    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);

    const payload = (await request.json()) as { ride_id?: string };
    if (!payload.ride_id) return json({ error: "ride_id is required." }, 400);

    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: ride, error: rideError } = await adminClient
      .from("rides")
      .select("id, passenger_id, fare, payment_method, payment_status, payment_reference")
      .eq("id", payload.ride_id)
      .maybeSingle();
    if (rideError) throw rideError;
    if (!ride || ride.passenger_id !== userData.user.id) return json({ error: "Ride not found." }, 404);
    if (!ride.payment_reference) return json({ error: "Payment has not been initialized." }, 409);
    if (ride.payment_status === "paid") return json({ status: "paid", reference: ride.payment_reference });

    const verifyResponse = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(ride.payment_reference)}`,
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
      Number(payment?.amount) === Math.round(Number(ride.fare) * 100) &&
      String(payment?.currency ?? "").toUpperCase() === PAYSTACK_CURRENCY &&
      (!PAYSTACK_SUBACCOUNT_CODE || String(subaccount ?? "") === PAYSTACK_SUBACCOUNT_CODE);

    if (!verified) {
      const failedStatuses = ["failed", "abandoned", "reversed"];
      if (failedStatuses.includes(String(payment?.status ?? "").toLowerCase())) {
        await adminClient.rpc("set_ride_payment_status", {
          p_ride_id: ride.id,
          p_status: "failed",
          p_reference: ride.payment_reference,
        });
        return json({ status: "failed", reference: ride.payment_reference });
      }
      return json({ status: "unverified", reference: ride.payment_reference });
    }

    const { error: statusError } = await adminClient.rpc("set_ride_payment_status", {
      p_ride_id: ride.id,
      p_status: "paid",
      p_reference: ride.payment_reference,
    });
    if (statusError) throw statusError;

    return json({ status: "paid", reference: ride.payment_reference });
  } catch (error) {
    console.error("[paystack-verify] Error:", error);
    return json({ error: "Payment verification failed." }, 500);
  }
});
