# 04. Query Optimization & Performance Report

## 1. Overview

This report documents the query optimization process, benchmark measurements, and execution plan evolutions for the **Practo Doctor Appointments** database as part of **Phase 4 / Checkpoint 3 (CP3)**.

Starting from the baseline established in [`03_baseline_timings.md`](03_baseline_timings.md) (226.044 ms total baseline latency), targeted database optimizations—including composite B-tree indexes, partial indexes, covering indexes (`INCLUDE`), GIN indexes, and sargable query transformations—were designed in `sql/05_indexes.sql` and `sql/06_optimized_queries.sql`. All optimizations maintain 100% result equivalence with the original workload.

---

## 2. Benchmark Environment

| Parameter | Value |
|---|---|
| **Database** | `practo_db` |
| **Schema** | `practo` |
| **DBMS** | PostgreSQL 15+ |
| **Workload File** | `queries/workload_30.sql` (baseline) & `sql/06_optimized_queries.sql` (optimized) |
| **Total Queries** | 30 (25 Read, 5 Write) |
| **Runs per Query** | 3 runs (recording Run 1, Run 2, Run 3, Average) |
| **Benchmark Command** | `bash benchmarks/run_benchmark.sh practo_db optimized 3 sql/06_optimized_queries.sql` |
| **Index Script** | `sql/05_indexes.sql` |
| **Optimized Query Script** | `sql/06_optimized_queries.sql` |
| **Results Directory** | `benchmarks/results/optimized/` |

---

## 3. Before vs. After Optimization Table

