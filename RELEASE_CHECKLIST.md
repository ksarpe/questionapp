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

| Key                          | Used for                                    | Required                     |
| ---------------------------- | ------------------------------------------- | ---------------------------- |
| `SUPABASE_URL` 🔑            | Backend / auth                              | Yes                          |
| `SUPABASE_ANON_KEY` 🔑       | Backend / auth                              | Yes                          |
| `GOOGLE_SERVER_CLIENT_ID` 🔑 | Native Google sign-in (Web OAuth client id) | If Google login              |
| `REVENUECAT_API_KEY` 🔑      | Subscriptions / paywall                     | If Premium                   |
| `ADMOB_BANNER_ID` 🔑         | Banner unit                                 | If banner ads                |
| `ADMOB_REWARDED_ID` 🔑       | Rewarded unit (free-tier unlock)            | If rewarded ads              |
| `PRIVACY_POLICY_URL`         | Privacy & data screen link                  | Defaults to debatly.app 🟢   |
| `TERMS_OF_SERVICE_URL`       | Privacy & data screen link                  | Defaults to debatly.app 🟢   |
| `DELETE_ACCOUNT_URL`         | Privacy & data screen + Play data-safety    | Defaults to debatly.app 🟢   |
| `SENTRY_DSN` 🔑              | Crash & error reporting                     | If error monitoring (see §10)|
| `SENTRY_ENVIRONMENT`         | Splits dev/prod events in Sentry            | Defaults per build mode 🟢   |
| `SENTRY_TRACES_SAMPLE_RATE`  | Perf tracing sample rate (0.0–1.0)          | Defaults to `0.2` 🟢         |

> The three legal URLs are **baked into `AppConfig`** (public, non-secret) so the
> links always work; the `--dart-define` keys above only override them. They
> point at `https://debatly.app/{privacy,terms,delete-account}` — make sure
> those pages are actually live before submitting.

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
- [x] All four functions deployed
- [ ] Seed real question content into `questions` / `question_translations` and
      fill `daily_questions` (the init migration seeds only 3 demo questions)

### Auth hardening (Dashboard → Authentication → Sign In / Providers)

These two are GoTrue settings, not code — they can't be set by a migration.

