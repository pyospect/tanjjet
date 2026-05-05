// Supabase Edge Function: Delete Account
// Deploy: supabase functions deploy delete-account

import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

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

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(authData.user.id)
    if (deleteError) {
      console.error("Delete user error:", deleteError)
      return json({ error: deleteError.message }, 500)
    }

    return json({ success: true })
  } catch (error) {
    console.error("Unhandled error:", error)
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
