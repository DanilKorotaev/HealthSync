# Main screen: today preview + last successful sync

**Status:** Done  
**Category:** Feature

## Description

- **Today preview:** read-only aggregates for the current calendar day (`dailyAggregationInput` → `DailyHealthData`), same pipeline as export.
- **Last sync:** `SyncRunStore` persists `UserDefaults` timestamp after successful foreground or background sync (after webhook step completes without error).

## Notes

- Server-side `lastSyncedAt` remains in `HealthData/sync_state.json`; local value is for UX when offline.
- Related server work (Path 2 linking, shared Python module) lives in `knowledge-base-bot` pending tasks.
