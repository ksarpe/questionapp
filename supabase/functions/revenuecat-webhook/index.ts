// ============================================================================
// RevenueCat webhook  ->  updates `subscriptions` + `profiles.is_premium`.
//
// Setup
//   1. RevenueCat dashboard: Project > Integrations > Webhooks
//        URL:  https://<project-ref>.functions.supabase.co/revenuecat-webhook
//        Authorization header: pick a long random secret.
//   2. Store the SAME secret for this function:
//        supabase secrets set REVENUECAT_WEBHOOK_SECRET="<that-secret>"
//   3. In the Flutter app, tie RevenueCat to the Supabase user:
//        await Purchases.logIn(supabaseUserId);   // app_user_id == auth.uid()
//   4. Deploy:
//        supabase functions deploy revenuecat-webhook --no-verify-jwt
//      (--no-verify-jwt because RevenueCat calls it, not a logged-in user;
//       we authenticate via the Authorization secret instead.)
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

// Event types that, on their own, mean the entitlement is granted right now.
const GRANTING_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "PRODUCT_CHANGE",
  "SUBSCRIPTION_EXTENDED",
  "TRANSFER",
]);

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // --- 1) Authenticate the caller via the shared secret ---
  if (!WEBHOOK_SECRET || req.headers.get("Authorization") !== WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  const body = await req.json().catch(() => null);
  const event = body?.event;
  if (!event?.id) return new Response("No event", { status: 400 });

  const userId: string | undefined = event.app_user_id; // == auth.uid()
  const entitlement: string =
    event.entitlement_ids?.[0] ?? event.entitlement_id ?? "premium";

  // --- 2) Idempotency: log the raw event; a duplicate event_id means we
  //         already handled it, so just ACK. ---
  const { error: logErr } = await supabase.from("billing_events").insert({
    event_id: event.id,
    user_id: userId ?? null,
    type: event.type,
    payload: body,
  });
  if (logErr) {
    if (logErr.code === "23505") return new Response("Already processed", { status: 200 });
    console.error("billing_events insert failed:", logErr);
    return new Response("DB error", { status: 500 });
  }

  // We can only mutate state for an identifiable user.
  if (!userId) return new Response("OK (no app_user_id)", { status: 200 });

  // --- 3) Decide the current entitlement state. Trust the expiry when present. ---
  const expiresMs: number | undefined = event.expiration_at_ms;
  const expiresAt = expiresMs ? new Date(expiresMs).toISOString() : null;

  let isActive: boolean;
  if (["EXPIRATION", "BILLING_ISSUE", "SUBSCRIPTION_PAUSED"].includes(event.type)) {
    isActive = false;
  } else if (expiresMs) {
    isActive = expiresMs > Date.now();       // e.g. CANCELLATION stays active until period end
  } else {
    isActive = GRANTING_TYPES.has(event.type); // lifetime / non-renewing
  }

  // --- 4) Upsert the per-entitlement subscription row ---
  const { error: subErr } = await supabase.from("subscriptions").upsert({
    user_id: userId,
    rc_app_user_id: userId,
    entitlement,
    product_id: event.product_id ?? null,
    store: event.store ?? null,
    status: event.type,
    is_active: isActive,
    current_period_end: expiresAt,
    will_renew: !["CANCELLATION", "EXPIRATION", "BILLING_ISSUE"].includes(event.type),
    updated_at: new Date().toISOString(),
  }, { onConflict: "user_id,entitlement" });
  if (subErr) {
    console.error("subscriptions upsert failed:", subErr);
    return new Response("DB error", { status: 500 });
  }

  // --- 5) Reflect onto the fast flag the RLS gate reads ---
  const { error: profErr } = await supabase
    .from("profiles")
    .update({ is_premium: isActive, premium_until: expiresAt })
    .eq("id", userId);
  if (profErr) {
    console.error("profiles update failed:", profErr);
    return new Response("DB error", { status: 500 });
  }

  return new Response("OK", { status: 200 });
});
