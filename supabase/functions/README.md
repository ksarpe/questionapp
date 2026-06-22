# Supabase Edge Functions

Server-side functions that hold privileged logic. Clients never write to
`profiles` / `subscriptions` directly, nor delete their own `auth.users` row —
only these functions (running with the `service_role` key) do.

| Function | Trigger | Writes |
|----------|---------|--------|
| `revenuecat-webhook` | RevenueCat webhook (POST) | `billing_events`, `subscriptions`, `profiles.is_premium` |
| `admob-ssv` | AdMob SSV callback (GET) | `ad_reward_events` (audit only) |
| `sync-entitlement` | App, on launch / after purchase (POST, JWT) | `profiles.is_premium` / `premium_until` |
| `delete-account` | App, Settings → Delete account (POST, JWT) | deletes `auth.users` (cascades to all user data) |

## Deploy

```bash
supabase link --project-ref <your-project-ref>

# DB schema
supabase db push        # applies migrations/20260618120000_init.sql

# Secrets (service-role key is injected automatically)
supabase secrets set REVENUECAT_WEBHOOK_SECRET="<long-random-secret>"

# Functions — public (Google / RevenueCat call them, not a logged-in user)
supabase functions deploy revenuecat-webhook --no-verify-jwt
supabase functions deploy admob-ssv          --no-verify-jwt

# Functions — JWT verified (the logged-in user/guest calls them)
supabase functions deploy sync-entitlement
supabase functions deploy delete-account
```

## Wiring on the client (Flutter)

- **RevenueCat:** `await Purchases.logIn(supabaseUserId);` so the webhook's
  `app_user_id` equals `auth.uid()`.
- **AdMob:** set `ServerSideVerificationOptions(userId: supabaseUserId)` before
  showing the rewarded ad, so the SSV callback can attribute the verified reward.

## How ad reveals work

`admob-ssv` is a **pure audit log** of verified rewards. The actual reveal is
client-driven: once the reward fires, the app calls the `reveal_ad_question` RPC,
which server-picks a random unseen question, records it in `question_seen`, and
returns its text. There is no question id to attribute server-side, so the SSV
callback grants nothing — it only records that the reward was genuine.
