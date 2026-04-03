# Architecture

## Goal

Mirror the design in the knowledge base **Apple Health iOS application** plan:

1. Read HealthKit samples (daily aggregates and workouts).
2. Serialize JSON into a `HealthData/` tree (daily + workouts + `sync_state.json`).
3. Upload via **WebDAV** to Nextcloud (implemented with native URLSession wrapper + protocol abstraction).
4. Optionally call a **webhook** after upload for server-side linking with Obsidian notes.

## Current skeleton

| Area | Status |
|------|--------|
| SwiftUI shell (`MainView`, `SettingsView`) | Main: Sync now + **Sync (background)** + settings (Nextcloud + notification toggle) |
| `AppConfiguration` | Reads `HEALTHSYNC_*` env and UserDefaults; user toggle for background-sync notifications |
| `HealthKitService` | Read types + auth + **real daily `HKStatistics` / samples** for the local calendar day + workout mappers |
| `HealthStoreAdapter.shared` | Single `HKHealthStore` for reads + background delivery + observer queries |
| `NextCloudService` | Keychain credentials + PROPFIND validation + foreground PUT retry/backoff + background enqueue |
| `SyncService` | `syncNow()` / background: **incremental workouts** (`HKAnchoredObjectQuery` + anchor in `sync_state`) → daily JSON → `sync_state` + optional webhook |
| `BackgroundWebDAVSession` | Background `URLSession` sequential PUT chain + `urlSessionDidFinishEvents` |
| `HealthKitBackgroundObserverRegistrar` | `enableBackgroundDelivery` + `HKObserverQuery` per sample type |
| `BackgroundSyncCoordinator` | Starts observers at launch; ties observer → background sync → notifications |
| `LocalNotificationScheduler` | Optional UNUserNotificationCenter alerts after background work |
| Models (`DailyHealthData`, `WorkoutData`, `SyncState`) | Daily/workout export structures implemented |

## Planned modules

- **HealthKitService** — anchored **workout** batches; incremental quantity/sleep samples (next milestone).
- **NextCloudService** — optional upload queue / conflict policy refinements.
- **SyncService** — historical backfill and conflict policy.

## Architecture constraints (mandatory)

- Services must expose protocols (`*Protocol`) and be injected as dependencies.
- Business logic must remain isolated from concrete frameworks where possible.
- New logic must be covered by tests (unit first, integration where meaningful).

See the implementation plan in the knowledge base for JSON schemas and folder layout.
