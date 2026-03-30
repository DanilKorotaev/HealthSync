# Nextcloud WebDAV upload and Keychain credentials

**Status:** Done  
**Priority:** High  
**Category:** Feature

## Description

Integrate Nextcloud/WebDAV client (SPM dependency TBD: NextcloudKit or equivalent), store credentials in Keychain, and upload JSON files to the configured `HealthData/` path.

## Tasks

- [x] Add thin wrapper service (native URLSession implementation)
- [x] Keychain read/write for username, app password, or token
- [x] PROPFIND connectivity check from Settings
- [x] PUT with retry/backoff policy

## Notes

- Implemented via native `URLSession` + service wrapper (`WebDAVHTTPClientProtocol`) without external SPM library.
