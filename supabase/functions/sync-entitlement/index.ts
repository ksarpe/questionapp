// ============================================================================
// sync-entitlement  ->  reconciles `profiles.is_premium` with RevenueCat NOW.
//
// Why this exists (alongside the inbound revenue-cat-webhook):
//   The webhook is RevenueCat PUSHING us state. It is async (seconds–minutes
//   late) and a single point of failure — if its URL/secret is misconfigured,
//   NOTHING ever sets `profiles.is_premium`, so every "premium" user keeps
//   getting locked questions/smaczki even though their device shows PRO.
//
//   This function is the app PULLING the truth on demand: the client calls it
//   right after a purchase/restore and on launch, we ask RevenueCat's REST API
//   for this exact identity's entitlements, and write the result synchronously.
//   That closes the post-purchase race AND makes the gate work even if the
//   inbound webhook never lands. The webhook stays as the path for renewals /
//   expiries / cross-device changes the app isn't open to observe.
//
// Setup
//   1. RevenueCat dashboard > API keys: copy the SECRET key (starts `sk_`).
//        supabase secrets set REVENUECAT_REST_API_KEY="sk_..."
//      (Optional, same value as the webhook) the entitlement that == premium:
//        supabase secrets set PREMIUM_ENTITLEMENT="premium"
//   2. Deploy (JWT verification ON — the caller is the logged-in user/guest):
//        supabase functions deploy sync-entitlement
//
// Auth: the client invokes this with its Supabase session, so we read the
// caller from their JWT — they can only ever sync THEIR OWN entitlement. The
// app_user_id in RevenueCat is the same auth.uid() (see Purchases.logIn).
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const PREMIUM_ENTITLEMENT = Deno.env.get("PREMIUM_ENTITLEMENT") ?? "premium";
const RC_API_KEY = Deno.env.get("REVENUECAT_REST_API_KEY");

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

// Service-role client for the write (bypasses RLS; profiles has no write policy).
const admin = createClient(
  SUPABASE_URL,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  // --- Identify the caller from their Supabase JWT (never trust a body uid) ---
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json(401, { error: "unauthorized" });

  const userClient = createClient(
    SUPABASE_URL,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) return json(401, { error: "unauthorized" });

  if (!RC_API_KEY) {
    console.error("REVENUECAT_REST_API_KEY not set — cannot reconcile.");
    return json(500, { error: "not_configured" });
  }

  // --- Ask RevenueCat for THIS identity's entitlements ---
  // app_user_id == auth.uid() because the app calls Purchases.logIn(uid).
  let isActive = false;
  let expiresAt: string | null = null;
  try {
    const rcRes = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(user.id)}`,
      { headers: { Authorization: `Bearer ${RC_API_KEY}` } },
    );

    if (rcRes.ok) {
      const payload = await rcRes.json();
      const ent = payload?.subscriber?.entitlements?.[PREMIUM_ENTITLEMENT];
      if (ent) {
        // expires_date null = lifetime/non-expiring; otherwise active until then.
        const exp = (ent.expires_date as string | null) ?? null;
        isActive = exp === null || new Date(exp).getTime() > Date.now();
        expiresAt = isActive ? exp : null;
      }
    } else if (rcRes.status === 404) {
      // Unknown subscriber = never purchased on this identity → not premium.
      isActive = false;
    } else {
      console.error("RevenueCat API error", rcRes.status, await rcRes.text());
      return json(502, { error: "revenuecat_error" });
    }
  } catch (e) {
    console.error("RevenueCat fetch failed:", e);
    return json(502, { error: "revenuecat_unreachable" });
  }

  // --- Reflect onto the fast flag the RLS gate / RPCs read ---
  const { error: updErr } = await admin
    .from("profiles")
    .update({ is_premium: isActive, premium_until: isActive ? expiresAt : null })
    .eq("id", user.id);
  if (updErr) {
    console.error("profiles update failed:", updErr);
    return json(500, { error: "db_error" });
  }

  return json(200, { is_premium: isActive, premium_until: expiresAt });
});
