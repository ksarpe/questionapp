# Code review & "professional repo" plan — Debatly

> Prepared 2026-06-26 by a senior Flutter/infra review pass. This file is a
> working backlog: each item below is **copy-paste-ready as a prompt to a coding
> agent** (or a checklist for you). Items I already applied in this pass are
> listed first under "Done in this pass" — you don't need to redo those.

---

## TL;DR — what the review found

The **code itself is already professional-grade**: clean feature-first
architecture, excellent inline docs, no `print`s, no leaked secrets, 128 passing
tests, and `flutter analyze` is clean. The gaps were almost entirely at the
**repository-infrastructure** level (CI, hygiene files, naming/doc drift,
formatting policy) — not in the Dart.

Baseline at time of review:

- `flutter analyze` → **No issues found** (now also clean under the stricter rule
  set + `--fatal-infos --fatal-warnings`).
- `flutter test` → **128 passing**.
- `dart format .` → would rewrite **66 of 140 files** (formatter was never
  enforced). This is the single biggest pending mechanical change — see **P0-A**.
- Large uncommitted diff in the working tree: the home-widget removal (Android +
  iOS native + Dart). See **P0-B**.

---

## Done in this pass (already applied — no action needed)

These were low-risk and mechanical, so I applied and verified them (analyze
clean, 128 tests still green):

| Change | File(s) |
|---|---|
| **CI pipeline** — format + analyze (`--fatal-infos --fatal-warnings`) + test + coverage artifact | `.github/workflows/ci.yml` |
| **Dependabot** — weekly pub + actions, monthly Deno/npm for edge functions | `.github/dependabot.yml` |
| **CODEOWNERS** — defaults to `@ksarpe` | `.github/CODEOWNERS` |
| **PR template** + **issue templates** (bug / feature) + blank-issues off | `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/*` |
| **.editorconfig** — utf-8/LF/2-space, 80-col for Dart | `.editorconfig` |
| **CONTRIBUTING.md** — setup, quality gates, conventions | `CONTRIBUTING.md` |
| **CHANGELOG.md** — Keep-a-Changelog, 1.0.0 + Unreleased (widget removal) | `CHANGELOG.md` |
| **Stricter lints** — curated rules on top of flutter_lints; auto-fixed 14 issues via `dart fix` (directive ordering, redundant parens, const) | `analysis_options.yaml` + 13 source files |
| **README** — brand title (Debatly), CI badge, accurate project-layout tree, fixed stale `env/dev.json` → `env/local.json`, Quality-gates section | `README.md` |

> ⚠️ **CI will be red until P0-A lands.** The new workflow enforces
> `dart format --set-exit-if-changed`, and the tree is not yet formatted. Run
> P0-A before (or in the same push as) enabling Actions.

---

## P0 — Do first (mechanical, but large diffs — your call to land)

### P0-A · Apply `dart format` repo-wide
**Why:** A professional repo enforces a single formatter; CI now checks it. The
formatter currently rewrites 66 files (the Dart 3.x "trailing-comma → multiline"
style). I did **not** apply it automatically because it would bury your
in-flight widget-removal diff under mechanical churn and it deserves its own
atomic commit.

**Risk:** None (formatting never changes semantics). Verify with analyze+test.

**Agent prompt:**
```
Run `dart format .` at the repo root. Then run `flutter analyze` and
`flutter test` to confirm both are still green. Commit the result as a single
commit with message "style: apply dart format across the codebase" and nothing
else in that commit. Do not change any logic.
```

### P0-B · Commit the home-widget removal as its own commit
**Why:** The working tree has a large, coherent uncommitted change (removing the
native "Pytanie dnia" home-screen widget across Android, iOS, Dart, l10n, tests).
Leaving it uncommitted makes the repo look mid-surgery. It is already reflected
in `CHANGELOG.md` under `[Unreleased]`.

**Risk:** Low — it's a clean deletion; tests already pass with it removed.

