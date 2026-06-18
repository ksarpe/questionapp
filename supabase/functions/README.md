# Supabase Edge Functions

Two server-side functions that hold the monetization logic. Clients never write
to `profiles` / `subscriptions` / `question_unlocks` directly — only these
functions (running with the `service_role` key) do.

| Function | Trigger | Writes |
|----------|---------|--------|
| `revenuecat-webhook` | RevenueCat webhook (POST) | `billing_events`, `subscriptions`, `profiles.is_premium` |
| `admob-ssv` | AdMob SSV callback (GET) | `ad_reward_events` (+ `question_unlocks` once enabled) |

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
```

## Wiring on the client (Flutter)

- **RevenueCat:** `await Purchases.logIn(supabaseUserId);` so the webhook's
  `app_user_id` equals `auth.uid()`.
- **AdMob:** set `ServerSideVerificationOptions(userId: supabaseUserId,
  customData: questionId)` before showing the rewarded ad, so the SSV callback
  knows who to credit and which question to unlock.

## Enabling ad-unlocks

`admob-ssv` currently only **logs** verified rewards. When you're ready to grant
unlocks, flip `GRANT_UNLOCKS = true` in `admob-ssv/index.ts` (the
`question_unlocks` table already exists from the migration).
