# Background delivery and background URLSession

**Status:** Planned  
**Priority:** Medium  
**Category:** Feature

## Description

Enable HealthKit background delivery, use background `URLSession` for uploads, and local notification on completion (per implementation plan — no Live Activities in v1).

## Tasks

- [ ] `enableBackgroundDelivery` for required types
- [ ] `HKObserverQuery` + completion handler discipline
- [ ] Background session identifier and `handleEventsForBackgroundURLSession`
- [ ] Local notification on success/failure (user-toggle)
