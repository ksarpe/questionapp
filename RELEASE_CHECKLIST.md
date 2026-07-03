# Release checklist

The app runs on mock data with no keys. A **store release** needs the manual,
outside-the-code steps below. This file is the single source of truth for
"things a human has to do in a console". Tick them off per platform before
submitting.

> Legend: 🔑 secret/key · ☁️ console · 📱 native file · ✅ already done

---

## ✅ Already done (don't redo)

- **App identity** — name **"Debatly"** on Android + iOS; launcher icons + splash
  generated from `assets/images/`.
- **AdMob App IDs** — real ids in both `AndroidManifest.xml` and iOS `Info.plist`.
- **Question content** — 732 questions, each EN + PL (seed batches 4+5 added
  250 on 2026-07-03); daily calendar pre-filled through **2028-06-18**
  (verified in prod 2026-07-03: continuous, one question per day, every
  question scheduled exactly once — so the calendar AND the supply of
  never-seen questions run out together; top up content before then).
- **Legal URLs** — baked into `AppConfig` → `https://debatly.app/{privacy,terms,delete-account}`,
  surfaced on the Privacy & data screen and the register consent line.
- **Sentry** — DSN wired in `env/prod-*.json`; Kotlin-2.0 override in
  `android/build.gradle.kts`. (Symbol upload + a test event still pending — see §8.)
- **Edge functions** — all four deployed (live as `revenue-cat-webhook` note the
  hyphen, `admob-ssv`, `sync-entitlement`, `delete-account`).
- **Backend** — RLS on every table; consent (GDPR + ATT), local daily reminders,
  share, in-app review, account deletion all wired in code.
- **Android signing keystore** — `android/keys/upload-keystore.jks` generated
  (alias `upload`) + `android/key.properties` wired up; both git-ignored.
  ⚠️ Back this keystore up somewhere safe (password manager / secure vault) —
  losing it means you can never update the app under the same Play listing again.
- **SKAdNetwork list** — Google's full list (50 identifiers, incl. Google, Meta,
  Applovin, Unity Ads…) pasted into iOS `Info.plist`, replacing the one-entry stub.
