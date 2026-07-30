import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Initialize Supabase Client
const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);

serve(async (req) => {
  try {
    const { ride_id, passenger_id } = await req.json();

    // 1. Fetch trip details
    const { data: ride, error: rideError } = await supabase
      .from("rides")
      .select("*, passenger_id")
      .eq("id", ride_id)
      .single();

    if (rideError) throw rideError;

    // 2. Fetch passenger email
    const { data: { user }, error: authError } = await supabase.auth.admin.getUserById(passenger_id);
    if (authError || !user) throw new Error("Passenger not found");
    const email = user.email;

    // 3. Send email via Supabase's email provider (or Resend/SendGrid)
    // For this implementation, I'm logging the action. 
    // You'd replace this with an actual API call to your mail provider.
    console.log(`Sending invoice to ${email} for ride ${ride_id}. Fare: ${ride.fare}`);
    
    // Example (pseudo-code):
    // await fetch("https://api.resend.com/emails", {
    //   method: "POST",
    //   headers: { "Authorization": `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "Content-Type": "application/json" },
    //   body: JSON.stringify({
    //     from: "noreply@tryp.app",
    //     to: email,
    //     subject: "Your Trip Invoice",
    //     html: `<h1>Trip Summary</h1><p>Fare: $${ride.fare}</p>`
    //   })
    // });

    return new Response(JSON.stringify({ message: "Email sent" }), {
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
