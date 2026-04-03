# Background delivery and background URLSession

**Status:** Done  
**Priority:** Medium  
**Category:** Feature

## Description

HealthKit background delivery, `HKObserverQuery` with completion-handler discipline, background `URLSession` for sequential WebDAV PUTs, `handleEventsForBackgroundURLSession`, and optional local notifications (Settings toggle).

## Tasks

- [x] `enableBackgroundDelivery` for required sample types (via `HealthKitBackgroundObserverRegistrar`)
- [x] `HKObserverQuery` + completion handler always invoked after work
- [x] Background session identifier (`com.example.HealthSync.background`) and `handleEventsForBackgroundURLSession` in `AppDelegate`
- [x] Local notification on success/failure when enabled in Settings + system permission

## Notes

- Foreground **Sync now** still uses `URLSession.shared` via `NextCloudService.upload`. Observer-driven sync uses `SyncService.syncNowUsingBackgroundUploads` → `NextCloudService.enqueueSequentialBackgroundUploads` → `BackgroundWebDAVSession`.
- `HealthStoreAdapter.shared` is the single production `HKHealthStore` wrapper for reads and background APIs.
- Entitlements: HealthKit + HealthKit background delivery. `Info.plist`: `UIBackgroundModes` (`fetch`, `processing`), Health usage strings, notification usage string.