- [ ] **Email confirmation ON** (Providers → Email → "Confirm email"). Anti-farm:
      `is_real_account` now also requires a confirmed email/phone before granting
      the daily free-unlock credit, so leaving autoconfirm on lets throwaway
      emails mint credits. (Google sign-in is auto-confirmed, so it's unaffected.)
- [ ] **Leaked-password protection ON** (Sign In → Passwords) — blocks passwords
      found in HaveIBeenPwned. Flagged by the Supabase security advisor.

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
- [ ] **SSV callback URL (REQUIRED)** → on the rewarded unit set Server-Side
      Verification to the deployed `admob-ssv` URL
      (`https://<project-ref>.functions.supabase.co/admob-ssv`). The reveal gate
      now requires a verified SSV reward (`reveal_ad_question`), so without this
      callback no free reveal beyond the small grace buffer ever succeeds. Test
      ad units fire SSV too, so the loop is verifiable before launch.
- [ ] **Privacy & messaging** → create a **GDPR consent message** (and, on iOS,
      an ATT pre-prompt message). Without this, the UMP form shows nothing.
      The app gathers consent at launch via `lib/services/consent_service.dart`
      _before_ initialising ads. 🟢
- [ ] Replace the **test App ID** with your real one in BOTH native files: 📱 - `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID` - `ios/Runner/Info.plist` → `GADApplicationIdentifier`
- [ ] iOS: `NSUserTrackingUsageDescription` is set 🟢, but paste Google's **full
      SKAdNetwork list** into `Info.plist` (only one entry is stubbed):
      https://developers.google.com/admob/ios/3p-skadnetworks

---

## 5. Social sign-in ☁️ + 📱

The auth sheet shows **Google on Android** and **Sign in with Apple on iOS**
only (one per platform — `defaultTargetPlatform` branch in `auth_screen.dart`);
email/password is on both. 🟢

### Google (Android)

- [ ] Create OAuth clients: **Web** (its id → `GOOGLE_SERVER_CLIENT_ID`), **iOS**,
      **Android** (needs the app's SHA-1).
- [ ] Enable Google as a provider in Supabase Auth (add the **Web** client id to
      "Authorized Client IDs" — the ID token's `aud` is the Web client id).
- [ ] iOS: the reversed-client-id URL scheme is in `Info.plist`
      (`CFBundleURLSchemes`) — only needed if you ever re-enable Google on iOS. 📱

### Apple (iOS) — required by App Store guideline 4.8

Implemented natively via `sign_in_with_apple` + Supabase `signInWithIdToken`
(SHA-256 nonce); see `SupabaseService.signInWithApple`. 🟢 Manual setup:

- [ ] **Apple Developer** → enable the *Sign in with Apple* capability on the App
      ID for `com.aknsoftware.questionapp`.
- [ ] **Xcode** → Runner target → Signing & Capabilities → **+ Sign in with
      Apple**. This wires `ios/Runner/Runner.entitlements` (the
      `com.apple.developer.applesignin` key is already in the file 🟢) — make sure
      `CODE_SIGN_ENTITLEMENTS` points at it. 📱
- [ ] **Supabase** → Auth → Providers → **Apple** ON; add the app **bundle id**
      `com.aknsoftware.questionapp` to the provider's authorized client ids
      (native iOS sends a token whose `aud` is the bundle id — no client
      secret/Service ID needed for the native flow).
- [ ] iOS only: nothing else in `Info.plist`; `pod install` after the plugin add.

---

## 6. Notifications 📱 (daily reminder)

**Local notifications — no Firebase, no server, no APNs key.** This is by design:
the daily reminder is scheduled on-device (`lib/services/notification_service.dart`),
so there is **nothing to configure in any console**. 🟢

- Android: the required receivers + `RECEIVE_BOOT_COMPLETED` /
  `POST_NOTIFICATIONS` permissions are already in `AndroidManifest.xml`. 🟢
  Uses _inexact_ alarms, so no `SCHEDULE_EXACT_ALARM` Play-Store declaration. 🟢
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
- [ ] Legal pages **live** at `https://debatly.app/{privacy,terms,delete-account}`.
      The in-app links are already wired (default URLs in `AppConfig`, surfaced on
      the Privacy & data screen 🟢) — this box is just "publish the actual pages".
- [ ] Paste the **account-deletion URL** (`https://debatly.app/delete-account`)
      into the Google Play **Data safety** form's deletion field (the in-app
      Settings → delete flow covers the on-device path).
- [ ] Store listings (screenshots, descriptions, data-safety / privacy forms).
      For **screenshots**, the in-app share already renders a branded 1080×1920
      poster of a question (`QuestionShareCard` via `renderWidgetToPng`) — the
      same render doubles as store-screenshot source art. To export a batch,
      render `QuestionShareCard` for a few questions and save the PNGs (see the
      `renderWidgetToPng` test for the pattern), then drop them into the console.

---

## 8. In-app review prompt 📱

**Native store-review sheet — no Firebase, no server, no keys.** The app asks for
a rating at a positive moment (after a daily vote that puts the user at a 3-day
streak, then at most ~once a week) via `lib/services/review_service.dart`
(`in_app_review`: iOS `SKStoreReviewController` / Android Play In-App Review). 🟢
Timing lives in the pure `shouldPromptForReview` (`review_providers.dart`).

- Nothing to configure for the in-app sheet — it carries no app-supplied copy. 🟢
- ⚠️ **It won't appear in local debug builds.** Android only shows it for an app
  installed from Play (internal-testing track or later); iOS shows it in
  production (not reliably in TestFlight). "Nothing happened" on a dev device is
  expected — verify the wiring with the unit test, not the dev build.
- [ ] (Optional, future) A "Rate the app" button in Settings would use
      `openStoreListing`, which needs the real **App Store ID** on iOS — wire that
      once the app exists in App Store Connect.

---

## 9. Home-screen widget 📱 ("Pytanie dnia")

The app pushes today's free daily question to a native home-screen widget via
`lib/services/widget_sync_service.dart` (`home_widget`); the widget renders the
last pushed value (no background network). Daily content is always free, so
nothing premium is exposed. 🟢

- **Android** — fully wired (provider, layout, manifest receiver). Nothing to
  configure; appears in the launcher's widget picker as "Debatly". 🟢
- **iOS** — needs a one-time **Xcode** step (Widget Extension target + App Group
  `group.com.aknsoftware.questionapp` on both Runner and the widget). 🟠
  - [ ] Follow `ios/DailyQuestionWidget/SETUP.md` step by step (target, App Group,
        `INFOPLIST_FILE`, font membership).
  - [ ] Register the App Group on the Apple Developer account if automatic signing
        doesn't create it.
- ⚠️ Verify by **opening the app once** (writes the data) then adding the widget;
  switching app language flips the label PL/EN after the app is reopened.

---

## 10. Crash & error reporting (Sentry) ☁️ + 🔑

Wired in code (a no-op until a DSN is supplied), so dev/mock builds are
untouched. Full walkthrough + dashboard setup: **`SENTRY_SETUP.md`**.

- [ ] Create the Sentry project (platform **Flutter**), copy its **DSN** into
      `SENTRY_DSN` in your `env/*.json` (see §1). Empty = reporting off.
- [ ] (Recommended) Set `SENTRY_ENVIRONMENT=production` for release builds and
      leave it `development` for `env/local.json`, so prod crashes aren't buried
      under dev noise.
- [ ] (Recommended for release) Upload Dart/native **debug symbols** so obfuscated
      release stack traces are readable — `sentry_dart_plugin` step in
      `SENTRY_SETUP.md` §5. Needs a `SENTRY_AUTH_TOKEN` (auth token, NOT the DSN).
- [ ] Verify a test event reaches the dashboard (`SENTRY_SETUP.md` §4).

---

## Quick "is it wired?" map

| Concern              | Code entry point                                                       |
| -------------------- | ---------------------------------------------------------------------- |
| Secrets              | `lib/core/config/app_config.dart`                                      |
| Consent (GDPR + ATT) | `lib/services/consent_service.dart`                                    |
| Account deletion     | `supabase/functions/delete-account/` + `SupabaseService.deleteAccount` |
| Daily reminder       | `lib/services/notification_service.dart`                               |
| In-app review        | `lib/services/review_service.dart` + `review_providers.dart`           |
| Premium gate         | `sync-entitlement` / `revenuecat-webhook` + `profiles.is_premium`      |
| Home-screen widget   | `lib/services/widget_sync_service.dart` + `ios/DailyQuestionWidget/`   |
| Crash/error reporting| `lib/core/monitoring/monitoring.dart` + `SentryFlutter.init` in `main.dart` |
