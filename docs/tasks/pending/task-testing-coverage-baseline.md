# Test infrastructure and coverage baseline

**Status:** Planned  
**Priority:** High  
**Category:** Testing

## Description

Set up a baseline testing strategy so every new code change is accompanied by tests.

## Tasks

- [ ] Add `HealthSyncTests` target
- [ ] Add first unit tests for `AppConfiguration` and `SyncService` behavior
- [ ] Add mock/fake test doubles for service protocols
- [ ] Document test execution command in CI/local workflow
- [ ] Define initial coverage threshold and enforce it in CI

## Acceptance criteria

- [ ] `xcodebuild test` runs successfully for the project
- [ ] New features require tests in the same PR
- [ ] Coverage gate is documented and reproducible
