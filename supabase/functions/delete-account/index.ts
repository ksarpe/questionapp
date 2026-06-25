// ============================================================================
// delete-account  ->  permanently deletes the caller's account and ALL its data.
//
// Why this exists:
//   App Store Guideline 5.1.1(v) and Google Play both REQUIRE an in-app way to
//   delete the account. A client cannot delete its own `auth.users` row, so this
//   service-role function does it on the caller's behalf.
//
//   Deleting the auth user CASCADES across the whole schema (see the migrations):
//     profiles (+ streak/credit columns), subscriptions, question_seen,
//     question_votes, question_favorites   -> ON DELETE CASCADE  (rows removed)
//     billing_events, ad_reward_events     -> ON DELETE SET NULL (kept as an
//                                             anonymized audit, user_id nulled)
//   so this single call removes or anonymizes every piece of personal data.
//
//   IMPORTANT: this deletes the Supabase identity only. It does NOT cancel an
//   active App Store / Play Store subscription — neither store lets an app cancel
//   billing on the user's behalf. The app tells the user to cancel in the store.
//
// Deploy (JWT verification ON — the caller is the logged-in user/guest):
//   supabase functions deploy delete-account
//
// Auth: the caller is read from their Supabase JWT, so a user can only ever
// delete THEIR OWN account; a body-supplied id is never trusted.
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

// Service-role client for the privileged delete (clients can't touch auth.users).
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

  // --- Permanently delete the auth user; FKs cascade/null out all their data ---
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) {
    console.error("deleteUser failed:", delErr);
    return json(500, { error: "delete_failed" });
  }

  return json(200, { deleted: true });
});
