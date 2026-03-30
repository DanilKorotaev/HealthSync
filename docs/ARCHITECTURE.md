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
| SwiftUI shell (`MainView`, `SettingsView`) | Stub |
| `AppConfiguration` | Reads `HEALTHSYNC_*` env and UserDefaults |
| `HealthKitService` | Explicit read type set + authorization flow + daily/workout mapper aggregation |
| `NextCloudService` | Keychain credentials + PROPFIND validation + PUT retry/backoff |
| `SyncService`, `BackgroundSyncService` | Stubs |
| Models (`DailyHealthData`, `WorkoutData`, `SyncState`) | Daily/workout export structures implemented |

## Planned modules

- **HealthKitService** — permissions, anchored queries, background delivery registration.
- **NextCloudService** — WebDAV PUT, credentials from Keychain.
- **SyncService** — orchestration, JSON encoding, conflict policy.
- **BackgroundSyncService** — `URLSession` background configuration and completion handlers.

## Architecture constraints (mandatory)

- Services must expose protocols (`*Protocol`) and be injected as dependencies.
- Business logic must remain isolated from concrete frameworks where possible.
- New logic must be covered by tests (unit first, integration where meaningful).

See the implementation plan in the knowledge base for JSON schemas and folder layout.
