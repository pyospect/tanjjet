// Supabase Edge Function: Send Push Notification
// Deploy: supabase functions deploy send-push-notification

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!
const APNS_HOST = Deno.env.get("APNS_HOST") ?? "api.push.apple.com"
const BUNDLE_ID = Deno.env.get("BUNDLE_ID") ?? "com.pyospect.tanjjet"

interface MessagePayload {
  message_id: string
  couple_id: string
  sender_id: string
  receiver_id: string
  content: string
}

interface CoupleRecord {
  user1_id: string
  user2_id: string | null
}

interface MessageRecord {
  couple_id: string
  sender_id: string
  content: string
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405)
    }

    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401)
    }

    const payload: MessagePayload = await req.json()
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    })
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    const { data: authData, error: authError } = await userClient.auth.getUser()
    if (authError || !authData.user) {
      return json({ error: "Unauthorized" }, 401)
    }

    if (authData.user.id !== payload.sender_id) {
      return json({ error: "Sender does not match authenticated user" }, 403)
    }

    const { data: couple, error: coupleError } = await adminClient
      .from("couples")
      .select("user1_id,user2_id")
      .eq("id", payload.couple_id)
      .single()

    const coupleRecord = couple as CoupleRecord | null
    if (coupleError || !coupleRecord) {
      return json({ error: "Couple not found" }, 404)
    }

    const expectedReceiverId = coupleRecord.user1_id === authData.user.id
      ? coupleRecord.user2_id
      : coupleRecord.user1_id
    if (!expectedReceiverId || expectedReceiverId !== payload.receiver_id) {
      return json({ error: "Invalid receiver" }, 400)
    }

    const { data: message, error: messageError } = await adminClient
      .from("messages")
      .select("couple_id,sender_id,content")
      .eq("id", payload.message_id)
      .single()

    const messageRecord = message as MessageRecord | null
    if (
      messageError ||
      !messageRecord ||
      messageRecord.couple_id !== payload.couple_id ||
      messageRecord.sender_id !== authData.user.id
    ) {
      return json({ error: "Message not found" }, 404)
    }

    const { data: tokens, error: tokenError } = await adminClient
      .from("device_tokens")
      .select("token")
      .eq("user_id", payload.receiver_id)

    if (tokenError) {
      console.error("Token query error:", tokenError)
      return json({ error: tokenError.message }, 500)
    }

    if (!tokens || tokens.length === 0) {
      return json({ message: "No tokens found" })
    }

    const { data: senderProfile } = await adminClient
      .from("profiles")
      .select("nickname")
      .eq("id", authData.user.id)
      .single()

    const senderName = senderProfile?.nickname || "파트너"
    const jwt = await createAPNsJWT()
    const body = messageRecord.content || payload.content

    const results = await Promise.all(
      tokens.map((tokenRecord) => sendPushNotification(tokenRecord.token, senderName, body, jwt))
    )

    return json({ success: true, results })
  } catch (error) {
    console.error("Unhandled error:", error)
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})

async function createAPNsJWT(): Promise<string> {
  const header = {
    alg: "ES256",
    kid: APNS_KEY_ID,
  }

  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: APNS_TEAM_ID,
    iat: now,
  }

  const encodedHeader = base64UrlEncode(JSON.stringify(header))
  const encodedClaims = base64UrlEncode(JSON.stringify(claims))
  const signatureInput = `${encodedHeader}.${encodedClaims}`
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(APNS_PRIVATE_KEY),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  )

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    privateKey,
    new TextEncoder().encode(signatureInput),
  )

  return `${signatureInput}.${base64UrlEncode(signature)}`
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const normalizedPem = pem.replace(/\\n/g, "\n")
  const base64 = normalizedPem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "")
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)

  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index)
  }

  return bytes.buffer
}

async function sendPushNotification(
  deviceToken: string,
  senderName: string,
  content: string,
  jwt: string,
): Promise<{ token: string; success: boolean; error?: string }> {
  const response = await fetch(`https://${APNS_HOST}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      Authorization: `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: senderName,
          body: content,
        },
        sound: "default",
        badge: 1,
      },
    }),
  })

  if (response.ok) {
    return { token: deviceToken, success: true }
  }

  const error = await response.text()
  console.error(`APNs error for ${deviceToken}:`, error)
  return { token: deviceToken, success: false, error }
}

function base64UrlEncode(value: string | ArrayBuffer): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : new Uint8Array(value)
  let binary = ""

  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "")
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
