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

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: profile, error: profileError } = await serviceClient
      .from("profiles")
      .select("role")
      .eq("id", userData.user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || !["admin", "super_admin"].includes(profile.role)) {
      return json({ error: "Admin access is required." }, 403);
    }

    const payload = (await request.json()) as { reference?: string };
    const reference = payload.reference?.trim();
    if (!reference || reference.length > 100) return json({ error: "A valid reference is required." }, 400);

    const verifyResponse = await fetch(`${PAYSTACK_API}/transaction/verify/${encodeURIComponent(reference)}`, {
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
    });
    const result = await verifyResponse.json();
    if (!verifyResponse.ok || result?.status !== true || !result?.data) {
      return json({ error: "Paystack transaction was not found." }, 404);
    }

    const transaction = result.data;
    return json({
      reference: transaction.reference ?? reference,
      amount: Number(transaction.amount ?? 0) / 100,
      currency: transaction.currency ?? null,
      channel: transaction.channel ?? "Paystack",
      status: transaction.status ?? "unknown",
      paidAt: transaction.paid_at ?? transaction.transaction_date ?? null,
      customerEmail: transaction.customer?.email ?? "",
    });
  } catch (error) {
    console.error("[paystack-admin-verify] Error:", error);
    return json({ error: "Paystack lookup failed." }, 500);
  }
});