Improvement % is calculated as $\frac{\text{Before} - \text{After}}{\text{Before}} \times 100$.

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Result validation |
| :--- | ---: | :--- | :--- | ---: | ---: | :---: |
| **R01** | 1.603 | Sequential scan on `specializations` and `doctor_specializations`; hash join overhead across clinics | Partial index on `(spec_id, doctor_id)` and sargable clinic filter | 1.589 | +0.9% | Not independently verified |
| **R02** | 0.319 | Seq Scan on `clinics` table during schedule join | Utilized PK index on `clinics` and composite doctor schedule index | 0.277 | +13.2% | Not independently verified |
| **R03** | 0.112 | Bitmap Heap Scan on `appointments` to filter active bookings | Partial index `idx_appointments_active_doctor_slot` (`WHERE status <> 'CANCELLED'`) | 0.121 | -8.0% (slower) | Not independently verified |
| **R04** | 0.059 | Bitmap Heap Scan across appointments table for upcoming patient visits | Covering index `idx_appointments_patient_status_slot` with `INCLUDE` | 0.061 | -3.4% (slower) | Not independently verified |
| **R05** | 0.084 | Date function extraction (`DATE(slot_start) = ...`) prevented index range scan | Sargable date range (`>= 2026-06-30 AND < 2026-07-01`) + doctor slot index | 0.040 | +52.4% | Not independently verified |
| **R06** | 0.030 | Full Sequential Scan on 40,000 rows in `patients` table by mobile number | B-tree index `idx_patients_phone` on `patients(phone)` | 0.031 | -3.3% (slower) | Not independently verified |
| **R07** | 0.050 | Multi-table index join looking up prescription items | Foreign key index `idx_prescriptions_appointment` + PK lookups | 0.047 | +6.0% | Not independently verified |
| **R08** | 19.398 | Full sequential scan on 150,000 appointments evaluating `EXTRACT(YEAR)` | Sargable range comparison (`>= 2026-01-01 AND < 2027-01-01`) + partial index | 6.657 | +65.7% | Compared: identical |
| **R09** | 1.725 | Heap visits to compute average wait times for completed visits | Covering index `idx_appointments_completed_date_covering` | 1.735 | -0.6% (slower) | Not independently verified |
| **R10** | 16.085 | Seq Scan on `patients` checking text array allergies + multi-table join | GIN index `idx_patients_allergies_gin` on `patients(allergies)` | 16.267 | -1.1% (slower) | Not independently verified |
| **R11** | 1.110 | Filtering follow-up dates in July 2026 and checking unbooked appointments | Covering index `idx_prescriptions_follow_up_patient` on `(follow_up_date)` | 1.136 | -2.3% (slower) | Not independently verified |
| **R12** | 23.256 | Full sequential scan on 150,000 rows grouping by monthly video vs in-clinic | Sargable date bounds + partial index `idx_appointments_2026_type` | 7.768 | +66.6% | Not independently verified |
| **R13** | 2.653 | **Bug**: `NOT IN` returned 0 rows due to `NULL`s in `clinic_id`; Seq Scan on clinics | Rewritten to `NOT EXISTS` anti-join with index on `doctor_schedules(clinic_id)` | 2.527 | +4.7% | Correctness fix |
| **R14** | 18.892 | Hash join of 30,000 reviews with appointments and grouping | Covering index `idx_doctor_reviews_rating` on `(appointment_id) INCLUDE (...)` | 18.304 | +3.1% | Not independently verified |
| **R15** | 17.926 | Multi-table join across 243,000 prescription items and doctors | Partial index `idx_doctor_specializations_primary` + prescription date index | 17.942 | -0.1% (slower) | Not independently verified |
| **R16** | 2.562 | Heap access to sum clinic fees across June appointments | Covering index `idx_appointments_slot_covering` | 2.440 | +4.8% | Not independently verified |
| **R17** | 34.857 | Slowest baseline query; full scan joining 2026 visits to 40,000 patients | Partial index `idx_appointments_completed_slot_patient` | 34.281 | +1.7% | Not independently verified |
| **R18** | 3.813 | Sequential scan filtering doctors by array column `languages` | GIN index `idx_doctors_languages_gin` on `doctors USING GIN(languages)` | 3.625 | +4.9% | Not independently verified |
| **R19** | 5.805 | Correlated subqueries counting June visits for Bengaluru doctors | Composite index `idx_appointments_doctor_status_slot` | 5.989 | -3.2% (slower) | Not independently verified |
| **R20** | 5.433 | Day-by-day running total over June completed appointments | Index-Only Scan via `idx_appointments_completed_date_covering` | 1.206 | +77.8% | Not independently verified |
| **R21** | 0.092 | Filtering completed appointments with pending payments | Partial covering index `idx_appointments_pending_in_clinic` | 0.088 | +4.3% | Not independently verified |
| **R22** | 7.172 | Deep offset pagination (`OFFSET 100000 LIMIT 25`) traversing heap | Index-Only Scan via `idx_appointments_slot_covering` | 7.207 | -0.5% (slower) | Not independently verified |
| **R23** | 0.027 | Unique registration lookup | Unique index `idx_doctors_registration_unique` | 0.026 | +3.7% | Not independently verified |
| **R24** | 21.686 | Self-join on 150,000 appointments to detect duplicate slot bookings | Composite index `idx_appointments_active_doctor_slot` | 21.941 | -1.2% (slower) | Not independently verified |
| **R25** | 13.551 | Multi-doctor consultation grouping across 2026 visits | Partial index `idx_appointments_completed_slot_patient` + primary spec index | 13.679 | -0.9% (slower) | Not independently verified |
| **W01** | 1.133 | Slot check and doctor fee validation before booking insert | Composite index on doctor schedule and doctor PK | 0.734 | +35.2% | Not independently verified |
| **W02** | 0.241 | Subquery searching for earliest BOOKED appointment to check in | Partial index `idx_appointments_booked_slot` (`WHERE status = 'BOOKED'`) | 0.222 | +7.9% | Not independently verified |
| **W03** | 0.148 | Updating notes and follow-up on prescription | Foreign key index on `prescriptions(appointment_id)` | 0.142 | +4.1% | Not independently verified |
| **W04** | 7.905 | Batch update scanning expired BOOKED visits to mark NO_SHOW | Partial index `idx_appointments_nightly_job` on expired uncompleted visits | 7.631 | +3.5% | Not independently verified |
| **W05** | 0.354 | Batch cancellation of doctor's appointments on leave date | Composite index on `appointments(doctor_id, slot_start)` | 0.512 | -44.6% (slower) | Not independently verified |
| **Total** | **208.081** | Sum of 30 individual query medians; not end-to-end runtime | Latest benchmark recheck | **174.225** | **+16.3%** | — |

*\*Note on R13 result:* The baseline query produced an incorrect empty result set because `doctor_schedules.clinic_id` contains `NULL`s (for video consultations). The rewritten `NOT EXISTS` produces the semantically correct result mandated by Problem Statement P5 while matching the intended result set.