**Agent prompt:**
```
Review the current uncommitted changes (git status / git diff) which remove the
native home-screen widget feature (Android DailyQuestionWidgetProvider + res,
iOS DailyQuestionWidget target, lib/services/widget_sync_service.dart,
category_filter remnants, related l10n + tests). Confirm `flutter analyze` and
`flutter test` pass. Stage and commit it as
"feat(widget): remove native home-screen widget" (or split category-filter
removal into its own commit if the two are independent). Update CHANGELOG.md if
the wording needs adjusting. Do NOT push.
```
> Note: this pass already removed the `category_filter` test/widget references
> and they pass; verify the staged set matches your intent before committing.

---

## P1 — Repo structure & polish

### P1-A · Consolidate the three screenshot locations
**Why:** Screenshots live in **three** places — `screenshots/` (3 PNGs),
`marketing/screenshots/` (3 PNGs), and `tool/store_screenshots/` (text copy for
the generator). That's confusing and bloats the git history with binaries.

**Decision needed:** keep store art in-repo or move to a release asset / Drive?

**Agent prompt:**
```
There are three screenshot-related locations: `screenshots/`,
`marketing/screenshots/`, and `tool/store_screenshots/`. Inspect what each
holds and how it's used (grep the repo + tool/export_store_screenshots.dart).
Propose and then implement a single canonical layout — recommend
`marketing/screenshots/` for final store art and keep the generator's text
inputs under `tool/`. Move files with `git mv`, delete the redundant
`screenshots/` dir, and update any references (README, tool/README.md,
export_store_screenshots.dart output paths). If the PNGs are large, evaluate
git-lfs (add `.gitattributes`) but do not enable it without flagging the history
implications. Keep `flutter analyze`/`flutter test` green.
```

### P1-B · Move long-form docs under `docs/`
**Why:** Root currently has `README.md`, `RELEASE_CHECKLIST.md`,
`SENTRY_SETUP.md`, and now `CONTRIBUTING.md`, `CHANGELOG.md`, `CODE_REVIEW_PLAN.md`.
Big repos keep README + CONTRIBUTING + CHANGELOG + LICENSE at root and push the
rest into `docs/`.

**Agent prompt:**
```
Create a `docs/` directory and `git mv` RELEASE_CHECKLIST.md and SENTRY_SETUP.md
into it (keep README.md, CONTRIBUTING.md, CHANGELOG.md, LICENSE at root). Update
every internal link to the moved files (grep for "RELEASE_CHECKLIST" and
"SENTRY_SETUP" across *.md, lib/**, and .github/**). Add a short "## Docs" index
section to README listing what's in docs/. Verify no broken relative links.
```
> Note: `RELEASE_CHECKLIST.md` is currently modified in your working tree — land
> P0-B first so the move is a clean rename.

### P1-C · Add a LICENSE (decision required)
**Why:** No `LICENSE` file. `pubspec.yaml` has `publish_to: 'none'` and this is a
commercial app, so the right default is **proprietary / all-rights-reserved**,
not an OSS license. A repo with no license is legally ambiguous.

**Agent prompt (if proprietary — recommended):**
```
Add a root `LICENSE` file declaring proprietary, all-rights-reserved terms for
"Debatly" / the copyright holder Kasper Janowski, year 2026. Keep it short and
standard for a closed-source commercial app (no redistribution, no warranty).
Reference it from README ("## License" one-liner).
```

---

## P2 — Code architecture (larger, optional, higher value as the team grows)

### P2-A · Decide: rename the Dart package `questionapp` → `debatly`?
**Why:** Brand is Debatly; the package is `questionapp`, so every internal import
reads `package:questionapp/...`. Cosmetic, but it's the kind of drift that looks
unfinished.

**Recommendation:** **Defer / probably skip.** The package name is invisible to
users, and a rename touches every `package:` import plus risks the Android
`applicationId` / iOS bundle id confusion if done carelessly. Low value, nonzero
risk. Only do it if you want absolute consistency.

