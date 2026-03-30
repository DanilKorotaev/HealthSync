# HealthSync

iOS app skeleton for syncing Apple Health exports to structured storage (Nextcloud / WebDAV) and optional webhook triggers, as described in the knowledge base implementation plan.

**Repository:** [github.com/DanilKorotaev/HealthSync](https://github.com/DanilKorotaev/HealthSync)

## Requirements

- Xcode 16+
- iOS 17+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — to regenerate `HealthSync.xcodeproj` from `project.yml` after structural changes

## Quick start

1. Clone the repository.
2. Open `HealthSync.xcodeproj` (or run `xcodegen generate` after editing `project.yml`).
3. Set your **team** in the target signing settings when you have an Apple Developer account; until then, local simulator builds work for UI-only work. HealthKit entitlements require a paid program for device builds and distribution.
4. Optional: copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig` for local build-time overrides (`Secrets.xcconfig` is gitignored).

## Configuration

- **Runtime:** non-secret URLs can be set via Xcode scheme **Environment Variables** (prefix `HEALTHSYNC_`) or in-app **Settings** (stored in UserDefaults for development; Keychain planned for credentials).
- **Local tooling:** see `env.example` for variable names aligned with the app prefix.
- **Never commit** real URLs with embedded credentials, app passwords, or tokens.

Full details: [docs/SETUP.md](docs/SETUP.md).

## Documentation

| Document | Description |
|----------|-------------|
| [docs/README.md](docs/README.md) | Documentation index |
| [docs/SETUP.md](docs/SETUP.md) | Environment and Xcode setup |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | How to develop and regenerate the project |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Module layout and planned services |
| [docs/todo.md](docs/todo.md) | Active tasks |
| [docs/completed.md](docs/completed.md) | Completed tasks |

## License

TBD (add a `LICENSE` file when you choose a license for the public repo).
