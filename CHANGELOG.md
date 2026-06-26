# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project aims to
adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The app's
store version lives in `pubspec.yaml` (`version: x.y.z+build`).

## [Unreleased]

### Removed
- Native "Pytanie dnia" home-screen widget (Android + iOS). A pure-text card
  was not compelling enough to keep; see the home-widget note in the project
  memory before reintroducing it.

## [1.0.0] - 2026-06-26

Initial release candidate. A minimalist daily-question app: one
thought-provoking question at a time, with voting, streaks, ranks, and a
freemium model.

### Added
- Daily question feed with the "wind" swipe animation.
- Freemium monetization: free daily question, rewarded-ad / credit reveals for
  the rest, and a RevenueCat-backed PRO tier (server-mediated via Supabase RLS).
- Anonymous, email/password, native Google, and Apple sign-in.
- Engagement loop: streaks, daily TAK/NIE voting, a data-driven rank ladder,
  and rank-up celebrations.
- PRO extras: favorites, question history, and full-catalog offline cache.
- Bilingual UI (English + Polish) driven by ARB localizations.
- Light / dark / system theming.
- Local daily reminder notifications (vote-aware 7-day loop).
- Store-compliance plumbing: account deletion, AdMob consent (UMP) + ATT,
  in-app review prompts, and Sentry crash/error reporting.

[Unreleased]: https://github.com/ksarpe/questionapp/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ksarpe/questionapp/releases/tag/v1.0.0
