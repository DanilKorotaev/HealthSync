# Test infrastructure and coverage baseline

**Status:** Done  
**Priority:** High  
**Category:** Testing

## Description

Set up baseline testing strategy and CI guardrails so every new code change is accompanied by tests.

## Tasks

- [x] Add `HealthSyncTests` target
- [x] Add first unit tests for `AppConfiguration` and `SyncService` behavior
- [x] Add mock/fake test doubles for service protocols
- [x] Document test execution command in CI/local workflow
- [x] Define initial coverage threshold and enforce it in CI

## Acceptance criteria

- [x] `xcodebuild test` runs successfully for the project
- [x] New features require tests in the same PR
- [x] Coverage gate is documented and reproducible

## Notes

- CI workflow: `.github/workflows/ci.yml`
- PR guardrails: `.github/pull_request_template.md`
- Initial baseline coverage threshold: `35%` via `MIN_COVERAGE`
