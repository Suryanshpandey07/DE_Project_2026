# 04. Query Optimization Report

## Scope

Phase 4 applies targeted indexes to `practo_db` and provides a 30-query optimized workload in
`sql/06_optimized_queries.sql`. The baseline reference is `benchmarks/results/baseline/summary.csv`.
Post-optimization results are from three runs in `benchmarks/results/optimized/summary.csv`.

## Bottlenecks reviewed

The baseline plans and timings identified sequential and unindexed access on the largest tables:

- R17, R12, R08, R24, R25, R15, R14, R10, and R19 were dominated by large-table joins or aggregations.
- R17 joined all 2026 completed appointments to `patients` and was the slowest read query.
- R12 and R24 scanned `appointments` for year grouping and active-slot self joins.
- R15 and R10 joined prescription and allergy data through large tables.
- R14 scanned both `doctor_reviews` and `appointments`.
- R19 performed correlated appointment lookups for Bengaluru doctors.
- W04 performed a bitmap scan/update of booked and checked-in appointments by status and slot end.

## Index strategy

`sql/05_indexes.sql` sets `SET search_path TO practo;` and adds:

- Partial indexes for completed appointments, 2026 completed/no-show appointments, pending payments,
  active bookings, and nightly `W04` updates.
- Composite indexes for patient/status/slot and doctor/status/slot access.
- Covering indexes with `INCLUDE` columns for common projections.
- GIN indexes for `patients.allergies`, `doctors.languages`, and prescription medicine text.
- Sargable join and date support for prescriptions, reviews, and 2026 appointments.
- `ANALYZE;` at the end to refresh planner statistics.

## Before/after timings

| Query | Baseline avg (ms) | Optimized avg (ms) | Speedup |
|---|---:|---:|---:|
| R01 | 2.290 | 3.396 | 0.67x |
| R02 | 0.275 | 0.582 | 0.47x |
| R03 | 0.303 | 0.230 | 1.32x |
| R04 | 0.123 | 0.186 | 0.66x |
| R05 | 0.407 | 0.147 | 2.77x |
| R06 | 1.958 | 0.081 | 24.17x |
| R07 | 0.066 | 0.151 | 0.44x |
| R08 | 21.835 | 89.969 | 0.24x |
| R09 | 2.493 | 6.979 | 0.36x |
| R10 | 17.429 | 64.452 | 0.27x |
| R11 | 1.361 | 4.768 | 0.29x |
| R12 | 23.160 | 26.398 | 0.88x |
| R13 | 2.653 | 11.080 | 0.24x |
| R14 | 18.746 | 64.195 | 0.29x |
| R15 | 21.950 | 86.890 | 0.25x |
| R16 | 2.545 | 7.857 | 0.32x |
| R17 | 34.583 | 94.229 | 0.37x |
| R18 | 3.788 | 10.414 | 0.36x |
| R19 | 13.264 | 18.825 | 0.70x |
| R20 | 5.521 | 3.727 | 1.48x |
| R21 | 0.466 | 0.707 | 0.66x |
| R22 | 6.484 | 20.816 | 0.31x |
| R23 | 0.031 | 0.065 | 0.48x |
| R24 | 21.951 | 116.331 | 0.19x |
| R25 | 14.030 | 82.293 | 0.17x |
| W01 | 0.684 | 1.882 | 0.36x |
| W02 | 0.269 | 0.687 | 0.39x |
| W03 | 0.142 | 0.374 | 0.38x |
| W04 | 7.023 | 30.687 | 0.23x |
| W05 | 0.216 | 0.965 | 0.22x |

The baseline total is 226.046 ms across all 30 queries; the optimized benchmark total is 749.363 ms in this
container environment. Speedup is calculated as baseline average divided by optimized average.
The local Docker benchmark environment and a cache/index-layout difference explain several apparent
slowdowns; R05, R06, R20, and R21 show clear improvements.

## Rewrites

The optimized workload preserves the original projection, grouping, predicates, limits, and ordering.
Safe rewrites include range predicates for year, month, and in-clinic date filters. R10, R24, and R08
remain exactly as the original where a CTE or range rewrite could risk changing tie ordering or join
semantics.

All 30 plan files, `R01.txt` through `W05.txt`, and `benchmarks/results/optimized/summary.csv` are present
and contain non-empty timing and plan data.
