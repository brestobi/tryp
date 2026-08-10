/**
 * TRYP Driver Statement Email Sender
 * 
 * This Edge Function sends a weekly earnings statement to a driver via email.
 * It generates an HTML email with the statement summary and provides a link
 * to download the full PDF statement.
 * 
 * Called by:
 * - Admin console "Send to Driver" button
 * - Auto-generation cron job (every Monday)
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

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("en-ZA", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function formatCurrency(amount: number): string {
  return `R${amount.toLocaleString("en-ZA", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
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
        ${formatDate(statement.periodStart)} - ${formatDate(statement.periodEnd)}
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

    // Get request body
    const { statement } = await req.json();
    
    if (!statement || !statement.driverEmail) {
      return new Response(
        JSON.stringify({ error: "Invalid statement data" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build email HTML
    const emailHtml = buildStatementEmail(statement);
    
    // Send email using Resend
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    
    if (!resendApiKey) {
      console.error("RESEND_API_KEY not configured");
      return new Response(
        JSON.stringify({ error: "Email service not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Sending statement to ${statement.driverEmail}`);
    console.log(`Statement period: ${statement.periodStart} to ${statement.periodEnd}`);
    console.log(`Total trips: ${statement.totalTrips}, Net earnings: R${statement.totalNetEarnings}`);
    
    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "TRYP Statements <noreply@updates.illdoit.space>",
        to: statement.driverEmail,
        subject: `TRYP Weekly Statement - ${formatDate(statement.periodStart)} to ${formatDate(statement.periodEnd)}`,
        html: emailHtml,
      }),
    });

    const emailResult = await emailResponse.json();

    if (!emailResponse.ok) {
      console.error("Email send failed:", emailResult);
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: emailResult }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Email sent successfully to ${statement.driverEmail}`);
    
    return new Response(
      JSON.stringify({
        success: true,
        message: `Statement sent to ${statement.driverName}`,
        email: statement.driverEmail,
        emailId: emailResult.id,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (error) {
    console.error("Error sending statement:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to send statement" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
