# Sync orchestration and JSON export

**Status:** Planned  
**Priority:** High  
**Category:** Feature

## Description

Connect HealthKit export, file naming (`daily/YYYY-MM-DD.json`, `workouts/...`), and `sync_state.json` updates; optional webhook `POST` after successful upload.

## Tasks

- [ ] Encode models matching knowledge base JSON schema
- [ ] Idempotent uploads and state persistence
- [ ] Manual “Sync now” and “Initial full backfill” flows
- [ ] Error surfacing in UI
