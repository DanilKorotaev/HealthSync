# Coding Standards

These standards are mandatory for all new code in this repository.

## 1) Protocol-first design (required)

- Every service/repository/coordinator must be represented by a protocol.
- Production implementation depends on abstractions, not concrete types.
- Dependency injection is required (constructor injection by default).
- Avoid singleton-driven architecture for business logic.

### Minimum pattern

- `HealthKitServiceProtocol` + `HealthKitService`
- `NextCloudServiceProtocol` + `NextCloudService`
- `SyncServiceProtocol` + `SyncService`

## 2) Test coverage (required)

- Every new production file must have tests in the same PR.
- Unit tests are mandatory for business logic and orchestration.
- Integration tests are required for boundaries where practical.
- PR is not complete if behavior changed without tests.

## 3) Definition of done (DoD)

A task is done only if all items are true:

1. Protocol abstraction introduced/updated.
2. Tests added/updated for the behavior.
3. Local test run is green.
4. Documentation updated (if behavior/config changed).

## 4) Project policy

- No personal data, secrets, tokens, keys, or credentials in git history.
- Runtime configuration must be externalized (environment variables, Keychain, local config files that are gitignored).
