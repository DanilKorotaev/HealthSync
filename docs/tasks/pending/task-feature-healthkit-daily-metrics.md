# HealthKit real daily metrics (replace stub)

**Status:** Planned  
**Priority:** High  
**Category:** Feature

## Description

Replace the zero-filled `HealthKitService.dailyAggregationInput(for:)` stub with real HealthKit reads for the selected calendar day (local timezone): quantity statistics (steps, distance, active/basal energy, exercise time, stand), optional resting HR / HRV / SpO₂ aggregates, heart rate samples for min/max/avg, and sleep summary from `HKCategoryType.sleepAnalysis`.

## Tasks

- [ ] Day-bounded predicates and `HKStatisticsQuery` / `HKStatisticsCollectionQuery` (or equivalent) per quantity type
- [ ] Sleep aggregation into `SleepSummary` (aligned with existing model)
- [ ] Wire results into `DailyAggregationInput` + keep `makeDailyHealthData` mapping tested
- [ ] Unit tests with `HealthStoreProtocol` extended or a test double that returns canned metrics (no simulator HealthKit dependency in CI)

## Notes

- Matches implementation plan section 10, **Этап 1** (daily metrics), and prepares for **Этап 3** incremental sync (anchored queries) as a follow-up task.
- Workout-of-day export can be a separate task if scope grows; this task focuses on **daily** JSON accuracy first.
