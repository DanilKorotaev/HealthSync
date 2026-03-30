# Nextcloud WebDAV upload and Keychain credentials

**Status:** Planned  
**Priority:** High  
**Category:** Feature

## Description

Integrate Nextcloud/WebDAV client (SPM dependency TBD: NextcloudKit or equivalent), store credentials in Keychain, and upload JSON files to the configured `HealthData/` path.

## Tasks

- [ ] Add SPM dependency and thin wrapper service
- [ ] Keychain read/write for username, app password, or token
- [ ] PROPFIND connectivity check from Settings
- [ ] PUT with retry/backoff policy
