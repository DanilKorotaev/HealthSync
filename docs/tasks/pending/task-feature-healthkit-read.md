# HealthKit read path and permissions

**Status:** Planned  
**Priority:** High  
**Category:** Feature

## Description

Request read access for required HealthKit types (steps, heart rate, sleep, workouts, HRV, SpO₂ as per plan), implement `HKAnchoredObjectQuery` / batching, and map samples into `DailyHealthData` / `WorkoutData` export models.

## Tasks

- [ ] Define explicit `HKObjectType` set and authorization flow
- [ ] Implement daily aggregation pipeline
- [ ] Implement workout export with zone breakdown where available
- [ ] Unit tests with mocked `HKHealthStore` where feasible

## Notes

- Apple Developer Program required for meaningful on-device validation.
- Background delivery registration in `AppDelegate` after authorization.
