import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PAYSTACK_SUBACCOUNT_CODE = Deno.env.get("PAYSTACK_SUBACCOUNT_CODE") ?? "";
const PAYSTACK_CURRENCY = (Deno.env.get("PAYSTACK_CURRENCY") ?? "ZAR").toUpperCase();
const PAYSTACK_API = "https://api.paystack.co";
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function equalHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let index = 0; index < a.length; index += 1) mismatch |= a.charCodeAt(index) ^ b.charCodeAt(index);
  return mismatch === 0;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function signatureFor(body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(PAYSTACK_SECRET_KEY),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return bytesToHex(new Uint8Array(signature));
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "Method Not Allowed" }, 405);
  if (!PAYSTACK_SECRET_KEY || !SUPABASE_SERVICE_ROLE_KEY) return json({ error: "Webhook is not configured." }, 503);

  try {
    const rawBody = await request.text();
    const providedSignature = request.headers.get("x-paystack-signature") ?? "";
    const expectedSignature = await signatureFor(rawBody);
    if (!providedSignature || !equalHex(providedSignature.toLowerCase(), expectedSignature)) {
      return json({ error: "Invalid signature" }, 401);
    }

    const event = JSON.parse(rawBody) as {
      event?: string;
      data?: {
        reference?: string;
        status?: string;
        amount?: number;
        currency?: string;
        subaccount?: string;
        metadata?: { ride_id?: string } | string;
      };
    };
    if (!event.data?.reference) return json({ received: true });

    const reference = event.data.reference;
    const { data: ride, error: rideError } = await supabase
      .from("rides")
      .select("id, fare, payment_method, payment_status, payment_reference")
      .eq("payment_reference", reference)
      .maybeSingle();
    if (rideError) throw rideError;

    // Long-distance bookings use the same Paystack webhook endpoint but have
    // their own settlement RPC and amount source.
    const { data: longDistanceBooking, error: longDistanceError } = await supabase
      .from("long_distance_bookings")
      .select("id, amount_paid, payment_status, payment_reference")
      .eq("payment_reference", reference)
      .maybeSingle();
    if (longDistanceError) throw longDistanceError;

    if (!ride && !longDistanceBooking) return json({ received: true });
    if (ride && (ride.payment_status === "paid" || ride.payment_status === "cancelled")) {
      return json({ received: true, already_processed: true });
    }
    if (longDistanceBooking && longDistanceBooking.payment_status === "paid") {
      return json({ received: true, already_processed: true });
    }

    if (event.event !== "charge.success") {
      if (["charge.failed", "charge.reversed"].includes(event.event ?? "")) {
        if (ride) {
          await supabase.rpc("set_ride_payment_status", {
            p_ride_id: ride.id,
            p_status: "failed",
            p_reference: reference,
          });
        } else if (longDistanceBooking) {
          await supabase.rpc("settle_long_distance_booking", {
            p_booking_id: longDistanceBooking.id,
            p_status: "failed",
            p_reference: reference,
          });
        }
      }
      return json({ received: true });
    }

    // Verify against Paystack's API rather than trusting webhook amount/status.
    const verifyResponse = await fetch(`${PAYSTACK_API}/transaction/verify/${encodeURIComponent(reference)}`, {
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
    });
    const verifyResult = await verifyResponse.json();
    const subaccount = typeof verifyResult?.data?.subaccount === "string"
      ? verifyResult.data.subaccount
      : verifyResult?.data?.subaccount?.subaccount_code;
    const expectedAmount = ride
      ? Math.round(Number(ride.fare) * 100)
      : Math.round(Number(longDistanceBooking!.amount_paid) * 100);
    const verified =
      verifyResponse.ok &&
      verifyResult?.status === true &&
      verifyResult?.data?.status === "success" &&
      Number(verifyResult?.data?.amount) === expectedAmount &&
      String(verifyResult?.data?.currency ?? "").toUpperCase() === PAYSTACK_CURRENCY &&
      (!PAYSTACK_SUBACCOUNT_CODE || String(subaccount ?? "") === PAYSTACK_SUBACCOUNT_CODE);

    if (!verified) {
      console.error("[paystack-webhook] Verification mismatch", {
        rideId: ride?.id,
        longDistanceBookingId: longDistanceBooking?.id,
        reference,
      });
      return json({ error: "Payment verification failed" }, 422);
    }

    if (ride) {
      const { error: statusError } = await supabase.rpc("set_ride_payment_status", {
        p_ride_id: ride.id,
        p_status: "paid",
        p_reference: reference,
      });
      if (statusError) throw statusError;
    } else {
      const { error: statusError } = await supabase.rpc("settle_long_distance_booking", {
        p_booking_id: longDistanceBooking!.id,
        p_status: "paid",
        p_reference: reference,
      });
      if (statusError) throw statusError;
    }

    return json({ received: true, paid: true });
  } catch (error) {
    console.error("[paystack-webhook] Error:", error);
    return json({ error: "Webhook processing failed" }, 500);
  }
});
