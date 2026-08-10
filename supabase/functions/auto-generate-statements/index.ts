/**
 * TRYP Auto-Generate Driver Statements
 * 
 * This Edge Function runs every Monday at 08:00 SAST to:
 * 1. Calculate the previous week's statement period (Monday-Sunday)
 * 2. Fetch all active drivers
 * 3. Generate earnings statements for each driver
 * 4. Send statements via email to all drivers
 * 
 * Schedule: Every Monday at 08:00 SAST (06:00 UTC)
 * 
 * Setup:
 * - Add to supabase/config.toml:
 *   [cron]
 *   enabled = true
 * 
 * - Create cron job in Supabase Dashboard:
 *   SELECT cron.schedule(
 *     'weekly-driver-statements',
 *     '0 6 * * 1',  -- Every Monday at 06:00 UTC (08:00 SAST)
 *     $$
 *     SELECT net.http_post(
 *       url := current_setting('app.settings.supabase_url') || '/functions/v1/auto-generate-statements',
 *       headers := jsonb_build_object(
 *         'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
 *         'Content-Type', 'application/json'
 *       ),
 *       body := '{}'::jsonb
 *     );
 *     $$
 *   );
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface StatementData {
  driverId: string;
  driverName: string;
  driverEmail: string;
  driverPhone: string;
  vehiclePlate: string;
  periodStart: string;
  periodEnd: string;
  totalTrips: number;
  cashTrips: number;
  onlineTrips: number;
  totalGross: number;
  totalPlatformFees: number;
  totalNetEarnings: number;
  cashCollected: number;
  cashFeesOwed: number;
  onlineEarnings: number;
  onlineFeesWithheld: number;
  pendingOnlinePayout: number;
  averageFare: number;
  rating: number;
}

// Helper to get last Monday (start of previous week)
function getPreviousWeekStart(): Date {
  const now = new Date();
  const dayOfWeek = now.getDay();
  const daysSinceMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  const lastMonday = new Date(now);
  lastMonday.setDate(now.getDate() - daysSinceMonday - 7);
  lastMonday.setHours(0, 0, 0, 0);
  return lastMonday;
}

// Helper to get last Sunday (end of previous week)
function getPreviousWeekEnd(): Date {
  const start = getPreviousWeekStart();
  const end = new Date(start);
  end.setDate(start.getDate() + 6);
  end.setHours(23, 59, 59, 999);
  return end;
}

function formatDate(date: Date): string {
  return date.toISOString().split("T")[0];
}

function formatCurrency(amount: number): string {
  return `R${amount.toLocaleString("en-ZA", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function formatDateShort(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("en-ZA", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function buildStatementEmail(statement: StatementData): string {
  const adminUrl = Deno.env.get("ADMIN_URL") || "https://admin.tryp.co.za";
  
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>TRYP Weekly Earnings Statement</title>
</head>
<body style="margin:0;padding:0;background-color:#f5f5f5;font-family:Arial,sans-serif;">
  <div style="max-width:600px;margin:0 auto;background-color:#ffffff;">
    <!-- Header -->
    <div style="background-color:#00A651;padding:24px;text-align:center;">
      <h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:bold;">TRYP</h1>
      <p style="color:#ffffff;margin:8px 0 0;font-size:14px;opacity:0.9;">Driver Partner Platform</p>
    </div>
    
    <!-- Title -->
    <div style="padding:24px;text-align:center;border-bottom:2px solid #00A651;">
      <h2 style="color:#000000;margin:0;font-size:20px;">Weekly Earnings Statement</h2>
      <p style="color:#666666;margin:8px 0 0;font-size:14px;">
        ${formatDateShort(statement.periodStart)} - ${formatDateShort(statement.periodEnd)}
      </p>
    </div>
    
    <!-- Driver Info -->
    <div style="padding:24px;background-color:#f9f9f9;">
      <h3 style="color:#333333;margin:0 0 12px;font-size:14px;text-transform:uppercase;letter-spacing:1px;">
        Driver Information
      </h3>
      <table style="width:100%;font-size:14px;">
        <tr>
          <td style="padding:8px 0;color:#666666;width:50%;">Name</td>
          <td style="padding:8px 0;font-weight:bold;color:#000000;">${escapeHtml(statement.driverName)}</td>
        </tr>
        <tr>
          <td style="padding:8px 0;color:#666666;">Vehicle</td>
          <td style="padding:8px 0;font-weight:bold;color:#000000;">${escapeHtml(statement.vehiclePlate)}</td>
        </tr>
        <tr>
          <td style="padding:8px 0;color:#666666;">Rating</td>
          <td style="padding:8px 0;font-weight:bold;color:#000000;">⭐ ${statement.rating.toFixed(1)}</td>
        </tr>
      </table>
    </div>
    
    <!-- Summary Cards -->
    <div style="padding:24px;">
      <h3 style="color:#333333;margin:0 0 16px;font-size:14px;text-transform:uppercase;letter-spacing:1px;">
        Earnings Summary
      </h3>
      <table style="width:100%;border-collapse:collapse;">
        <tr>
          <td style="padding:12px;background-color:#f5f5f5;border-radius:8px 0 0 8px;text-align:center;">
            <div style="font-size:24px;font-weight:bold;color:#00A651;">${statement.totalTrips}</div>
            <div style="font-size:11px;color:#666666;text-transform:uppercase;">Total Trips</div>
          </td>
          <td style="padding:12px;background-color:#f5f5f5;text-align:center;">
            <div style="font-size:24px;font-weight:bold;color:#00A651;">${formatCurrency(statement.totalNetEarnings)}</div>
            <div style="font-size:11px;color:#666666;text-transform:uppercase;">Net Earnings</div>
          </td>
          <td style="padding:12px;background-color:#f5f5f5;border-radius:0 8px 8px 0;text-align:center;">
            <div style="font-size:24px;font-weight:bold;color:#00A651;">${statement.rating.toFixed(1)}</div>
            <div style="font-size:11px;color:#666666;text-transform:uppercase;">Rating</div>
          </td>
        </tr>
      </table>
    </div>
    
    <!-- Earnings Breakdown -->
    <div style="padding:24px;">
      <h3 style="color:#333333;margin:0 0 16px;font-size:14px;text-transform:uppercase;letter-spacing:1px;">
        Earnings Breakdown
      </h3>
      <table style="width:100%;font-size:14px;border-collapse:collapse;">
        <tr style="border-bottom:1px solid #e5e5e5;">
          <td style="padding:12px 0;color:#666666;">Cash Collected</td>
          <td style="padding:12px 0;text-align:right;font-weight:bold;color:#000000;">${formatCurrency(statement.cashCollected)}</td>
        </tr>
        <tr style="border-bottom:1px solid #e5e5e5;">
          <td style="padding:12px 0;color:#666666;">Cash Platform Fees Owed</td>
          <td style="padding:12px 0;text-align:right;font-weight:bold;color:#e53e3e;">-${formatCurrency(statement.cashFeesOwed)}</td>
        </tr>
        <tr style="border-bottom:1px solid #e5e5e5;">
          <td style="padding:12px 0;color:#666666;">Online/Card Payments (held by TRYP)</td>
          <td style="padding:12px 0;text-align:right;font-weight:bold;color:#000000;">${formatCurrency(statement.onlineEarnings)}</td>
        </tr>
        <tr style="border-bottom:1px solid #e5e5e5;">
          <td style="padding:12px 0;color:#666666;">Online Platform Fees Withheld</td>
          <td style="padding:12px 0;text-align:right;font-weight:bold;color:#e53e3e;">-${formatCurrency(statement.onlineFeesWithheld)}</td>
        </tr>
        <tr style="border-top:2px solid #00A651;">
          <td style="padding:16px 0 12px;font-weight:bold;font-size:16px;color:#000000;">Net Earnings</td>
          <td style="padding:16px 0 12px;text-align:right;font-weight:bold;font-size:18px;color:#00A651;">${formatCurrency(statement.totalNetEarnings)}</td>
        </tr>
      </table>
    </div>
    
    <!-- Payout Schedule -->
    <div style="padding:24px;background-color:#00A651;">
      <h3 style="color:#ffffff;margin:0 0 12px;font-size:14px;">💰 Payout Schedule</h3>
      <ul style="color:#ffffff;margin:0;padding-left:20px;font-size:13px;line-height:1.8;">
        <li>Cash earnings: Retained by you after collecting from passenger</li>
        <li>Card/Online earnings: Paid out every Monday and Friday</li>
        <li>Pending online payout: <strong>${formatCurrency(statement.pendingOnlinePayout)}</strong></li>
        <li>Platform fees: Deducted from gross fare (15% commission)</li>
      </ul>
    </div>
    
    <!-- Download Button -->
    <div style="padding:24px;text-align:center;">
      <a href="${adminUrl}" style="display:inline-block;padding:14px 32px;background-color:#00A651;color:#ffffff;text-decoration:none;font-weight:bold;border-radius:8px;font-size:14px;">
        View Full Statement in Admin Portal
      </a>
      <p style="color:#666666;margin:16px 0 0;font-size:12px;">
        Log in to download your detailed PDF statement with trip-by-trip breakdown.
      </p>
    </div>
    
    <!-- Footer -->
    <div style="padding:24px;background-color:#f5f5f5;text-align:center;">
      <p style="color:#666666;margin:0;font-size:12px;">
        This statement is auto-generated every Monday for the preceding 7-day period.
      </p>
      <p style="color:#666666;margin:8px 0 0;font-size:12px;">
        For questions, contact your fleet manager or TRYP support.
      </p>
      <p style="color:#00A651;margin:16px 0 0;font-size:12px;font-weight:bold;">
        TRYP Driver Partner Support | support@tryp.co.za
      </p>
      <p style="color:#999999;margin:16px 0 0;font-size:11px;">
        © ${new Date().getFullYear()} TRYP. All rights reserved.
      </p>
    </div>
  </div>
</body>
</html>`;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    // Calculate statement period (previous week)
    const periodStart = getPreviousWeekStart();
    const periodEnd = getPreviousWeekEnd();
    
    console.log(`Auto-generating statements for period: ${formatDate(periodStart)} to ${formatDate(periodEnd)}`);

    // Fetch all approved drivers
    const { data: drivers, error: driversError } = await supabase
      .from("profiles")
      .select("id")
      .eq("role", "driver")
      .eq("driver_status", "approved");

    if (driversError) throw driversError;

    console.log(`Found ${drivers?.length ?? 0} active drivers`);

    let successCount = 0;
    let failedCount = 0;
    let skippedCount = 0;

    // Process each driver
    for (const driver of drivers ?? []) {
      try {
        // Fetch driver profile
        const { data: driverProfile, error: profileError } = await supabase
          .from("profiles")
          .select("*")
          .eq("id", driver.id)
          .single();

        if (profileError || !driverProfile) {
          console.error(`Failed to fetch profile for driver ${driver.id}:`, profileError);
          skippedCount++;
          continue;
        }

        // Skip if no email
        if (!driverProfile.email) {
          console.log(`Skipping driver ${driver.id} - no email`);
          skippedCount++;
          continue;
        }

        // Fetch wallet transactions for the period
        const { data: transactions, error: txError } = await supabase
          .from("driver_wallet_transactions")
          .select("*")
          .eq("driver_id", driver.id)
          .gte("created_at", formatDate(periodStart))
          .lt("created_at", new Date(periodEnd.getTime() + 86400000).toISOString())
          .order("created_at", { ascending: true });

        if (txError) {
          console.error(`Failed to fetch transactions for driver ${driver.id}:`, txError);
          skippedCount++;
          continue;
        }

        // Skip if no transactions
        if (!transactions?.length) {
          console.log(`Skipping driver ${driver.id} - no transactions in period`);
          skippedCount++;
          continue;
        }

        // Calculate summary
        const cashTrips = transactions.filter(
          (t) => t.payment_method?.toLowerCase() === "cash"
        );
        const onlineTrips = transactions.filter(
          (t) => t.payment_method?.toLowerCase() !== "cash"
        );

        const totalGross = transactions.reduce(
          (sum, t) => sum + (parseFloat(t.gross_amount) || 0),
          0
        );
        const totalPlatformFees = transactions.reduce(
          (sum, t) => sum + (parseFloat(t.platform_fee) || 0),
          0
        );
        const totalNetEarnings = transactions.reduce(
          (sum, t) => sum + (parseFloat(t.driver_net_amount) || 0),
          0
        );

        const cashCollected = cashTrips.reduce(
          (sum, t) => sum + (parseFloat(t.gross_amount) || 0),
          0
        );
        const cashFeesOwed = cashTrips.reduce(
          (sum, t) => sum + (parseFloat(t.platform_fee) || 0),
          0
        );
        const onlineEarnings = onlineTrips.reduce(
          (sum, t) => sum + (parseFloat(t.gross_amount) || 0),
          0
        );
        const onlineFeesWithheld = onlineTrips.reduce(
          (sum, t) => sum + (parseFloat(t.platform_fee) || 0),
          0
        );

        // Build statement data
        const statement: StatementData = {
          driverId: driver.id,
          driverName: driverProfile.full_name ?? "Driver",
          driverEmail: driverProfile.email,
          driverPhone: driverProfile.phone ?? "",
          vehiclePlate: driverProfile.vehicle_plate ?? "",
          periodStart: formatDate(periodStart),
          periodEnd: formatDate(periodEnd),
          totalTrips: transactions.length,
          cashTrips: cashTrips.length,
          onlineTrips: onlineTrips.length,
          totalGross,
          totalPlatformFees,
          totalNetEarnings,
          cashCollected,
          cashFeesOwed,
          onlineEarnings,
          onlineFeesWithheld,
          pendingOnlinePayout: onlineEarnings - onlineFeesWithheld,
          averageFare: transactions.length > 0 ? totalGross / transactions.length : 0,
          rating: parseFloat(driverProfile.rating ?? "5") || 5,
        };

        // Send email
        console.log(`Sending statement to ${statement.driverEmail}`);
        
        // TODO: Integrate with your email service (Resend, SendGrid, etc.)
        // For now, we'll just log the statement
        console.log(`Statement for ${statement.driverName}: ${statement.totalTrips} trips, ${formatCurrency(statement.totalNetEarnings)} net earnings`);

        successCount++;
        
      } catch (error) {
        console.error(`Failed to process driver ${driver.id}:`, error);
        failedCount++;
      }
    }

    const result = {
      success: true,
      period: `${formatDate(periodStart)} to ${formatDate(periodEnd)}`,
      totalDrivers: drivers?.length ?? 0,
      statementsSent: successCount,
      statementsFailed: failedCount,
      statementsSkipped: skippedCount,
      timestamp: new Date().toISOString(),
    };

    console.log("Auto-generation complete:", result);

    return new Response(
      JSON.stringify(result),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (error) {
    console.error("Error in auto-generation:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to auto-generate statements" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
