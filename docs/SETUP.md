# Setup

## Apple Developer Program

HealthKit capabilities and on-device provisioning expect a **paid Apple Developer Program** membership. Until you enroll:

- You can build and run the **simulator** target for UI and non–HealthKit code paths.
- **Device** installs with HealthKit require correct provisioning and entitlements tied to your team.

## Xcode

1. Install Xcode from the Mac App Store.
2. Install XcodeGen (optional but recommended): `brew install xcodegen`
3. Open `HealthSync.xcodeproj`.

If you change `project.yml`, regenerate the project:

```bash
cd /path/to/HealthSync
xcodegen generate
```

## Signing

1. Select the **HealthSync** target → **Signing & Capabilities**.
2. Choose your **Team** when available.
3. Adjust **Bundle Identifier** if it conflicts (default in `project.yml` is `com.example.HealthSync`).

## Configuration and secrets

### Rules

- Do **not** commit hostnames with embedded credentials, app passwords, API keys, or personal health payloads.
- Prefer **Keychain** for passwords and tokens (planned); the current skeleton uses **UserDefaults** only for non-sensitive URL fields during development.

### Environment variables (prefix `HEALTHSYNC_`)

| Variable | Meaning |
|----------|---------|
| `HEALTHSYNC_NEXTCLOUD_BASE_URL` | HTTPS base URL of the Nextcloud instance (no trailing slash) |
| `HEALTHSYNC_NEXTCLOUD_WEBDAV_ROOT` | Optional WebDAV path segment (if not using app defaults) |
| `HEALTHSYNC_SYNC_WEBHOOK_URL` | Optional `POST` endpoint for sync-complete (`health-sync-api` в knowledge-base-bot) |
| `HEALTHSYNC_SYNC_WEBHOOK_TOKEN` | Optional Bearer token (must match `HEALTH_SYNC_API_TOKEN` on the server) |

Set them in **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables** for local debugging.

### Files

- `env.example` — template for **shell/CI** tooling (not read by the app at runtime).
- `Config/Secrets.xcconfig.example` — optional **build-time** overrides; copy to `Config/Secrets.xcconfig` (gitignored).

## HealthKit usage strings

Privacy descriptions live in `HealthSync/Resources/Info.plist`. Update localized copy before App Store submission if you add languages.
