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

## Branching

Use short-lived branches and open PRs to `main` once collaboration starts; exact Git flow can mirror the knowledge-base-bot `GIT_FLOW.md` pattern if you add it later.
