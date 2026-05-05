// Supabase Edge Function: Disconnect Couple
// Deploy: supabase functions deploy disconnect-couple

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

interface ProfileRecord {
  couple_id: string | null
}

interface CoupleRecord {
  user1_id: string
  user2_id: string | null
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

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    })
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    const { data: authData, error: authError } = await userClient.auth.getUser()
    if (authError || !authData.user) {
      return json({ error: "Unauthorized" }, 401)
    }

    const userId = authData.user.id
    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .select("couple_id")
      .eq("id", userId)
      .single()

    const profileRecord = profile as ProfileRecord | null
    if (profileError || !profileRecord?.couple_id) {
      return json({ success: false, message: "No couple found" })
    }

    const coupleId = profileRecord.couple_id
    const { data: couple, error: coupleError } = await adminClient
      .from("couples")
      .select("user1_id,user2_id")
      .eq("id", coupleId)
      .single()

    const coupleRecord = couple as CoupleRecord | null
    if (coupleError || !coupleRecord) {
      await clearProfiles(adminClient, coupleId)
      return json({ success: false, message: "Couple record not found" })
    }

    if (coupleRecord.user1_id !== userId && coupleRecord.user2_id !== userId) {
      return json({ error: "User is not a member of this couple" }, 403)
    }

    await deleteMessages(adminClient, coupleId)
    await clearProfiles(adminClient, coupleId)

    const { error: deleteError } = await adminClient
      .from("couples")
      .delete()
      .eq("id", coupleId)

    if (deleteError) {
      console.error("Disconnect couple delete error:", deleteError)
      return json({ error: deleteError.message }, 500)
    }

    return json({ success: true })
  } catch (error) {
    console.error("Unhandled error:", error)
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})

async function deleteMessages(adminClient: ReturnType<typeof createClient>, coupleId: string) {
  const { error } = await adminClient
    .from("messages")
    .delete()
    .eq("couple_id", coupleId)

  if (error) {
    throw error
  }
}

async function clearProfiles(adminClient: ReturnType<typeof createClient>, coupleId: string) {
  const { error } = await adminClient
    .from("profiles")
    .update({ couple_id: null })
    .eq("couple_id", coupleId)

  if (error) {
    throw error
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
