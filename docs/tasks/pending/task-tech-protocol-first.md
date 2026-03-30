# Protocol-first refactor for service layer

**Status:** Planned  
**Priority:** High  
**Category:** Technical

## Description

Enforce protocol-oriented architecture for all service components to keep logic testable and replaceable.

## Tasks

- [ ] Introduce `HealthKitServiceProtocol`
- [ ] Introduce `NextCloudServiceProtocol`
- [ ] Introduce `SyncServiceProtocol`
- [ ] Wire constructor-based dependency injection in app composition root
- [ ] Remove direct concrete dependencies from orchestration code

## Acceptance criteria

- [ ] All service entry points are referenced by protocol in consuming code
- [ ] Test doubles can replace concrete implementations without production side effects
