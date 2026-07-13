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
- **Question content** — 1000 questions, each EN + PL (2000 translations) +
  3 smaczki each (3000); daily calendar pre-filled through **2029-03-13**
  (verified in prod 2026-07-13: 1000 continuous days, one question per day,
  every question scheduled exactly once, 974 days of runway from today — so
  the calendar AND the supply of never-seen questions run out together; top
  up content before then). `questions.is_premium` = 0 catalog-wide (unlock
  wall gone). `question_vote_seeds` = 1000 rows, all `seed_total=0` (no cold-
  start seed curated yet → zero behaviour change until the USER fills them).
- **Legal URLs** — baked into `AppConfig` → `https://debatly.app/{privacy,terms,delete-account}`,
  surfaced on the Privacy & data screen and the register consent line.
- **Sentry** — DSN wired in `env/prod-*.json`; Kotlin-2.0 override in
  `android/build.gradle.kts`. Test event verified reaching the dashboard
  (200 OK, 2026-07-08). Symbol upload now wired too: `sentry_dart_plugin` in
  `dev_dependencies` + `sentry:` block in `pubspec.yaml` (org `akn-software` /
  project `debatly` pinned there), and the Codemagic iOS workflow builds
  obfuscated + runs the upload — all it needs is the `SENTRY_AUTH_TOKEN` secret
  (already added to Codemagic 2026-07-08; see §8, opt-in).
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

## ✅ Verified green 2026-07-13 (code + backend)

Pre-release re-check on v**1.0.4**: `dart format` clean, `flutter analyze
--fatal-infos` clean, **183 tests pass**, working tree pushed to `master`.
Prod backend: 4 edge functions ACTIVE incl. **`revenue-cat-webhook` v6** (the
non-uuid/deleted-user 500-loop fix); content 1000 Qs / 2000 translations / 3000
smaczki, calendar to 2029-03-13; analytics live (`app_events` + `onboarding_funnel`
+ `paywall_funnel` views on prod). Prod env keys REAL on both platforms (RC
`goog_`/`appl_`, AdMob rewarded, Supabase, Google, Sentry) — no placeholders.
Security advisors: only the by-design set (service-role tables w/o policy,
`SECURITY DEFINER` RPCs, anonymous sign-in, leaked-password = Pro-only). Empirical
gaps still open below: `billing_events=0` (webhook never received a real event),
`ad_reward_events=1` (SSV ≥3-ad test not completed), `subscriptions=0`.

## 🔴 Blockers — must do before you can ship

### 1. Android signing 🔑 ✅
~~Generate the upload keystore (`keytool`) and create `android/key.properties`.~~
Done — see "Already done" above. Nothing left here except backing up the `.jks`.

### 2. RevenueCat ☁️🔑 (Premium)
`REVENUECAT_API_KEY` in `env/prod-android.json` is still the `goog_REPLACE_…`
placeholder.
- [ ] add products (App Store + Play).
- [ ] Put the **public SDK key** in `env/prod-*.json` (`REVENUECAT_API_KEY`). // DONE FOR ANDROID
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

### 4. Supabase Auth (dashboard toggles) ☁️
Can't be set by a migration.
- [ ] ~~**Leaked-password protection ON**~~ — NOT AVAILABLE on the free plan
      (HaveIBeenPwned check is a Supabase Pro feature). The security advisor
      will keep flagging it; ignore until/unless the project moves to Pro.
      Free-plan mitigation instead: set a **minimum password length** (≥8)
      under Auth → Sign In / Providers → Passwords.

### 5. Sign-in providers ☁️📱
- [ ] **Apple (iOS, required by App Store 4.8)** — enable *Sign in with Apple* on
      the App ID; add the capability in Xcode (wires `Runner.entitlements`); enable
      the Apple provider in Supabase with bundle id `com.aknsoftware.debatly`.

### 6. Legal pages live ☁️
- [ ] Paste the delete-account URL into the Play **Data safety** deletion field.

### 7. iOS build 📱
- [x] App-level **Privacy Manifest** (`ios/Runner/PrivacyInfo.xcprivacy`) — added
      2026-07-07 (present in repo). Declares the app's own "required reason" API
      use (`shared_preferences`/`package_info_plus` → UserDefaults). Third-party
      pods (Google Mobile Ads, RevenueCat) ship their own.
- [ ] `pod install` on a Mac (ATT + local-notifications plugins), then archive in
      Xcode. (Checked 2026-07-01: `IPHONEOS_DEPLOYMENT_TARGET=13.0` is sufficient
      for every current plugin incl. RevenueCat/AdMob's native pods — no bump
      needed, `pod install` should not fail on a deployment-target mismatch.)

### 8. Store submission ☁️
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
- [x] Verify a Sentry test event reaches the dashboard — done 2026-07-08 (test
      event ingested, 200 OK).
- [ ] (Recommended) Enable readable release crash traces. Org/project are pinned
      in `pubspec.yaml`, so the only thing to supply is a Sentry **org auth
      token** (`SENTRY_AUTH_TOKEN`). Codemagic (iOS) ✅ already has it. For **local
      Android** release builds set it once on Windows (`setx SENTRY_AUTH_TOKEN
      "sntrys_..."`) — without it Android release still ships/reports, just with
      obfuscated traces. `SENTRY_SETUP.md` §5.

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
