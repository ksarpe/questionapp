# Release checklist — manual setup

Everything in the codebase degrades gracefully without keys (it runs on mock
data), but a **production release** needs the steps below. This is the single
source of truth for "things a human has to do outside the code". Tick them off
per platform before submitting to the stores.

> Legend: 🔑 secret/key · ☁️ server/console · 📱 native file · 🟢 done in code

---

## 1. Build-time config (`--dart-define`)

All secrets are read from `--dart-define` (see `lib/core/config/app_config.dart`)
so nothing is committed. Copy `env/example.json` → `env/dev.json` (git-ignored),
fill it in, and run `flutter run --dart-define-from-file=env/dev.json`.

| Key | Used for | Required |
|-----|----------|----------|
| `SUPABASE_URL` 🔑 | Backend / auth | Yes |
| `SUPABASE_ANON_KEY` 🔑 | Backend / auth | Yes |
| `GOOGLE_SERVER_CLIENT_ID` 🔑 | Native Google sign-in (Web OAuth client id) | If Google login |
| `REVENUECAT_API_KEY` 🔑 | Subscriptions / paywall | If Premium |
| `ADMOB_BANNER_ID` 🔑 | Banner unit | If banner ads |
| `ADMOB_REWARDED_ID` 🔑 | Rewarded unit (free-tier unlock) | If rewarded ads |
| `PRIVACY_POLICY_URL` | Privacy & data screen link | Store requirement (deferred) |
| `TERMS_OF_SERVICE_URL` | Privacy & data screen link | Store requirement (deferred) |

---

## 2. Supabase ☁️

```bash
supabase link --project-ref <your-project-ref>
supabase db push                 # applies everything in supabase/migrations/

# Secrets (service-role key is injected automatically)
supabase secrets set REVENUECAT_WEBHOOK_SECRET="<long-random-secret>"
supabase secrets set REVENUECAT_REST_API_KEY="sk_..."   # RevenueCat SECRET key
# optional, defaults to "premium":
# supabase secrets set PREMIUM_ENTITLEMENT="premium"

# Edge functions — public (Google / RevenueCat call them)
supabase functions deploy revenuecat-webhook --no-verify-jwt
supabase functions deploy admob-ssv          --no-verify-jwt
# Edge functions — JWT verified (the logged-in user calls them)
supabase functions deploy sync-entitlement
supabase functions deploy delete-account     # ← account deletion (store requirement)
```

- [ ] Migrations pushed
- [ ] Secrets set
- [ ] All four functions deployed
- [ ] Seed real question content into `questions` / `question_translations` and
      fill `daily_questions` (the init migration seeds only 3 demo questions)

---

## 3. RevenueCat ☁️ (Premium)

- [ ] Create the entitlement (default name `premium`) and products (App Store +
      Play Store).
- [ ] Build a Paywall in the RevenueCat dashboard (the app uses
      `purchases_ui_flutter`'s `presentPaywall`).
- [ ] **API keys** → `REVENUECAT_API_KEY` (public SDK key) and
      `REVENUECAT_REST_API_KEY` (secret, for the Supabase functions above).
- [ ] **Webhook** → point it at the deployed `revenuecat-webhook` URL with the
      `REVENUECAT_WEBHOOK_SECRET`.

---

## 4. AdMob ☁️ + 📱 (Ads & consent)

- [ ] Create the AdMob app + the banner & rewarded ad units → put the unit ids
      in `env/dev.json` (see §1).
- [ ] **Privacy & messaging** → create a **GDPR consent message** (and, on iOS,
      an ATT pre-prompt message). Without this, the UMP form shows nothing.
      The app gathers consent at launch via `lib/services/consent_service.dart`
      *before* initialising ads. 🟢
- [ ] Replace the **test App ID** with your real one in BOTH native files: 📱
      - `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID`
      - `ios/Runner/Info.plist` → `GADApplicationIdentifier`
- [ ] iOS: `NSUserTrackingUsageDescription` is set 🟢, but paste Google's **full
      SKAdNetwork list** into `Info.plist` (only one entry is stubbed):
      https://developers.google.com/admob/ios/3p-skadnetworks

---

## 5. Google Sign-In ☁️ + 📱

- [ ] Create OAuth clients: **Web** (its id → `GOOGLE_SERVER_CLIENT_ID`), **iOS**,
      **Android** (needs the app's SHA-1).
- [ ] Enable Google as a provider in Supabase Auth.
- [ ] iOS: the reversed-client-id URL scheme is in `Info.plist`
      (`CFBundleURLSchemes`) — make sure it matches your real iOS client. 📱

---

## 6. Notifications 📱 (daily reminder)

**Local notifications — no Firebase, no server, no APNs key.** This is by design:
the daily reminder is scheduled on-device (`lib/services/notification_service.dart`),
so there is **nothing to configure in any console**. 🟢

- Android: the required receivers + `RECEIVE_BOOT_COMPLETED` /
  `POST_NOTIFICATIONS` permissions are already in `AndroidManifest.xml`. 🟢
  Uses *inexact* alarms, so no `SCHEDULE_EXACT_ALARM` Play-Store declaration. 🟢
- iOS: permission is requested at runtime; no Info.plist string needed. 🟢
- [ ] (Optional) Replace the default notification icon with a real monochrome
      `@drawable/ic_notification` for Android.

---

## 7. App identity & store assets 📱

- [ ] App display name (currently `questionapp` / `Questionapp`), bundle id /
      application id, version (`pubspec.yaml`).
- [ ] App icons + splash.
- [ ] iOS: `pod install` on a Mac after every native-plugin change
      (ATT + local-notifications were added).
- [ ] Legal pages live + URLs wired (see §1) — **deferred**.
- [ ] Store listings (screenshots, descriptions, data-safety / privacy forms).

---

## Quick "is it wired?" map

| Concern | Code entry point |
|---------|------------------|
| Secrets | `lib/core/config/app_config.dart` |
| Consent (GDPR + ATT) | `lib/services/consent_service.dart` |
| Account deletion | `supabase/functions/delete-account/` + `SupabaseService.deleteAccount` |
| Daily reminder | `lib/services/notification_service.dart` |
| Premium gate | `sync-entitlement` / `revenuecat-webhook` + `profiles.is_premium` |
