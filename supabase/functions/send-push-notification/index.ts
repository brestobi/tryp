// Supabase Edge Function: send-push-notification
// Path: supabase/functions/send-push-notification/index.ts
//
// This function is triggered by a Supabase Database Webhook on the `rides` table.
// It sends a Firebase Cloud Messaging (FCM) push notification to the passenger
// or driver when a ride's status changes.
//
// SETUP:
//  1. Deploy: supabase functions deploy send-push-notification
//  2. Set secret: supabase secrets set FCM_SERVER_KEY=<your-firebase-server-key>
//  3. Create Database Webhook in Supabase Dashboard:
//     - Table: rides
//     - Events: UPDATE
//     - URL: https://<project-ref>.supabase.co/functions/v1/send-push-notification
//     - HTTP Headers: Authorization: Bearer <supabase-service-role-key>

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_URL = "https://fcm.googleapis.com/fcm/send";

interface RideRecord {
  id: string;
  passenger_id: string;
  driver_id: string | null;
  status: string;
  origin: string;
  destination: string;
  fare: number;
  ride_type: string;
  payment_method: string;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: RideRecord;
  old_record: RideRecord;
}

type NotificationConfig = {
  title: string;
  body: string;
  recipientId: string;
  data: Record<string, string>;
};

function buildNotificationForStatus(
  record: RideRecord,
  oldRecord: RideRecord
): NotificationConfig | null {
  const status = record.status;
  const prevStatus = oldRecord?.status;

  if (status === prevStatus) return null;

  // Notify PASSENGER about their ride status
  const passengerNotifs: Record<string, { title: string; body: string }> = {
    accepted: {
      title: "🚘 Driver Found!",
      body: `Your TRYP driver is on the way to ${record.origin}. Check the app for live tracking.`,
    },
    arrived: {
      title: "📍 Driver Arrived!",
      body: `Your driver is waiting at ${record.origin}. Show them your safety PIN to start your trip.`,
    },
    in_trip: {
      title: "🛣️ Trip Started!",
      body: `You're on your way to ${record.destination}. Estimated arrival coming soon.`,
    },
    completed: {
      title: "✅ Trip Complete!",
      body: `You've arrived at ${record.destination}. Fare: R${record.fare.toFixed(2)}. Please rate your driver.`,
    },
    cancelled: {
      title: "❌ Ride Cancelled",
      body: `Your ride to ${record.destination} has been cancelled. Tap to book a new ride.`,
    },
  };

  const notif = passengerNotifs[status];
  if (!notif) return null;

  return {
    title: notif.title,
    body: notif.body,
    recipientId: record.passenger_id,
    data: {
      ride_id: record.id,
      status: status,
      route: "/passenger/ride-tracking",
      type: "ride",
    },
  };
}

async function sendFcmNotification(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
) {
  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
  if (!fcmServerKey) {
    throw new Error("FCM_SERVER_KEY environment variable is not set");
  }

  const response = await fetch(FCM_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${fcmServerKey}`,
    },
    body: JSON.stringify({
      to: fcmToken,
      notification: {
        title,
        body,
        sound: "default",
        badge: "1",
        android_channel_id: "tryp_rides",
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      priority: "high",
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`FCM send failed: ${response.status} — ${error}`);
  }

  return await response.json();
}

serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    // Only handle UPDATE events on the rides table
    if (payload.type !== "UPDATE" || payload.table !== "rides") {
      return new Response(JSON.stringify({ message: "Ignored" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const notif = buildNotificationForStatus(payload.record, payload.old_record);
    if (!notif) {
      return new Response(JSON.stringify({ message: "No notification needed" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Initialize Supabase admin client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Look up the recipient's FCM push token
    const { data: profile, error } = await supabase
      .from("profiles")
      .select("push_token, full_name")
      .eq("id", notif.recipientId)
      .maybeSingle();

    if (error || !profile?.push_token) {
      console.warn(`No FCM token for user ${notif.recipientId}: ${error?.message}`);
      return new Response(
        JSON.stringify({ message: "No push token registered for user" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Send via FCM
    const result = await sendFcmNotification(
      profile.push_token,
      notif.title,
      notif.body,
      notif.data
    );

    console.log(`Push sent to ${profile.full_name} (${notif.recipientId}):`, result);

    return new Response(JSON.stringify({ success: true, result }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Edge Function error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