- **Store screenshots** — generated via `tool/export_store_screenshots.dart`;
  10 PNGs (5 PL + 5 EN, 1080×1920) under `build/store_screenshots/{pl,en}/`.
  Re-run any time to refresh (output isn't committed).
- **Ad/credit-unlock wall fixed (2026-07-01, prod)** — 218 of 482 questions had
  `questions.is_premium=true`, and `reveal_ad_question`/`reveal_free_question`/
  `peek_next_question` all filtered `and not q.is_premium`, so those 218 could
  never be unlocked by ad or credit (only ever seen as a daily) — a free user
  watching ads hit a permanent wall at 264 questions. Migration
  `20260701120000_open_premium_questions_to_unlock_pool.sql` flipped the flag
  off catalog-wide and dropped the now-vestigial predicate from all 3 RPCs.
  The whole catalog is now unlockable (incl. later-seeded questions — the
  predicate is gone, so new seeds join the pool automatically).
- **Entitlement-sources migration applied + webhook redeployed (2026-07-02,
  prod)** — the `entitlement_sources` migration (store vs promotional premium,
  `apply_store_entitlement`) had never been applied to prod even though the
  deployed `sync-entitlement` already called it — setting
  `REVENUECAT_REST_API_KEY` would have 500'd every entitlement sync. Applied
  2026-07-02. The live `revenue-cat-webhook` was also one version behind the
  repo (wrote `profiles.is_premium` directly, clobbering promo grants) —
  redeployed (v3) with the reconciler + a fix so `BILLING_ISSUE` keeps premium
  through the store grace period (`expiration_at_ms`) instead of revoking
  instantly.

---

## 🔴 Blockers — must do before you can ship

### 1. Android signing 🔑 ✅
~~Generate the upload keystore (`keytool`) and create `android/key.properties`.~~
Done — see "Already done" above. Nothing left here except backing up the `.jks`.

### 2. RevenueCat ☁️🔑 (Premium)
`REVENUECAT_API_KEY` in `env/prod-android.json` is still the `goog_REPLACE_…`
placeholder.
- [ ] Create the entitlement (`premium`) + products (App Store + Play).
- [ ] Build the Paywall in the RevenueCat dashboard.
- [ ] Put the **public SDK key** in `env/prod-*.json` (`REVENUECAT_API_KEY`).
- [ ] Set the **secret REST key** + **webhook secret** as Supabase secrets
      (`REVENUECAT_REST_API_KEY`, `REVENUECAT_WEBHOOK_SECRET`) and point the
      webhook at `.../revenue-cat-webhook` — **note the hyphen**, the deployed
      slug does NOT match the repo folder name (`revenuecat-webhook`); the
      folder-name URL 404s and renewals/cancellations/refunds silently stop
      syncing (initial purchase still works via `sync-entitlement`'s pull).
- [ ] `sync-entitlement` silently degrades to DB-only truth (no reconciliation)
      if `REVENUECAT_REST_API_KEY` isn't set — no error is thrown, so this is
      easy to miss. Confirm the secret is actually set, not just that the
      function returns 200.

### 3. AdMob ☁️📱
- [x] ~~Banner ad~~ — decided 2026-07-01: **rewarded-only, no banner.**
      `AdsService.createBannerAd` was dead code (no widget ever called it, so no
      banner rendered anyway) and has been removed. Don't create a banner ad unit
      in the AdMob console — there's nothing to point it at.
- [ ] **SSV callback URL (required)** on the rewarded unit →
      `https://<project-ref>.functions.supabase.co/admob-ssv`. Without it, no free
      reveal-by-ad ever validates.
  - ⚠️ **Test past 2 reveals before sign-off.** `reveal_ad_question`'s grace
    limit (`c_grace = 2`) is a **lifetime** allowance, not per-day. If SSV is
    misconfigured, the first 2 ad-unlocks per user succeed anyway (masking the
    problem), then every one after fails with a generic error. QA must watch
    ≥3 ads on one test account and confirm the 3rd unlocks before declaring
    the SSV wiring good.
- [ ] Create a **GDPR consent message** (and an iOS **ATT** message) in the
      Privacy & messaging section — without them the consent form is blank.
- [x] ~~Paste Google's full SKAdNetwork list into iOS `Info.plist`~~ — done, see
      "Already done" above.

### 4. Supabase Auth (dashboard toggles) ☁️
Can't be set by a migration.
- [ ] **Confirm email ON** (Providers → Email) — activates the anti-farm credit
      guard.
- [ ] **Leaked-password protection ON** (Sign In → Passwords) — still flagged by
      the security advisor.

### 5. Sign-in providers ☁️📱
- [ ] **Google** — partially done: the **Web** OAuth client exists and its id is
      already in `env/prod-*.json` (`GOOGLE_SERVER_CLIENT_ID`). Still left:
  - [ ] iOS OAuth client + Android OAuth client (with the release SHA-1).
  - [ ] Enable Google in Supabase Auth (Web client id in Authorized Client IDs).
- [ ] **Apple (iOS, required by App Store 4.8)** — enable *Sign in with Apple* on
      the App ID; add the capability in Xcode (wires `Runner.entitlements`); enable
      the Apple provider in Supabase with bundle id `com.aknsoftware.questionapp`.

### 6. Legal pages live ☁️
- [ ] Publish the actual pages at `https://debatly.app/{privacy,terms,delete-account}`.
- [ ] Paste the delete-account URL into the Play **Data safety** deletion field.

### 7. iOS build 📱
- [ ] Add an app-level **Privacy Manifest** (`ios/Runner/PrivacyInfo.xcprivacy`) —
      none exists yet. Apple requires it because `shared_preferences` (and
      possibly `package_info_plus`) touch "required reason" APIs (UserDefaults).
      Third-party pods (Google Mobile Ads, RevenueCat) ship their own manifests;
      this is the app's *own* declaration, still missing. Can cause a warning or
      rejection at submission if skipped.
- [ ] `pod install` on a Mac (ATT + local-notifications plugins), then archive in
      Xcode. (Checked 2026-07-01: `IPHONEOS_DEPLOYMENT_TARGET=13.0` is sufficient
      for every current plugin incl. RevenueCat/AdMob's native pods — no bump
      needed, `pod install` should not fail on a deployment-target mismatch.)

### 8. Store submission ☁️
- [x] ~~Screenshots~~ — generated, see "Already done" above.
- [ ] Store listings: descriptions, data-safety / privacy forms.
- [ ] **Play Console**: content rating questionnaire, category, and the "Ads" +
      "Advertising ID" declaration (yes — `google_mobile_ads` pulls in
      `com.google.android.gms.permission.AD_ID` via manifest merge even though
      it's not explicit in this repo's `AndroidManifest.xml`).
- [ ] **App Store Connect**: age rating and category.
- [ ] **Data safety / App Privacy forms** — data actually collected per the code:
      email + auth identifiers (Supabase auth), purchase history (RevenueCat,
      linked to account), advertising ID (AdMob), pseudonymous crash data
      (Sentry — `sendDefaultPii=false`, no email/name/IP attached), app
      activity (votes/streaks/favorites in Supabase). No analytics SDK present.
- [ ] (Recommended) Upload Sentry debug symbols (`SENTRY_AUTH_TOKEN`,
      `SENTRY_SETUP.md` §5) and verify a test event reaches the dashboard.

---

## Build & run

Secrets come from `--dart-define` (`lib/core/config/app_config.dart`). Copy
`env/example.json` → `env/local.json` (git-ignored), fill it, then:

```bash
flutter run   --dart-define-from-file=env/local.json
flutter build appbundle --dart-define-from-file=env/prod-android.json
flutter build ipa       --dart-define-from-file=env/prod-ios.json
```

| Key | For | Required |
| --- | --- | --- |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` 🔑 | Backend / auth | Yes |
| `GOOGLE_SERVER_CLIENT_ID` 🔑 | Native Google sign-in | If Google login |
| `REVENUECAT_API_KEY` 🔑 | Subscriptions / paywall | If Premium |
| `ADMOB_REWARDED_ID` 🔑 | Ads (reveal-by-ad) | If ads |
| `SENTRY_DSN` 🔑 | Crash / error reporting | If monitoring |
| `PRIVACY_POLICY_URL`, `TERMS_OF_SERVICE_URL`, `DELETE_ACCOUNT_URL` | Legal links | Default to debatly.app ✅ |

Supabase secrets (server-side): `REVENUECAT_WEBHOOK_SECRET`,
`REVENUECAT_REST_API_KEY`, optional `PREMIUM_ENTITLEMENT` (default `premium`).

---

## Where it's wired

| Concern | Entry point |
| --- | --- |
| Secrets | `lib/core/config/app_config.dart` |
| Consent (GDPR + ATT) | `lib/services/consent_service.dart` |
| Account deletion | `supabase/functions/delete-account/` + `SupabaseService.deleteAccount` |
| Daily reminder | `lib/services/notification_service.dart` |
| In-app review | `lib/services/review_service.dart` + `review_providers.dart` |
| Premium gate | `sync-entitlement` / `revenuecat-webhook` + `profiles.is_premium` |
| Crash / error reporting | `lib/core/monitoring/monitoring.dart` + `SentryFlutter.init` in `main.dart` |
