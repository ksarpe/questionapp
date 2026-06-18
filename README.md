# questionapp

A minimalist, modern mobile app designed to spark conversation. It shows a
single thought-provoking question as styled text, with a fast "wind" animation
when swiping to the next one.

## Tech stack

| Concern            | Choice                                  |
| ------------------ | --------------------------------------- |
| Framework          | Flutter (Dart)                          |
| State management   | Riverpod (`flutter_riverpod`)           |
| Backend / Auth     | Supabase (`supabase_flutter`)           |
| Subscriptions      | RevenueCat (`purchases_flutter`)        |
| Ads                | Google AdMob (`google_mobile_ads`)      |
| Animation          | Custom `AnimatedBuilder` + `Transform`  |

## Project layout

```
lib/
├── main.dart                     # Entry point — initialises SDKs, mounts ProviderScope
├── app.dart                      # MaterialApp + theme
├── core/
│   ├── config/app_config.dart    # Secrets via --dart-define
│   └── theme/app_theme.dart      # Colours + the white-fill/black-stroke text style
├── data/
│   ├── models/question.dart      # Question model
│   ├── mock/mock_questions.dart  # Seed questions for the UI
│   └── repositories/             # QuestionRepository (mock → Supabase later)
├── features/
│   ├── questions/
│   │   ├── providers/            # Riverpod providers + deck navigation
│   │   ├── screens/              # QuestionScreen (home)
│   │   └── widgets/              # StyledQuestionText, WindQuestionView, info sheet
│   └── settings/
│       └── screens/              # SettingsScreen (login/logout/preferences)
└── services/                     # Supabase, RevenueCat, AdMob wrappers
```

## The "wind" animation

`WindQuestionView` owns the transition. On a horizontal swipe the current text
accelerates off the left edge (fading, `easeInCubic`), then after a short beat
the next question flies in from the right and settles centre (`easeOutCubic`).
No cards, no flips — just text in motion. See
[wind_question_view.dart](lib/features/questions/widgets/wind_question_view.dart).

## Running

The app runs against mock data out of the box — every SDK no-ops gracefully when
its credentials are missing:

```bash
flutter pub get
flutter run
```

To enable the backends, pass keys at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xyz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=REVENUECAT_API_KEY=... \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-.../... \
  --dart-define=ADMOB_REWARDED_ID=ca-app-pub-.../...
```

Or copy `env/example.json` to `env/dev.json`, fill in the real values, and run:

```bash
flutter run --dart-define-from-file=env/dev.json
```

`env/dev.json` is ignored by git, so real keys stay local.

## Supabase questions

The app uses mock questions when Supabase credentials are missing. When
`SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided, `QuestionRepository`
automatically switches to Supabase.

Initial setup:

1. Create a Supabase project.
2. Open SQL Editor in Supabase.
3. Run `supabase/schema.sql`.
4. Add question rows to `questions`.
5. Add daily schedule rows to `daily_questions` by linking `publish_date` to a
   `question_id`.
6. Run the app with `--dart-define-from-file=env/dev.json`.

The mobile app should only use the public anon key. Insert/update/delete access
should stay in Supabase Dashboard or a protected admin tool, never in the
released app.

### Native config notes

- **AdMob app id** is set to Google's public *test* id in
  `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.
  Replace both with your real id before release.
- Android `minSdk` is raised to 23 (required by `google_mobile_ads`).
- Android `compileSdk` is raised to 36 (required by `package_info_plus`), and
  `android/build.gradle.kts` forces every subproject to compileSdk 36 — some
  transitive plugins (`passkeys_*` via Supabase) pin themselves to 35.
- `kotlin.incremental=false` is set in `android/gradle.properties` to work
  around a Kotlin 2.3.20 Build Tools API crash on Windows ("Could not close
  incremental caches"). Remove it once the toolchain is past that bug.
- The build prints a harmless KGP warning ("plugins that apply Kotlin Gradle
  Plugin") — Flutter 3.44 still supports this path (`android.builtInKotlin=false`);
  it only matters for a future Flutter release.

## Auth & monetization

The app uses a *freemium with rewarded ads* model. Everything degrades
gracefully when SDK keys are absent, so it still runs against mock data.

- **Silent anonymous auth.** On launch `SessionNotifier`
  ([session_providers.dart](lib/features/account/providers/session_providers.dart))
  calls `SupabaseService.ensureSignedIn()`, which signs the user in anonymously
  if `currentUser` is null. Every guest gets a stable Supabase UUID — no email,
  no password — and that UUID is also passed to RevenueCat (`Purchases.logIn`)
  so entitlements follow the same identity.
- **The swipe gate.** The first question is free. On a swipe,
  `WindQuestionView` asks `SwipeGate.requestAdvance()`
  ([monetization_providers.dart](lib/features/monetization/providers/monetization_providers.dart)):
  premium users pass instantly; free users spend an unlock credit; with none
  left the swipe is *not* animated and the unlock sheet opens instead.
- **Unlock sheet.**
  [unlock_question_sheet.dart](lib/features/monetization/widgets/unlock_question_sheet.dart)
  offers "Watch a short video" (a Google AdMob rewarded ad via
  [`RewardedAdService`](lib/services/rewarded_ad_service.dart)) or "Get
  Premium" (RevenueCat). Watching one ad grants `kUnlocksPerAd` swipes (3 by
  default) so users aren't prompted on every single swipe; a fresh ad is
  pre-loaded in the background each time.

## Next steps (placeholders to flesh out)

- Swap `MockQuestionRepository` for a Supabase-backed implementation.
- Wire Login/Logout in `SettingsScreen` to Supabase Auth.
- Replace `PurchasesService.purchasePremium()` (buys the default package) with a
  proper RevenueCat paywall, and gate `isPremium` questions in the deck.
- Persist earned unlock credits / progress per user UUID in Supabase.
- Replace the info bottom-sheet placeholder with real "arguments for discussion".