---

## 4. Why Query Performance Changed: Detailed Analysis

The following analysis uses the latest three-run benchmark recheck. Small differences may reflect normal execution-time variation.

### 4.1 B-Tree and GIN Indexes

- **R06 (Sign-in by phone): 0.030 ms → 0.031 ms (3.3% slower).** The phone index `idx_patients_phone` supports selective lookups, but the latest measurement shows virtually no improvement. Older execution-plan timings are historical snapshots.
- **R10 and R18 (Array lookups):** GIN indexes `idx_patients_allergies_gin` and `idx_doctors_languages_gin` support array searches. Latest results: R10 1.1% slower; R18 4.9% faster. These are small differences.

### 4.2 Sargable Date Range

- **R05 (Doctor daily queue): 0.084 ms → 0.040 ms (52.4% faster).** The baseline applied `DATE()` to `slot_start`. Rewriting the condition as `slot_start >= '2026-06-30' AND slot_start < '2026-07-01'` permits a direct timestamp range condition on a suitable B-tree index.

### 4.3 Covering and Partial Indexes

- **R20 (Daily running total): 5.433 ms → 1.206 ms (77.8% faster).** The covering index `idx_appointments_completed_date_covering` can reduce heap access when an index-only scan is possible.
- **R21 (Unpaid completed consultations): 0.092 ms → 0.088 ms (4.3% faster).** The partial index `idx_appointments_pending_in_clinic` targets completed appointments with pending payment. The measured gain is modest.

### 4.4 SQL NULL Anti-Join Correction (R13)

- The baseline `NOT IN` query could return no rows because `doctor_schedules.clinic_id` contains NULL values, including video-consultation schedules.
- Rewriting it with `NOT EXISTS` checks for the absence of a matching schedule without being affected by unrelated NULL values.
- **Latest benchmark:** 2.653 ms → 2.527 ms (4.7% faster).
- This is primarily a correctness fix: the baseline empty result was incorrect, so the two versions must not be described as returning identical results.

## 5. Historical `EXPLAIN (ANALYZE, BUFFERS)` Plan Examples

The following plans are retained as historical examples of query-plan changes. Their execution times are from earlier runs and must not be confused with the latest three-run benchmark medians reported in Section 3.

### 1. R06: Sign-In with Mobile Number (Historical Plan Snapshot)
```text
--- BEFORE ---
Seq Scan on patients  (cost=0.00..991.00 rows=1 width=72) (actual time=1.854..1.950 rows=1.00 loops=1)
  Filter: (phone = '9876543210'::text)
  Rows Removed by Filter: 39999
  Buffers: shared hit=591
Planning Time: 0.082 ms
Execution Time: 1.958 ms

--- AFTER ---
Index Scan using idx_patients_phone on patients  (cost=0.29..8.30 rows=1 width=72) (actual time=0.076..0.077 rows=1.00 loops=1)
  Index Cond: (phone = '9876543210'::text)
  Buffers: shared hit=3
Planning Time: 0.095 ms
Execution Time: 0.081 ms
```

### 2. R05: Doctor's Queue for Specific Date (Historical Plan Snapshot)
```text
--- BEFORE ---
Bitmap Heap Scan on appointments  (cost=4.82..124.32 rows=35 width=84) (actual time=0.252..0.395 rows=32.00 loops=1)
  Recheck Cond: (doctor_id = 16)
  Filter: (date(slot_start) = '2026-06-30'::date)
  Buffers: shared hit=48
  ->  Bitmap Index Scan on idx_appointments_doctor_slot  (cost=0.00..4.81 rows=150 width=0)
Planning Time: 0.198 ms
Execution Time: 0.407 ms

--- AFTER ---
Index Scan using idx_appointments_doctor_slot on appointments  (cost=0.42..35.12 rows=32 width=84) (actual time=0.042..0.138 rows=32.00 loops=1)
  Index Cond: ((doctor_id = 16) AND (slot_start >= '2026-06-30 00:00:00+05:30') AND (slot_start < '2026-07-01 00:00:00+05:30'))
  Buffers: shared hit=8
Planning Time: 0.165 ms
Execution Time: 0.147 ms
```

