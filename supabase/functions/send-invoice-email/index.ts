import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createTransport } from "npm:nodemailer";

// Initialize Supabase Client
const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);

// Setup SMTP Transporter
const transporter = createTransport({
  host: Deno.env.get("SMTP_HOST"),
  port: 587,
  secure: false, // true for 465, false for other ports
  auth: {
    user: "resend", // Standard user for Resend SMTP
    pass: Deno.env.get("SMTP_PASSWORD"), // Your Resend API Key
  },
});

serve(async (req) => {
  try {
    const { ride_id, passenger_id } = await req.json();

    // 1. Fetch data
    const { data: ride, error: rideError } = await supabase
      .from("rides")
      .select("*")
      .eq("id", ride_id)
      .single();
    if (rideError) throw rideError;

    const { data: { user }, error: authError } = await supabase.auth.admin.getUserById(passenger_id);
    if (authError || !user) throw new Error("Passenger not found");
    const email = user.email;

    // 2. Generate HTML Invoice
    const htmlTemplate = `<html><body><h1>Invoice ${ride_id}</h1><p>Fare: $${ride.fare}</p></body></html>`;

    // 3. Convert HTML to PDF (via an external PDF conversion API - Example)
    // IMPORTANT: Replace with your actual PDF conversion service call
    const pdfResponse = await fetch("https://api.pdfservice.example/convert", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": "Bearer YOUR_PDF_API_KEY" },
        body: JSON.stringify({ html: htmlTemplate })
    });
    const pdfBuffer = await pdfResponse.arrayBuffer();

    // 4. Send Email via SMTP
    await transporter.sendMail({
      from: 'billing@tryp.app',
      to: email,
      subject: 'Your Official Invoice',
      html: '<p>Please find your invoice attached.</p>',
      attachments: [{
        filename: 'invoice.pdf',
        content: Buffer.from(pdfBuffer)
      }]
    });

    return new Response(JSON.stringify({ message: "Invoice sent via SMTP" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
