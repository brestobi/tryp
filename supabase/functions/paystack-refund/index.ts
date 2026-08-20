import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PAYSTACK_API = "https://api.paystack.co";

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function badRequest(message: string) {
  return json({ error: message }, 400);
}

function randToKobo(rand: number): number {
  // Paystack amounts are integer kobo. Trim to two decimal places first so we
  // do not lose precision on edge values like 0.1 increments.
  return Math.round(Math.round(rand * 100) * 100);
}

interface RefundRequestPayload {
  rideId?: string;
  amount?: number;
  reason?: string;
  notes?: Record<string, unknown>;
}

serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "Method Not Allowed" }, 405);
  if (!PAYSTACK_SECRET_KEY) return json({ error: "Paystack is not configured." }, 503);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);

  try {
    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: profile, error: profileError } = await serviceClient
      .from("profiles")
      .select("id, role, admin_role, full_name, email")
      .eq("id", userData.user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || !["admin", "super_admin"].includes(profile.role)) {
      return json({ error: "Only super admins can issue refunds." }, 403);
    }
    const adminRole = profile.admin_role ?? "super_admin";
    if (!["super_admin", "finance_manager"].includes(adminRole)) {
      return json({
        error: "Refunds are reserved for the finance manager or super admin role.",
        adminRole,
      }, 403);
    }

    const payload = (await request.json()) as RefundRequestPayload;
    const rideId = payload.rideId?.trim();
    const reason = payload.reason?.trim();
    const amount = typeof payload.amount === "number" ? payload.amount : NaN;
    const notes = payload.notes ?? {};

    if (!rideId || !/^[0-9a-f-]{36}$/i.test(rideId)) {
      return badRequest("A valid rideId is required.");
    }
    if (!Number.isFinite(amount) || amount <= 0) {
      return badRequest("amount must be a positive number in ZAR.");
    }
    if (!reason || reason.length < 4) {
      return badRequest("reason must be at least 4 characters.");
    }
    if (reason.length > 500) {
      return badRequest("reason must be at most 500 characters.");
    }

    const { data: ride, error: rideError } = await serviceClient
      .from("rides")
      .select("id, passenger_id, driver_id, fare, payment_method, payment_status, payment_reference, status")
      .eq("id", rideId)
      .maybeSingle();
    if (rideError) throw rideError;
    if (!ride) return badRequest(`Ride ${rideId} not found.`);

    if (ride.payment_method === "Cash") {
      return badRequest("Cash rides cannot be refunded via Paystack.");
    }
    if (ride.payment_status !== "paid") {
      return badRequest(
        `Only settled payments can be refunded. Current payment_status: ${ride.payment_status ?? "unknown"}.`,
      );
    }
    if (!ride.payment_reference?.trim()) {
      return badRequest("Ride has no payment_reference - refunds cannot be issued.");
    }
    if (amount > Number(ride.fare ?? 0) + 0.01) {
      return badRequest(
        `Refund amount (R ${amount.toFixed(2)}) exceeds the ride fare (R ${Number(ride.fare ?? 0).toFixed(2)}).`,
      );
    }

    // Step 1: open the refund row in the pending state so the dashboard shows
    // operator-side activity even before Paystack responds.
    const { data: refundRow, error: refundInsertError } = await serviceClient
      .from("refunds")
      .insert({
        ride_id: ride.id,
        payment_reference: ride.payment_reference!,
        requested_amount: amount,
        currency: "ZAR",
        reason,
        status: "processing",
        requested_by: userData.user.id,
        passenger_id: ride.passenger_id ?? null,
        driver_id: ride.driver_id ?? null,
        notes,
      })
      .select("id, status, requested_amount, currency")
      .single();
    if (refundInsertError) throw refundInsertError;

    // Step 2: ask Paystack to refund. Paystack returns { status, data, message }.
    const paystackResponse = await fetch(`${PAYSTACK_API}/refund`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        transaction: ride.payment_reference,
        amount: randToKobo(amount),
        currency: "ZAR",
        merchant_note: reason.slice(0, 100),
      }),
    });

    const paystackBody = await paystackResponse.json();
    const refundStatusLower = String(paystackBody?.data?.status ?? "").toLowerCase();
    const paystackRefundId: string | null = paystackBody?.data?.id
      ? String(paystackBody.data.id)
      : null;
    const processedKobo: number = Number(paystackBody?.data?.amount ?? randToKobo(amount));
    const processedAmount = processedKobo / 100;

    if (!paystackResponse.ok || !paystackBody?.status || refundStatusLower !== "processed") {
      const failureReason = typeof paystackBody?.message === "string"
        ? paystackBody.message
        : `Paystack responded with status ${paystackResponse.status}.`;
      const { error: failUpdateError } = await serviceClient.rpc("finalize_refund", {
        p_refund_id: refundRow.id,
        p_status: "failed",
        p_processed_amount: 0,
        p_paystack_refund_id: null,
        p_paystack_response: paystackBody,
        p_failure_reason: failureReason,
      });
      if (failUpdateError) throw failUpdateError;
      await serviceClient.from("admin_audit_logs").insert({
        action: "REFUND_FAILED",
        target_id: refundRow.id,
        target_type: "refund",
        details: `Refund ${refundRow.id} failed for ride ${ride.id}. ${failureReason}`,
      });
      return json({
        refundId: refundRow.id,
        status: "failed",
        amount,
        paystackStatus: refundStatusLower || null,
        paystackMessage: failureReason,
        paystackResponse: paystackBody,
      }, 502);
    }

    // Step 3: finalize the refund. This trusted path also flips the ride
    // payment_status to 'refunded' inside the RPC.
    const { data: finalized, error: finalizeError } = await serviceClient.rpc("finalize_refund", {
      p_refund_id: refundRow.id,
      p_status: "completed",
      p_processed_amount: processedAmount,
      p_paystack_refund_id: paystackRefundId,
      p_paystack_response: paystackBody,
      p_failure_reason: null,
    });
    if (finalizeError) throw finalizeError;

    await serviceClient.from("admin_audit_logs").insert({
      action: "PROCESS_REFUND",
      target_id: refundRow.id,
      target_type: "refund",
      details: `Refunded R ${processedAmount.toFixed(2)} for ride ${ride.id}. Reference: ${paystackRefundId ?? "n/a"}.`,
    });

    return json({
      refundId: refundRow.id,
      status: "completed",
      amount,
      processedAmount,
      paystackRefundId,
      paystackResponse: paystackBody,
      rideId: ride.id,
      passengerId: ride.passenger_id,
      driverId: ride.driver_id,
    });
  } catch (error) {
    console.error("[paystack-refund] Error:", error);
    return json({ error: "Refund request failed." }, 500);
  }
});