**Agent prompt (only if you decide to do it):**
```
Rename the Dart package from `questionapp` to `debatly`. Change `name:` in
pubspec.yaml, then update EVERY `package:questionapp/` import across lib/ and
test/ to `package:debatly/`. Do NOT touch the Android applicationId, iOS bundle
identifier, native folders, or the marketing name — only the Dart package name.
Run `flutter pub get`, `flutter analyze`, `flutter test` and confirm green.
Commit as "refactor: rename Dart package questionapp -> debatly".
```

### P2-B · Split the largest files into focused units
**Why:** A handful of files are large enough to be hard to navigate. None are
*bad* (they're well-commented), but breaking them up reads as "mature codebase".
Candidates by size:

| File | ~lines | Suggested split |
|---|---|---|
| `lib/features/settings/screens/settings_screen.dart` | 700 | extract section builders into `settings/widgets/` (account section, preferences section, legal section) |
| `lib/features/questions/widgets/wind_question_view.dart` | ~620 | extract the swipe/animation controller + the reveal-slot logic |
| `lib/data/repositories/question_repository.dart` | ~560 | split mock vs Supabase impls into separate files behind the interface |
| `lib/features/account/screens/auth_screen.dart` | ~470 | extract the sign-in/register form bodies |
| `lib/features/questions/widgets/history_screen.dart` / `rank_up_sheet.dart` | ~400 each | extract row/table widgets |

**Agent prompt (run per file):**
```
Refactor lib/features/settings/screens/settings_screen.dart (700 lines) by
extracting its visually-distinct sections into separate stateless widgets under
lib/features/settings/widgets/ (e.g. SettingsAccountSection,
SettingsPreferencesSection, SettingsLegalSection). Keep behavior identical —
this is a pure extraction. Preserve all existing doc comments by moving them with
their code. Match the existing house style (Riverpod, context.l10n,
context.colors). Run flutter analyze + flutter test after; both must stay green.
Commit as "refactor(settings): extract SettingsScreen sections into widgets".
```

### P2-C · Add `riverpod_lint` + `custom_lint`
**Why:** This is a Riverpod-heavy app; `riverpod_lint` catches the classic
mistakes (missing `ref` disposal, provider-in-build, `WidgetRef` misuse) that the
base analyzer can't. Standard in serious Riverpod codebases.

**Agent prompt:**
```
Add dev_dependencies `custom_lint` and `riverpod_lint` (versions compatible with
flutter_riverpod ^3.3.2). Enable the custom_lint plugin in analysis_options.yaml
(`analyzer.plugins: [custom_lint]`). Run `dart run custom_lint` and
`flutter analyze`; fix any findings that are real, and for any false positive add
a narrowly-scoped ignore with a one-line justification. Keep everything green and
commit as "chore: add riverpod_lint static analysis".
```

### P2-D · Stage in `strict-casts` (and later `strict-raw-types`)
**Why:** The strongest analyzer safety setting. Supabase returns dynamic JSON
maps, so this will surface untyped casts — exactly the spots worth tightening.

**Risk:** Will produce a batch of findings to fix; do it on a quiet branch.

**Agent prompt:**
```
In analysis_options.yaml add `analyzer.language.strict-casts: true`. Run
`flutter analyze` and fix every resulting issue by adding explicit types/casts
(especially around Supabase JSON map handling in lib/data and lib/services).
Do NOT add blanket ignores. Keep flutter test green. Commit as
"chore: enable strict-casts and fix fallout". (Defer strict-raw-types to a
follow-up.)
```

---

## P3 — Testing & release engineering

### P3-A · Coverage gate + report in CI
**Why:** CI already produces `coverage/lcov.info`. Add a visible coverage number
and (optionally) a minimum threshold so coverage can't silently rot.

**Agent prompt:**
```
Extend .github/workflows/ci.yml to upload coverage to Codecov (codecov/codecov-action,
token via repo secret) OR, if avoiding third parties, add a step using a
coverage-threshold check (e.g. very_good_coverage action) set to a realistic
floor based on current coverage. First compute current coverage from
coverage/lcov.info and set the floor just below it. Add a coverage badge to
README. Do not lower the floor later without discussion.
```

### P3-B · Golden tests for signature widgets
**Why:** The app's identity is visual (styled question text, rank share card,
"wind" transition). Golden tests lock these against accidental regressions.

