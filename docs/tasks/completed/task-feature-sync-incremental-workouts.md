# Incremental sync — workouts first

**Status:** Done  
**Priority:** High  
**Category:** Feature

## Description

Incremental export of **workouts** using `HKAnchoredObjectQuery`, persisting a base64 `HKQueryAnchor` in `HealthData/sync_state.json` (`workout_query_anchor`). Each sync downloads existing `sync_state.json` (GET), uploads new/changed workouts to `HealthData/workouts/{yyyy-MM-dd}_{uuid}.json`, then daily JSON and updated `sync_state`. Webhook receives all touched file paths.

## Tasks

- [x] `NextCloudService.download` (GET, 404 → nil)
- [x] `SyncState.workoutQueryAnchor` + encode/decode anchor (`HKQueryAnchorCoder`)
- [x] `HealthKitService.fetchWorkoutsIncremental` + `WorkoutAnchoredQuery` on `HealthStoreAdapter`
- [x] Map `HKWorkout` → `WorkoutAggregationInput` (HR samples in workout window, `WorkoutTypeSlug`, `is_gym` heuristics)
- [x] `WorkoutData.source_id` from `HKWorkout.uuid`
- [x] `SyncService` ordering: incremental workouts → daily → state; background upload chains all files
- [x] Unit tests (mock batches, GET, webhook file lists)

## Notes

- **Next:** anchored / incremental sync for quantity samples and sleep (separate anchors or unified strategy) — not in this task.
- First-time sync with `nil` anchor may return large batches (limit 50 per `HKAnchoredObjectQuery` call) until the anchor catches up.
