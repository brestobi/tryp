import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_URL = "https://fcm.googleapis.com/fcm/send";

interface DirectPayload {
  user_id?: string;
  recipient_id?: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface NotificationTableRecord {
  id: string;
  user_id: string;
  title: string;
  body: string;
  type: string;
  route_path?: string;
  payload?: Record<string, string>;
}

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
  type?: "INSERT" | "UPDATE" | "DELETE";
  table?: string;
  record?: NotificationTableRecord | RideRecord;
  old_record?: RideRecord;
  // Direct payload fallback
  user_id?: string;
  recipient_id?: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
}

interface NotificationTarget {
  title: string;
  body: string;
  recipientId: string;
  data: Record<string, string>;
}

function parseWebhookOrDirectPayload(payload: WebhookPayload): NotificationTarget[] {
  const targets: NotificationTarget[] = [];

  // Case 1: Direct payload
  if (payload.title && payload.body && (payload.user_id || payload.recipient_id)) {
    targets.push({
      title: payload.title,
      body: payload.body,
      recipientId: (payload.user_id || payload.recipient_id)!,
      data: payload.data || {},
    });
    return targets;
  }

  // Case 2: INSERT on notifications table
  if (payload.type === "INSERT" && payload.table === "notifications" && payload.record) {
    const rec = payload.record as NotificationTableRecord;
    targets.push({
      title: rec.title,
      body: rec.body,
      recipientId: rec.user_id,
      data: {
        notification_id: rec.id,
        type: rec.type || "system",
        route: rec.route_path || "/notifications",
        ...(rec.payload || {}),
      },
    });
    return targets;
  }

  // Case 3: UPDATE on rides table (Ride status changes)
  if (payload.type === "UPDATE" && payload.table === "rides" && payload.record) {
    const record = payload.record as RideRecord;
    const oldRecord = payload.old_record as RideRecord;
    const status = record.status;
    const prevStatus = oldRecord?.status;

    if (status === prevStatus) return targets;

    // Passenger Notifications
    const passengerNotifs: Record<string, { title: string; body: string }> = {
      accepted: {
        title: "🚘 Driver Found!",
        body: `Your TRYP driver is on the way to ${record.origin}. Tap to view live map tracking.`,
      },
      arrived: {
        title: "📍 Driver Arrived!",
        body: `Your driver has arrived at ${record.origin}. Meet your driver outside.`,
      },
      in_trip: {
        title: "🛣️ Trip Started!",
        body: `En route to ${record.destination}. Have a safe journey with TRYP!`,
      },
      completed: {
        title: "✅ Trip Completed!",
        body: `You've arrived at ${record.destination}. Total fare: R${(record.fare || 0).toFixed(2)}.`,
      },
      cancelled: {
        title: "❌ Ride Cancelled",
        body: `Your ride to ${record.destination} was cancelled. Tap to request a new ride.`,
      },
    };

    if (passengerNotifs[status] && record.passenger_id) {
      targets.push({
        title: passengerNotifs[status].title,
        body: passengerNotifs[status].body,
        recipientId: record.passenger_id,
        data: {
          ride_id: record.id,
          status: status,
          route: "/passenger/home",
          type: "ride",
        },
      });
    }

    // Driver Notifications
    if (status === "requested" && record.driver_id) {
      targets.push({
        title: "🚗 New Ride Request!",
        body: `New ${record.ride_type || "TRYP"} request near ${record.origin}. Tap to accept.`,
        recipientId: record.driver_id,
        data: {
          ride_id: record.id,
          status: status,
          route: "/driver/active-trip",
          type: "ride",
        },
      });
    } else if (status === "cancelled" && record.driver_id) {
      targets.push({
        title: "⚠️ Trip Cancelled by Passenger",
        body: `The passenger cancelled the trip to ${record.destination}.`,
        recipientId: record.driver_id,
        data: {
          ride_id: record.id,
          status: status,
          route: "/driver/home",
          type: "ride",
        },
      });
    }
  }

  return targets;
}

async function sendFcmNotification(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
) {
  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
  if (!fcmServerKey) {
    console.warn("FCM_SERVER_KEY is not set in Edge Function secrets. Skipping FCM HTTP send.");
    return { skipped: true, reason: "FCM_SERVER_KEY missing" };
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
        android_channel_id: "tryp_notifications",
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      priority: "high",
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`FCM send failed HTTP ${response.status}: ${errorText}`);
  }

  return await response.json();
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const payload: WebhookPayload = await req.json();
    const targets = parseWebhookOrDirectPayload(payload);

    if (targets.length === 0) {
      return new Response(JSON.stringify({ message: "No push notification actions required" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const results = [];

    for (const target of targets) {
      // Look up recipient's push_token
      const { data: profile } = await supabase
        .from("profiles")
        .select("push_token, full_name")
        .eq("id", target.recipientId)
        .maybeSingle();

      if (!profile?.push_token) {
        console.log(`[send-push-notification] User ${target.recipientId} has no push_token registered.`);
        results.push({ recipientId: target.recipientId, status: "no_token" });
        continue;
      }

      const res = await sendFcmNotification(
        profile.push_token,
        target.title,
        target.body,
        target.data
      );

      console.log(`[send-push-notification] Sent to ${profile.full_name || target.recipientId}:`, res);
      results.push({ recipientId: target.recipientId, status: "sent", res });
    }

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[send-push-notification] Error:", err);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