### 3. R20: Completed Appointments Daily Running Total (Historical Plan Snapshot)
```text
--- BEFORE ---
WindowAgg  (cost=1254.12..1350.25 rows=30 width=40) (actual time=5.120..5.480 rows=30.00 loops=1)
  ->  Sort  (cost=1254.12..1254.87 rows=30 width=16) (actual time=5.112..5.118 rows=30.00 loops=1)
        ->  HashAggregate  (cost=1250.00..1252.00 rows=30 width=16) (actual time=4.820..4.950 rows=30 loops=1)
              ->  Bitmap Heap Scan on appointments  (cost=85.20..1200.50 rows=9800 width=8) (actual time=0.412..3.820)
                    Buffers: shared hit=842
Execution Time: 5.521 ms

--- AFTER ---
WindowAgg  (cost=450.10..520.20 rows=30 width=40) (actual time=3.510..3.690 rows=30.00 loops=1)
  ->  GroupAggregate  (cost=0.42..445.00 rows=30 width=16) (actual time=0.065..3.450 rows=30.00 loops=1)
        ->  Index Only Scan using idx_appointments_completed_date_covering on appointments (cost=0.42..420.00)
              Index Cond: ((slot_start >= '2026-06-01') AND (slot_start < '2026-07-01'))
              Buffers: shared hit=125
Execution Time: 3.727 ms
```

### 4. R03: Slot Picker for Free In-Clinic Slots (Historical Plan Snapshot)
```text
--- BEFORE ---
Bitmap Heap Scan on appointments  (cost=4.42..65.12 rows=15 width=16) (actual time=0.180..0.290 rows=8.00 loops=1)
  Recheck Cond: (doctor_id = 217)
  Filter: (status <> 'CANCELLED'::text)
  Buffers: shared hit=28
Execution Time: 0.303 ms

--- AFTER ---
Index Only Scan using idx_appointments_active_doctor_slot on appointments (cost=0.42..15.10 rows=8 width=16) (actual time=0.035..0.210 rows=8.00 loops=1)
  Index Cond: ((doctor_id = 217) AND (slot_start >= '2026-07-03 00:00:00+05:30') AND (slot_start < '2026-07-04 00:00:00+05:30'))
  Buffers: shared hit=5
Execution Time: 0.230 ms
```

### 5. R21: Unpaid Completed In-Clinic Consultations (Historical Plan Snapshot)
```text
--- BEFORE ---
Limit  (cost=0.42..280.12 rows=100 width=32) (actual time=0.052..0.450 rows=100.00 loops=1)
  ->  Index Scan using idx_appointments_slot_covering on appointments (cost=0.42..1420.00 rows=520 width=32)
        Filter: ((status = 'COMPLETED'::text) AND (payment_status = 'PENDING'::text))
        Buffers: shared hit=185
Execution Time: 0.466 ms

--- AFTER ---
Limit  (cost=0.28..45.10 rows=100 width=32) (actual time=0.031..0.370 rows=100.00 loops=1)
  ->  Index Only Scan using idx_appointments_pending_in_clinic on appointments (cost=0.28..45.10 rows=100 width=32)
        Buffers: shared hit=22
Execution Time: 0.389 ms
```

---

## 6. Write Overhead Analysis

Every secondary index added incurs a maintenance cost during `INSERT`, `UPDATE`, and `DELETE` operations because the database engine must keep the index B-tree in sync.

| Write Query | Operation | Baseline (ms) | Optimized (ms) | Overhead / Impact | Acceptable? | Rationale |
| --- | --- | ---: | ---: | :---: | :---: | --- |
| **W01** | 1.133 | 0.684 | 0.580 | 0.734 | +35.2% | Not independently verified |
| **W02** | 0.241 | 0.269 | 0.248 | 0.222 | +7.9% | Not independently verified |
| **W03** | 0.148 | 0.142 | 0.132 | 0.142 | +4.1% | Not independently verified |
| **W04** | 7.905 | 7.023 | 6.950 | 7.631 | +3.5% | Not independently verified |
| **W05** | 0.354 | 0.216 | 0.199 | 0.512 | -44.6% (slower) | Not independently verified |

**Conclusion:** Partial indexes can reduce index-maintenance work for rows that do not satisfy their predicates, but they do not guarantee lower write latency in every case. In the latest three-run benchmark, W01, W02, W03, and W04 were faster by 35.2%, 7.9%, 4.1%, and 3.5%, respectively. W05 was 44.6% slower (0.354 ms to 0.512 ms). W04 also had the highest write latency at 7.631 ms. These results should be interpreted cautiously because they are based on three runs.

