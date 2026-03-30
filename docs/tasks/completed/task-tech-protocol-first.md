# Protocol-first refactor for service layer

**Status:** Done  
**Priority:** High  
**Category:** Technical

## Description

Enforced protocol-oriented architecture for service components to keep logic testable and replaceable.

## Tasks

- [x] Introduce `HealthKitServiceProtocol`
- [x] Introduce `NextCloudServiceProtocol`
- [x] Introduce `SyncServiceProtocol`
- [x] Wire constructor-based dependency injection in app composition root
- [x] Remove direct concrete dependencies from orchestration code

## Acceptance criteria

- [x] All service entry points are referenced by protocol in consuming code
- [x] Test doubles can replace concrete implementations without production side effects
