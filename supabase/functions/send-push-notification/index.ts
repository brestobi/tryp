import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DEFAULT_PROJECT_ID = "tryp-75e26";
const OAUTH_TOKEN_URL = "https://oauth2.googleapis.com/token";
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
type StringMap = Record<string, string>;

interface NotificationTableRecord {
  id: string;
  user_id: string;
  title: string;
  body: string;
  type: string;
  route_path?: string;
  payload?: Record<string, unknown>;
}
interface WebhookPayload {
  type?: "INSERT" | "UPDATE" | "DELETE";
  table?: string;
  record?: NotificationTableRecord;
  user_id?: string;
  recipient_id?: string;
  title?: string;
  body?: string;
  data?: Record<string, unknown>;
}
interface NotificationTarget {
  title: string;
  body: string;
  recipientId: string;
  data: StringMap;
}
interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function toStringMap(value: Record<string, unknown> | undefined): StringMap {
  return Object.fromEntries(
    Object.entries(value || {}).map(([key, item]) => [key, String(item)]),
  );
}

function base64UrlEncode(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlDecode(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function pemToBytes(pem: string): Uint8Array {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  return base64UrlDecode(body);
}

async function createGoogleAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64UrlEncode(JSON.stringify({
    iss: account.client_email,
    scope: FCM_SCOPE,
    aud: OAUTH_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  }));
  const unsignedToken = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedToken),
  );
  const assertion = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;
  const response = await fetch(OAUTH_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google OAuth token exchange failed HTTP ${response.status}: ${await response.text()}`);
  }
  const result = await response.json();
  if (!result.access_token) throw new Error("Google OAuth response did not include access_token.");
  return result.access_token as string;
}

function parsePayload(payload: WebhookPayload): NotificationTarget[] {
  if (payload.title && payload.body && (payload.user_id || payload.recipient_id)) {
    return [{
      title: payload.title,
      body: payload.body,
      recipientId: (payload.user_id || payload.recipient_id)!,
      data: toStringMap(payload.data),
    }];
  }
  if (payload.type === "INSERT" && payload.table === "notifications" && payload.record) {
    const record = payload.record;
    return [{
      title: record.title,
      body: record.body,
      recipientId: record.user_id,
      data: {
        notification_id: record.id,
        type: record.type || "system",
        route: record.route_path || "/notifications",
        ...toStringMap(record.payload),
      },
    }];
  }
  return [];
}

async function sendFcmNotification(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
  data: StringMap,
) {
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token: fcmToken,
        notification: { title, body },
        data,
        android: {
          priority: "high",
          notification: { channel_id: "tryp_notifications", sound: "default" },
        },
        apns: { payload: { aps: { alert: { title, body }, sound: "default", badge: 1 } } },
      },
    }),
  });
  if (!response.ok) {
    throw new Error(`FCM HTTP v1 send failed HTTP ${response.status}: ${await response.text()}`);
  }
  return await response.json();
}

serve(async (request: Request) => {
  if (request.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  try {
    const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
    if (!expectedSecret || request.headers.get("x-tryp-push-secret") !== expectedSecret) {
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = (await request.json()) as WebhookPayload;
    const targets = parsePayload(payload);
    if (targets.length === 0) {
      return new Response(JSON.stringify({ message: "No push notification actions required" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const rawServiceAccount = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!rawServiceAccount) throw new Error("FCM_SERVICE_ACCOUNT_JSON is not configured.");
    const serviceAccount = JSON.parse(rawServiceAccount) as ServiceAccount;
    const projectId = Deno.env.get("FCM_PROJECT_ID") || serviceAccount.project_id || DEFAULT_PROJECT_ID;
    const accessToken = await createGoogleAccessToken(serviceAccount);
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const results: Array<Record<string, unknown>> = [];

    for (const target of targets) {
      const { data: profile, error } = await supabase
        .from("profiles")
        .select("push_token, full_name")
        .eq("id", target.recipientId)
        .maybeSingle();
      if (error) throw error;
      if (!profile?.push_token) {
        results.push({ recipientId: target.recipientId, status: "no_token" });
        continue;
      }

      try {
        const result = await sendFcmNotification(
          accessToken,
          projectId,
          profile.push_token as string,
          target.title,
          target.body,
          target.data,
        );
        results.push({ recipientId: target.recipientId, status: "sent", result });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        const isUnregisteredToken =
          message.includes("UNREGISTERED") ||
          message.includes("NotRegistered") ||
          message.includes("registration-token-not-registered");

        if (!isUnregisteredToken) throw error;

        // FCM tokens are invalidated when an app is uninstalled, restored, or
        // its Firebase installation changes. Remove the stale token so future
        // notifications do not fail and the next app session can re-register.
        await supabase
          .from("profiles")
          .update({
            push_token: null,
            push_token_updated_at: new Date().toISOString(),
          })
          .eq("id", target.recipientId);

        results.push({
          recipientId: target.recipientId,
          status: "invalid_token_cleared",
        });
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[send-push-notification] Error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