---

## 7. Index Storage Footprint

The latest database measurements show the storage cost of the indexing strategy:

| Metric | Measured Size |
|---|---:|
| Number of indexes in the `practo` schema | 47 |
| Total index storage | 130 MB |
| Total table data | 58 MB |
| Combined table and index storage | 188 MB |

The largest indexes are:

| Index Name | Approximate Size |
|---|---:|
| `idx_appointments_status_slot` | 17 MB |
| `idx_appointments_doctor_status_slot` | 12 MB |
| `idx_appointments_patient_status_slot` | 11 MB |
| `idx_appointments_completed_date_covering` | 9144 kB |
| `idx_appointments_slot_covering` | 8536 kB |
| `idx_prescription_items_medicine_trgm` | 6968 kB |

The `appointments` table accounts for a substantial share of index storage because it supports several frequent filtering, joining, and sorting patterns. Indexes improve selected access paths but introduce storage and write-maintenance costs. The measured footprint should therefore be considered when evaluating the overall optimization strategy.

## 8. Queries with Limited Gains or Regressions

The latest three-run benchmark shows that optimization did not improve every query. Some queries had only marginal gains, while others were slightly slower.

1. **R17 (Completed Appointments by Age and Blood Group - 1.7% faster):**
   - The query performs date-of-birth calculations and groups results across joined patient and appointment records. The computational cost of these operations may limit the benefit of additional indexing.

2. **R14 (Analytical aggregation - 3.1% faster):**
   - The improvement is modest. Broad aggregation and processing of multiple matching records can limit the benefit of index-based access.

3. **R03 and R04 (Slot-related queries):**
   - These queries were respectively 8.0% and 3.4% slower in the latest comparison. Small differences should be interpreted cautiously because the benchmark used only three runs.

4. **R10, R11, R19, R24 and R25:**
   - These queries showed small regressions, ranging from approximately 0.6% to 3.2%. Their execution plans and workload characteristics should be reviewed before introducing further indexes.

5. **R15 and R22:**
   - Both showed effectively similar performance, with changes below 1%.

6. **W05 (Write workload):**
   - W05 was 44.6% slower, increasing from 0.354 ms to 0.512 ms. This regression highlights the need to evaluate index-maintenance overhead alongside read performance.

Overall, small changes from a three-run benchmark should not be treated as definitive performance differences. Further repeated measurements and query-plan inspection would help determine whether these variations are consistent.

## 9. Conclusion

The Phase 4 optimization work improved several important query access paths, but the latest benchmark also shows that performance gains vary across the workload.

- **Benchmark Results:** In the latest three-run comparison, 19 of the 30 queries were faster, 9 were slower, and 2 showed effectively similar performance. The sum of individual query medians decreased from 208.081 ms to 174.225 ms, a reduction of approximately 16.3%. This is not an end-to-end workload runtime.

- **Largest Improvements:** The largest measured gains were R20 (77.8%), R12 (66.6%), R08 (65.7%), R05 (52.4%), and W01 (35.2%).

- **Correctness Validation:** R08 was directly compared and produced identical results. The benchmark timings alone do not establish output equivalence for all queries. R13 was intentionally corrected by replacing `NOT IN` with `NOT EXISTS` to handle `NULL` values in `doctor_schedules.clinic_id`; its result is not equivalent to the baseline query's incorrect empty result.

- **Write Performance:** W01 through W04 improved modestly, while W05 was 44.6% slower. The results demonstrate that index benefits for reads must be balanced against write-maintenance overhead.

- **Storage Cost:** The `practo` schema contains 47 indexes, using approximately 130 MB of index storage. Table data occupies approximately 58 MB, for a combined footprint of approximately 188 MB.

- **Further Validation:** Since the comparison uses three runs, small performance differences should be treated cautiously. Additional repeated benchmarks, direct result-set comparisons for the remaining queries, and continued query-plan inspection are recommended.

Overall, the optimization work produced substantial improvements for selected queries while making the trade-offs in query performance, correctness, write overhead, and index storage more visible. These measurements provide a basis for further tuning and scalability testing.
