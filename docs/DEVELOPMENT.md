# Development

## Layout

- `HealthSync/` — Swift sources (App, Models, Services, Views, Configuration, Resources)
- `project.yml` — XcodeGen specification
- `HealthSync.entitlements` — HealthKit + background delivery flags
- `Config/` — shared `xcconfig` files for Debug/Release

## Regenerating the Xcode project

After editing `project.yml` (new sources, frameworks, plist paths):

```bash
xcodegen generate
```

Commit both `project.yml` and `HealthSync.xcodeproj` so clones build without XcodeGen.

## Building from the command line

```bash
xcodebuild -scheme HealthSync -destination 'generic/platform=iOS Simulator' build
```

## Testing policy (mandatory)

- All new production code must include tests in the same change.
- Use protocol-driven design to make services testable with mocks/fakes.
- A change is not considered complete without green tests.

Recommended local command:

```bash
xcodebuild test -scheme HealthSync -destination 'platform=iOS Simulator,name=iPhone 16'
```

## CI quality gates

- CI workflow is defined in `.github/workflows/ci.yml`.
- **No XcodeGen on CI runners:** `HealthSync.xcodeproj` is committed; GitHub Actions does not run `xcodegen` (it is not installed by default). After changing `project.yml`, run `xcodegen generate` locally and commit the updated `.xcodeproj`.
- Every PR runs tests with `-enableCodeCoverage YES`.
- Coverage threshold is enforced by `MIN_COVERAGE` (current baseline: `35`).
- PR template requires explicit confirmation for tests, protocol-first design, and secrets policy.

## Branching

Use short-lived branches and open PRs to `main` once collaboration starts; exact Git flow can mirror the knowledge-base-bot `GIT_FLOW.md` pattern if you add it later.
