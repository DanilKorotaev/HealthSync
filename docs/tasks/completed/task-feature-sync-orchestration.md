# Sync orchestration and JSON export

**Status:** Done  
**Priority:** High  
**Category:** Feature

## Description

Connect HealthKit export, file naming (`daily/YYYY-MM-DD.json`, `workouts/...`), and `sync_state.json` updates; optional webhook `POST` after successful upload.

## Tasks

- [x] Encode models matching knowledge base JSON schema (daily + `sync_state`; workouts via separate milestone)
- [x] Idempotent uploads and state persistence (overwrite same remote paths)
- [x] Manual “Sync now” flow (main screen + error surfacing)
- [ ] Initial full backfill (historical range) — follow-up task / next iteration

## Notes

- `SyncService.syncNow()` uploads `HealthData/daily/yyyy-MM-dd.json` and `HealthData/sync_state.json`, then optional webhook `POST` with `{ date, files }`.
- `HealthKitService.dailyAggregationInput` is still a stub (zeros) until anchored queries land; mapping and JSON shape are wired end-to-end.
