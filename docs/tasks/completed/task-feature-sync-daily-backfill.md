# Daily JSON backfill (historical non-workout data)

**Status:** Done  
**Priority:** High  
**Category:** Feature

## Description

After incremental **workouts**, each sync uploads **today’s** daily aggregate JSON, then a **batched backfill** of older calendar days so non-workout metrics (steps, energy, sleep, etc.) gradually fill history without separate `HKAnchoredObjectQuery` per quantity type. Cursor: `daily_backfill_oldest_completed` in `HealthData/sync_state.json` (earliest `yyyy-MM-dd` for which a backfill daily file was written).

## Tasks

- [x] `SyncState.dailyBackfillOldestCompleted` + JSON key `daily_backfill_oldest_completed`
- [x] `CalendarDayFormatter.startOfDay(fromYyyyMMdd:calendar:)` for backfill cursor parsing
- [x] `SyncService`: `dailyBackfillMaxAgeDays` (default 730), `dailyBackfillBatchSize` (default 7; 0 = off); shared `dailyBackfillEntries` for foreground upload and background enqueue
- [x] Webhook file lists include backfill daily paths
- [x] Unit tests (`dailyBackfillBatchSize: 0` preserves prior test behavior; backfill scenario with fixed calendar)

## Notes

- Ordering per sync: workout increments → today daily → backfill dailies → `sync_state.json`.
