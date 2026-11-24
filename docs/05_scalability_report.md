# Phase 5: Scalability and Performance Report

## 1. Objective

The objective of this phase was to evaluate the Practo Doctor Appointments
database with a large dataset, review query performance, correct a query
logic issue, and demonstrate PostgreSQL table partitioning.

## 2. Large Dataset

The scalability experiment used the `practo_large` PostgreSQL database.

The appointments table contained 3,000,000 records.

| Dataset detail | Count |
|---|---:|
| Appointments | 3,000,000 |
| Clinics | 30,000 |
| Doctors | 60,000 |
| Patients | 800,000 |
| Doctor reviews | 608,179 |
| Doctor schedules | 609,747 |
| Prescriptions | 1,944,432 |
| Prescription items | 4,861,186 |

Appointment date range:

- Earliest appointment: 1 January 2025
- Latest appointment: 16 July 2026
- 2025 appointments: 1,970,284
- 2026 appointments: 1,029,716

## 3. Large-Scale Query Benchmark

The benchmark covered 30 workload queries:

- R01–R25: read queries
- W01–W05: write queries

Each query was executed five times using the benchmark script.
Write queries were executed inside transactions and rolled back, so the
benchmark did not permanently apply their modifications.

The consolidated results are available in:

`benchmarks/results/large/summary.csv`

The raw benchmark outputs are preserved in the corresponding result folders.

### Selected query observations

The following values are median execution times in milliseconds from the
consolidated large-data benchmark.

| Query | Median (ms) |
|---|---:|
| R01 | 8.608 |
| R02 | 0.061 |
| R03 | 0.108 |
| R04 | 0.035 |
| R05 | 0.075 |
| R06 | 0.028 |
| R07 | 0.038 |
| R08 | 295.632 |
| R09 | 30.667 |
| R10 | 361.834 |
| R11 | 12.166 |
| R12 | 267.385 |
| R13 | 15.722 |
| R14 | 341.586 |
| R15 | 248.137 |
| R16 | 68.384 |
| R17 | 433.046 |
| R18 | 45.644 |
| R19 | 116.140 |
| R20 | 89.370 |
| R21 | 0.050 |
| R22 | 6.029 |
| R23 | 0.026 |
| R24 | 1290.164 |
| R25 | 305.674 |
| W01 | 0.836 |
| W02 | 0.249 |
| W03 | 0.064 |
| W04 | 324.708 |
| W05 | 0.055 |

Execution times are workload- and environment-dependent. The medians are
reported alongside the averages, minimums and maximums in the CSV because
some queries showed substantial run-to-run variation.

### Query plan observations

The large-data execution plans showed a mixture of:

- Sequential scans for queries reading a substantial part of a table.
- Index scans for selective lookups.
- Index-only scans for queries supported by covering indexes.
- Bitmap scans for queries matching multiple rows.

R24 had the highest read-query median in this benchmark at 1290.164 ms.
This query is a candidate for further query-plan and indexing investigation.

W04 had a median of 324.708 ms and substantial timing variation. Its
average was 1230.473 ms, showing why repeated measurements and medians
are useful when evaluating performance.

## 4. R13 NULL-Handling Correction

The original R13 query used `NOT IN` to find clinics without doctor schedules.

The `doctor_schedules.clinic_id` column contained 117,747 NULL values.
A `NOT IN` subquery containing NULL can cause comparisons to evaluate to
UNKNOWN, which can incorrectly filter out rows.

The query was corrected to use `NOT EXISTS`:

```sql
SELECT c.clinic_id, c.clinic_name, c.city_id
FROM clinics c
WHERE NOT EXISTS (
    SELECT 1
    FROM doctor_schedules sc
    WHERE sc.clinic_id = c.clinic_id
);
```

## 5. Appointment Table Partitioning

A separate partitioned table, `practo.appointments_partitioned`, was created to evaluate range partitioning on the `slot_start` column.

The original `practo.appointments` table was preserved.

The partitioned table uses:
- Range partitioning on `slot_start`
- Composite primary key `(appointment_id, slot_start)`
- Yearly partitions for 2025, 2026, and 2027
- A default partition

The experiment copied all 3,000,000 appointment rows. The shadow table does not reproduce the original foreign-key relationships because the original appointment references use `appointment_id` alone.

## 6. Partition Pruning Experiment

| Partition | Appointment rows |
|---|---:|
| 2025 | 1,970,284 |
| 2026 | 1,029,716 |
| Total | 3,000,000 |

A query filtering appointments from May 2026 accessed only `appointments_partitioned_2026`, demonstrating partition pruning.

## 7. Original vs Partitioned Query Performance

Six alternating measurements were taken. Run 1 was treated as a warm-up and excluded from the median comparison.

| Measurement | Original (ms) | Partitioned (ms) |
|---|---:|---:|
| Run 1 (warm-up) | 16.973 | 8.201 |
| Run 2 | 8.935 | 5.986 |
| Run 3 | 7.378 | 5.383 |
| Run 4 | 6.681 | 5.400 |
| Run 5 | 6.698 | 5.517 |
| Run 6 | 6.751 | 5.297 |
| Median excluding warm-up | 6.751 | 5.400 |

For this particular date-range query, the partitioned table had an approximately 20% lower median execution time. This result should not be generalized to every query or the complete workload.

Raw measurements are available in `benchmarks/results/partitioning_comparison/summary.csv`.

## 8. Indexing and Query Performance

The benchmark plans showed different scan strategies depending on query conditions and data volume:

- Index-only scans for queries answerable using indexed columns.
- Index scans for selective lookups.
- Sequential scans for queries processing a large portion of a table.
- Bitmap scans for some filtering operations.
- Anti-join execution for the corrected R13 query.

Indexes can improve selective lookups and joins, but require storage and add overhead to data modifications. Index selection should be based on measured query patterns.

## 9. Limitations

- Results come from one PostgreSQL test environment.
- Execution times can vary with hardware, configuration, cache state, and concurrent load.
- The partitioning comparison covers one date-range query only.
- The partitioned table is an experimental shadow table, not a replacement for the original.
- The test dataset may not represent every production workload.

## 10. Conclusion

The Phase 5 experiments evaluated the Practo database with 3,000,000 appointment records.

The large-scale benchmark measured read and write queries using repeated executions and median timings. R13 was corrected to use `NOT EXISTS`, avoiding the NULL-related behavior of `NOT IN`.

The partitioning experiment demonstrated partition pruning. For the tested date-range query, the partitioned table achieved a median execution time of 5.400 ms compared with 6.751 ms for the original table.

Overall, the experiments demonstrate how query corrections, indexing, benchmarking, and partitioning can be evaluated using PostgreSQL execution plans and measured timings.
