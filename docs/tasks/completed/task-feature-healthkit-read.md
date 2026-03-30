# HealthKit read path and permissions

**Status:** Done  
**Priority:** High  
**Category:** Feature

## Description

Request read access for required HealthKit types (steps, heart rate, sleep, workouts, HRV, SpO₂ as per plan), implement `HKAnchoredObjectQuery` / batching, and map samples into `DailyHealthData` / `WorkoutData` export models.

## Tasks

- [x] Define explicit `HKObjectType` set and authorization flow
- [x] Implement daily aggregation pipeline
- [x] Implement workout export with zone breakdown where available
- [x] Unit tests with mocked `HKHealthStore` where feasible

## Notes

- Apple Developer Program required for meaningful on-device validation.
- Background delivery registration in `AppDelegate` after authorization.
- Implemented in code: explicit read type set, async auth wrapper, daily/workout mappers, heart rate zone aggregation, unit tests for all public behavior.
