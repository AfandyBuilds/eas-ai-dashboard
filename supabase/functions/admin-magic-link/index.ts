// ============================================================
// EAS AI Adoption Dashboard — Admin Magic Link Generator
// Supabase Edge Function: admin-magic-link
//
// Generates a magic-link login URL for any user.
// Only callable by authenticated admin users.
//
// POST / { email: string }
// Returns: { action_link, email }
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed. Use POST." }, 405);
  }

  try {
    // ---- 1. Authenticate the caller using their JWT ----
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return jsonResponse({ error: "Missing or invalid Authorization header." }, 401);
    }

    const token = authHeader.replace("Bearer ", "");

    // Create a client scoped to the caller's JWT (RLS applies)
    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    // Verify the token
    const {
      data: { user: callerAuth },
      error: authError,
    } = await callerClient.auth.getUser(token);

    if (authError || !callerAuth) {
      return jsonResponse({ error: "Invalid or expired token." }, 401);
    }

    // ---- 2. Verify caller is an admin ----
    const { data: callerProfile, error: profileError } = await callerClient
      .from("users")
      .select("id, role, is_active")
      .eq("auth_id", callerAuth.id)
      .single();

    if (profileError || !callerProfile) {
      return jsonResponse({ error: "Caller profile not found." }, 403);
    }

    if (callerProfile.role !== "admin") {
      return jsonResponse({ error: "Forbidden. Only admins can generate magic links." }, 403);
    }

    if (!callerProfile.is_active) {
      return jsonResponse({ error: "Caller account is deactivated." }, 403);
    }

    // ---- 3. Parse the target email ----
    const body = await req.json();
    const targetEmail = body?.email?.trim()?.toLowerCase();

    if (!targetEmail) {
      return jsonResponse({ error: "Missing required field: email" }, 400);
    }

    // ---- 4. Generate the magic link using the service-role client ----
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    const { data: linkData, error: linkError } =
      await adminClient.auth.admin.generateLink({
        type: "magiclink",
        email: targetEmail,
      });

    if (linkError) {
      console.error("generateLink error:", linkError);
      return jsonResponse(
        { error: `Failed to generate magic link: ${linkError.message}` },
        500
      );
    }

    const actionLink = linkData?.properties?.action_link;
    if (!actionLink) {
      return jsonResponse({ error: "No action_link returned from Supabase." }, 500);
    }

    // ---- 5. Log the action for auditing ----
    console.log(
      `[AUDIT] Admin ${callerProfile.id} (${callerAuth.email}) generated magic link for ${targetEmail}`
    );

    return jsonResponse({
      action_link: actionLink,
      email: targetEmail,
      generated_by: callerAuth.email,
      generated_at: new Date().toISOString(),
    });
  } catch (err) {
    console.error("admin-magic-link error:", err);
    return jsonResponse(
      { error: `Internal error: ${err.message || "Unknown error"}` },
      500
    );
  }
});
