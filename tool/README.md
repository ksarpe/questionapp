# Screenshot exporters

Two head-less exporters — no emulator, no backend — write upload-ready PNGs:

- **`export_app_screenshots.dart`** — real in-app screens (daily + vote, feed
  question, rank ladder, rank poster, PRO history) at **three device sizes**
  (phone / 7" tablet / 10" tablet). This is what the store listing wants. See
  ["App-screen exporter"](#app-screen-exporter) below.
- **`export_store_screenshots.dart`** — just the branded `QuestionShareCard`
  poster (documented in the rest of this file).

---

## App-screen exporter

```bash
flutter test tool/export_app_screenshots.dart
```

Output → `build/store_screenshots/app/<device>/<locale>/NN_name.png`, wiped and
rewritten per run. Three sizes, all valid for Google Play:

| Device     | logical  | ×dpr | pixels    |
| ---------- | -------- | ---- | --------- |
| `phone`    | 360×640  | 3    | 1080×1920 |
| `tablet7`  | 600×960  | 2    | 1200×1920 |
| `tablet10` | 800×1280 | 2    | 1600×2560 |

Six screens each: `01_daily_vote`, `02_daily_result`, `03_feed_question`,
`04_rank_ladder`, `05_rank_share`, `06_history`.

It renders the app's **real** presentational widgets (`StyledQuestionText`,
`VoteButtonsRow`/`VoteResultsRow`, `RankShareCard`) plus faithful, provider-free
reconstructions of the surrounding chrome (status chips, rank ladder, history
table) — so no Supabase/RevenueCat/ads are touched. All screens use the dark
theme (the app's signature black canvas).

Change the questions / rank / history sample data inline near the top of the
screen builders in `export_app_screenshots.dart`.

Options (OS env vars): `SCREENSHOT_LOCALES` (default `pl`; e.g. `pl,en`),
`SCREENSHOT_OUT_DIR` (default `build/store_screenshots/app`).

```powershell
# Polish + English, both:
$env:SCREENSHOT_LOCALES='pl,en'; flutter test tool/export_app_screenshots.dart
```

---

## Store-screenshot exporter (branded poster only)

Renders branded question posters (the **same** `QuestionShareCard` the in-app
share button shares) to PNGs you can upload to the Play Store / App Store. One
asset, two jobs — the share image doubles as store-screenshot source art.

## Use it

```bash
flutter test tool/export_store_screenshots.dart
```

Output → `build/store_screenshots/<locale>/01.png, 02.png, …` at **1080×1920**.
The output folder for each locale is wiped and rewritten on every run.

## Change the questions

Edit, one question per line (blank lines and `#` comments are ignored):

- `tool/store_screenshots/questions.pl.txt` — Polish screenshots
- `tool/store_screenshots/questions.en.txt` — English screenshots

The line's order is the file number (`01.png`, `02.png`, …). A missing
per-locale file falls back to `questions.txt` if you add one.

## Options (optional OS env vars)

| Var                      | Default                  | Notes                                   |
| ------------------------ | ------------------------ | --------------------------------------- |
| `SCREENSHOT_LOCALES`     | `pl,en`                  | comma list; must have a questions file  |
| `SCREENSHOT_OUT_DIR`     | `build/store_screenshots`| output root                             |
| `SCREENSHOT_PIXEL_RATIO` | `3`                      | 3 ⇒ 360×640 logical ⇒ 1080×1920 px      |

PowerShell example (only Polish, bigger 4× export):

```powershell
$env:SCREENSHOT_LOCALES='pl'; $env:SCREENSHOT_PIXEL_RATIO='4'; flutter test tool/export_store_screenshots.dart
```

## Notes

- 1080×1920 (9:16) is accepted as-is by Google Play. For the App Store's exact
  device sizes (e.g. 1290×2796), pad/scale these in the console — the art is the
  source, the final crop is manual.
- The poster's look lives in
  [`lib/features/questions/widgets/share_question_card.dart`](../lib/features/questions/widgets/share_question_card.dart);
  the off-screen renderer is
  [`lib/core/share/widget_to_image.dart`](../lib/core/share/widget_to_image.dart).
- `build/` is git-ignored, so exported PNGs aren't committed.
