# Migrations — read before touching prod

**These files are reference copies, not a replayable history.** Migrations are
applied to prod via the Supabase MCP (`apply_migration`), which stamps its own
timestamp — so the remote `supabase_migrations.schema_migrations` versions do
NOT match these filenames. The remote history table is the ground truth:

```sql
select version, name from supabase_migrations.schema_migrations order by version;
```

## Do NOT `supabase db push`

A fresh `supabase link` + `db push` would try to re-apply every file here (the
remote history doesn't know these versions) and fail or duplicate seeds. Apply
new changes the same way as before (MCP / SQL editor) and drop a copy of the
SQL in this folder for reference.

## Known gaps between this folder and prod (as of 2026-07-09)

- `20260709160000_spicy_third_smaczek.sql` (adds a PRO-gated third "pod włos"
  smaczek to 992 questions + backfills position 2 for 3 questions) was applied
  to prod NOT as a single remote migration but as **4 chunked `execute_sql`
  batches** (the full VALUES list was too large for one MCP call). The reference
  file here is the complete, idempotent version — treat it as the source of
  truth. Every INSERT is guarded by `ON CONFLICT (question_id, position) DO
  NOTHING`, so re-running is a no-op. Verified live: positions 1/2/3 = 1000 each,
  0 questions with <3 active smaczki, 0 smaczki missing a pl/en translation.


- `20260709120000_polish_copy_editing_pass.sql` (PL copy-editing pass, 61
  guarded UPDATEs) was applied via MCP as remote version `20260709120114`. The
  SQL sent to MCP had a hand-paste typo in the LAST statement's guard
  (`…nie ma czego ukrycia?` instead of the real prior text `…nie ma czego
  ukrywać?`), so that one row was a no-op remotely; it was then fixed by a
  standalone `execute_sql`. The reference file in this folder has the CORRECT
  guard and is fully idempotent — treat it, not the recorded remote statements,
  as the accurate copy. All 61 edits verified live on prod.


- **Two applied seed migrations exist ONLY in remote history**, not as files
  here: `seed_global_dilemmas_batch_2` (98 questions, version 20260627071251)
  and `seed_global_dilemmas_batch_3` (276 questions, version 20260627093317).
  Their full SQL is recoverable from prod:

  ```sql
  select name, array_to_string(statements, E'\n')
  from supabase_migrations.schema_migrations
  where name like 'seed_global_dilemmas_batch_%';
  ```

- `20260618120000_init.sql` predates migration tracking on the remote — it is
  applied (the schema exists) but absent from the remote history table.
- `20260622140000_entitlement_sources.sql` sat unapplied on prod until
  **2026-07-02** (while the deployed `sync-entitlement` function already
  depended on its `apply_store_entitlement`). Applied 2026-07-02.
- `20260625120000_fix_reveal_ad_question_ambiguous_id.sql` has no remote
  history entry; its effect is superseded by
  `20260701120000_open_premium_questions_to_unlock_pool.sql`, which recreated
  the RPC.
- Batches 2-3 are ALSO recoverable locally from git: commit `a3a04a0` contains
  `20260627120000_seed_global_dilemmas_batch_2.sql` and
  `20260627130000_seed_global_dilemmas_batch_3.sql` (deleted from the tree
  later).
- `20260713150000_vote_farming_monitoring.sql` (admin-only views
  `admin_vote_farming_suspects` + `admin_question_vote_velocity` for spotting
  vote-farming bot accounts) — applied to prod 2026-07-13 via MCP. Idempotent
  (create-or-replace), safe to re-run. Smoke test
  `select * from admin_vote_farming_suspects limit 20;` returned only
  no-app-events test accounts, as expected on a clean base.
- `20260713120000_personal_daily_question.sql` (personal per-user daily +
  streak on any vote; retires the shared calendar daily) applied to prod
  2026-07-13 via MCP as `personal_daily_question` — file and remote content
  match 1:1. `daily_questions` is legacy from this point: read-only fallback,
  nothing writes it.
- `20260713170000_paywall_funnel_analytics.sql` (read-side `paywall_funnel`
  view over `app_events`; the client logs `paywall_*` events since app version
  1.0.3+) — **NOT yet applied to prod**. Idempotent (`create or replace view`),
  no schema change; apply via MCP / SQL editor whenever.
- `20260713160000_vote_seed_baseline.sql` (hand-curated phantom-vote baseline:
  client-invisible `question_vote_seeds` table prefilled 50/0 for every
  question + all four tally RPCs add the seeds) — **applied to prod 2026-07-13**
  via MCP as remote version `vote_seed_baseline`. Verified live: 1000 seed rows
  (one per question), 0 active seeds (`seed_total<>0`), 0 orphans, all four RPCs
  (`cast_daily_vote`, `get_daily_vote_state`, `get_vote_history`,
  `get_daily_history`) reference `question_vote_seeds`, RLS on with zero client
  grants. Idempotent (guarded DDL + `on conflict do nothing` prefill), so
  re-running is a no-op. With every `seed_total = 0` there is zero behaviour
  change until the values are curated by hand. The seed values themselves are
  curated manually (Excel round-trip; export query in the file header) and are
  NOT tracked as migrations.
