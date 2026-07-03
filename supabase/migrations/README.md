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

## Known gaps between this folder and prod (as of 2026-07-02)

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
