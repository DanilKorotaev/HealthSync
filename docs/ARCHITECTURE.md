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
| SwiftUI shell (`MainView`, `SettingsView`) | Main: **today preview** (HealthKit aggregates) + last sync time + Sync now / **Sync (background)** + settings |
| `AppConfiguration` | Reads `HEALTHSYNC_*` env and UserDefaults; user toggle for background-sync notifications |
| `HealthKitService` | Read types + auth + **real daily `HKStatistics` / samples** for the local calendar day + workout mappers |
| `HealthStoreAdapter.shared` | Single `HKHealthStore` for reads + background delivery + observer queries |
| `NextCloudService` | Keychain credentials + PROPFIND validation + foreground PUT retry/backoff + background enqueue |
| `SyncService` | `syncNow()` / background: **incremental workouts** (`HKAnchoredObjectQuery` + anchor in `sync_state`) → **today’s** daily JSON → **historical daily backfill** (batched older calendar days, cursor `daily_backfill_oldest_completed` in `sync_state`) → `sync_state` + optional webhook |
| `BackgroundWebDAVSession` | Background `URLSession` sequential PUT chain + `urlSessionDidFinishEvents` |
| `HealthKitBackgroundObserverRegistrar` | `enableBackgroundDelivery` + `HKObserverQuery` per sample type |
| `BackgroundSyncCoordinator` | Starts observers at launch; ties observer → background sync → notifications |
| `LocalNotificationScheduler` | Optional UNUserNotificationCenter alerts after background work |
| Models (`DailyHealthData`, `WorkoutData`, `SyncState`) | Daily/workout export structures implemented |

## Planned modules

- **HealthKitService** — anchored **workout** batches (done); quantity/sleep remain **daily aggregates** (no per-type anchored backfill).
- **NextCloudService** — optional upload queue / conflict policy refinements.
- **SyncService** — optional tuning of daily backfill (`dailyBackfillBatchSize`, max age); conflict policy if needed.

## Daily backfill (non-workout history)

Workouts use `HKAnchoredObjectQuery`. For steps, energy, sleep summaries, and related **daily** JSON, history is filled by uploading one file per **calendar day**, walking backward from “day before the oldest completed backfill day” (or **yesterday** on first run), up to `dailyBackfillBatchSize` days per sync (default **7**; set **0** to disable). Stops when the cursor would go older than `dailyBackfillMaxAgeDays` (default **730**). The earliest day successfully written is stored in `sync_state.json` as `daily_backfill_oldest_completed` (`yyyy-MM-dd`).

## Architecture constraints (mandatory)

- Services must expose protocols (`*Protocol`) and be injected as dependencies.
- Business logic must remain isolated from concrete frameworks where possible.
- New logic must be covered by tests (unit first, integration where meaningful).

See the implementation plan in the knowledge base for JSON schemas and folder layout.