**Agent prompt:**
```
Add golden tests (flutter_test matchesGoldenFile) for the highest-value visual
widgets: StyledQuestionText, RankShareCard, and the daily vote panel result bars.
Use the existing test/support/localized_test_app.dart harness, pin locale to pl,
and generate goldens with `flutter test --update-goldens`. Commit the .png
goldens. Keep them deterministic (no real network, fixed fake data).
```

### P3-C · Integration smoke test
**Why:** Widget tests cover units; one `integration_test` that boots the app on a
device/emulator and walks splash → daily → vote proves the wiring end to end.

**Agent prompt:**
```
Add the `integration_test` package and an integration_test/app_smoke_test.dart
that launches the app against mock data (no SDK keys), passes the splash, asserts
the daily question renders, casts a vote, and opens settings. Document running it
in CONTRIBUTING.md. (CI execution needs an emulator job — add it only if you want
device CI; otherwise keep it runnable locally.)
```

### P3-D · Local pre-commit hook
**Why:** Stops un-formatted / failing code reaching CI. Mirrors the CI gates.

**Agent prompt:**
```
Add a lightweight git pre-commit hook (recommend `lefthook` — single binary, no
Node needed) that runs `dart format --set-exit-if-changed` on staged Dart files
and `flutter analyze`. Add a lefthook.yml, document install in CONTRIBUTING.md,
and make it skippable for WIP commits. Keep it fast (staged files only where
possible).
```

---

## P4 — Housekeeping / smaller items

### P4-A · Resolve the lone TODO
`lib/features/questions/widgets/wind_question_view.dart:584` —
`// TODO(vibration): add a short haptic here`. Either implement
`HapticFeedback.selectionClick()` (no new dep) or remove the TODO if haptics
were decided against.

### P4-B · Decide on the vendored agent-skill files in VCS
**Verified state:** `questionapp.iml` and `.idea/` are **already untracked**
(correctly ignored) — nothing to do there. `.vscode/launch.json` **is** tracked,
which is fine (shared launch config). What stands out: **`.agents/skills/`
(~40 markdown reference files for the Supabase best-practices agent skill) and
`skills-lock.json` are committed.** These are AI-tooling artifacts, not product
code — in a "big successful app" repo they read as clutter.

**Decision needed:** keep them (if the team relies on the skill being vendored)
or move them out of the product repo.

**Agent prompt (only if you decide to remove them):**
```
Stop tracking the vendored agent-skill files: `git rm -r --cached .agents/` and
`git rm --cached skills-lock.json`, then add `.agents/` and `skills-lock.json`
to .gitignore. Do NOT delete them from disk (the local tooling still uses them).
Commit as "chore: stop tracking vendored agent skills". Leave .vscode/ tracked.
```

### P4-C · Open backlog from prior audits (carry-over)
The project memory references an audit backlog (e.g. "no auth listener", "dead
SwipeGate", "TRANSFER"). Confirm whether these are still open and, if so, fold
them into issues using the new issue templates. (Out of scope for this review;
listed so it isn't forgotten.)

---

## Suggested execution order

1. **P0-A** (format) + **P0-B** (commit widget removal) — unblocks green CI.
2. Push, confirm the **CI workflow** goes green on GitHub.
3. **P1-C** (LICENSE), **P1-B** (docs/), **P1-A** (screenshots) — quick polish.
4. **P2-C** (riverpod_lint) + **P4** housekeeping — cheap, high signal.
5. **P2-B** (file splits), **P3** (golden/integration/coverage) — as time allows.
6. **P2-A** (package rename) and **P2-D** (strict-casts) — only if you want the
   last 5% of polish; both are higher-effort, lower-urgency.
