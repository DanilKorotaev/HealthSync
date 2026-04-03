# HealthKit real daily metrics (replace stub)

**Status:** Done  
**Priority:** High  
**Category:** Feature

## Description

Replace the zero-filled `HealthKitService.dailyAggregationInput(for:)` stub with real HealthKit reads for the selected calendar day (local timezone): quantity statistics (steps, distance, active/basal energy, exercise time, stand), optional resting HR / HRV / SpO₂ aggregates, heart rate min/max/avg via `HKStatistics`, and sleep summary from `HKCategoryType.sleepAnalysis`.

## Tasks

- [x] Day-bounded predicates and `HKStatisticsQuery` per quantity type (`DailyHealthKitDataProviding` on `HealthStoreAdapter`)
- [x] Sleep aggregation into `SleepSummary` via `DailyMetricsSleepAggregator` (clips segments to local day)
- [x] Wire results into `DailyAggregationInput` (`heartRateSummary` + `makeDailyHealthData`) + tests
- [x] Unit tests with empty query mock (no simulator HealthKit dependency in CI) + `HKCategorySample` sleep tests

## Notes

- Local calendar day key: `CalendarDayFormatter.yyyyMMddLocalDay(containing:calendar:)`.
- `dailyAggregationInput` throws `healthDataUnavailable` when Health data is not available (aligned with `SyncService` guard).
- Next follow-up: incremental / anchored sync for **Этап 3** (historical days + `sync_state` progress).
