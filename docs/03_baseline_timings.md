# 03. Baseline Query Performance Analysis

## 1. Overview

This document records the baseline performance measurements of the Practo Doctor Appointments database.

The purpose of baseline benchmarking is to measure query execution performance before applying further query optimizations. These measurements provide a reference for comparing database performance after optimization.

## 2. Benchmark Environment

| Parameter | Value |
|---|---|
| Database | practo_db |
| Schema | practo |
| DBMS | PostgreSQL 15+ |
| Workload file | queries/workload_30.sql |
| Total queries | 30 |
| Read queries | 25 |
| Write queries | 5 |
| Runs per query | 3 |
| Query analysis | EXPLAIN (ANALYZE, BUFFERS) |
| Benchmark phase | baseline (before) |

Write queries are executed inside transactions and rolled back to avoid permanently modifying the database during benchmarking.

## 3. Baseline Benchmark Results

Execution times are measured in milliseconds (ms).

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Find a doctor: verified dermatologists practising in Bengaluru, most experienced first | READ | 2.971 | 2.111 | 1.789 | 2.290 |
| R02: Doctor profile: doctor 217's weekly timetable with clinic names | READ | 0.287 | 0.280 | 0.257 | 0.275 |
| R03: Slot picker: doctor 217's free in-clinic slots on Friday 3 July 2026 | READ | 0.452 | 0.237 | 0.220 | 0.303 |
| R04: "My appointments": patient 90's upcoming appointments | READ | 0.166 | 0.103 | 0.100 | 0.123 |
| R05: Doctor's queue: doctor 16's appointments on 30 June 2026 | READ | 0.672 | 0.265 | 0.285 | 0.407 |
| R06: Sign-in with mobile number | READ | 2.190 | 1.877 | 1.808 | 1.958 |
| R07: Prescription view: the prescription and medicines of appointment 18872 | READ | 0.099 | 0.052 | 0.047 | 0.066 |
| R08: Quality: no-show rate per specialization in 2026 | READ | 24.002 | 20.823 | 20.681 | 21.835 |
| R09: Clinic experience: average minutes patients waited after their slot time, per clinic (June 2026) | READ | 2.593 | 2.473 | 2.414 | 2.493 |
| R10: Patient safety: patients allergic to penicillin who were prescribed amoxicillin | READ | 18.900 | 16.558 | 16.829 | 17.429 |
| R11: Care team: follow-ups due in the first week of July 2026 that the patient has not booked yet | READ | 1.719 | 1.245 | 1.120 | 1.361 |
| R12: Product analytics: video vs in-clinic appointments per month in 2026 | READ | 23.140 | 23.004 | 23.336 | 23.160 |
| R13: Clinic partnerships: clinics where no doctor has any schedule | READ | 2.632 | 2.614 | 2.712 | 2.653 |
| R14: Doctor ranking: average rating and recommendation rate (at least 10 reviews) | READ | 19.041 | 18.575 | 18.621 | 18.746 |
| R15: Pharmacy partners: most prescribed medicines per primary specialization in June 2026 | READ | 23.271 | 21.543 | 21.035 | 21.950 |
| R16: Finance: fees collected per clinic in June 2026 | READ | 2.611 | 2.495 | 2.528 | 2.545 |
| R17: Population health: completed appointments by patient age group and blood group (2026) | READ | 35.132 | 34.286 | 34.330 | 34.583 |
| R18: Search filter: Tamil-speaking doctors with Chennai clinics | READ | 3.983 | 3.730 | 3.650 | 3.788 |
| R19: City report: June 2026 completed consultations and latest consultation of every doctor with a Bengaluru clinic | READ | 13.783 | 13.325 | 12.684 | 13.264 |
| R20: Platform analytics: completed appointments per day and running total, June 2026 | READ | 6.658 | 4.852 | 5.052 | 5.521 |
| R21: Finance: completed in-clinic consultations whose fee is still unpaid | READ | 0.570 | 0.423 | 0.404 | 0.466 |
| R22: Support console: all appointments, newest first, page 4,001 (25 per page) | READ | 7.059 | 6.228 | 6.164 | 6.484 |
| R23: Verification team: look up a doctor by medical council registration number | READ | 0.041 | 0.027 | 0.026 | 0.031 |
| R24: Data quality: two active appointments of the same doctor in the same slot (double bookings) | READ | 21.824 | 21.983 | 22.045 | 21.951 |
| R25: Care quality: patients who saw 3 or more different doctors of the same specialization in 2026 | READ | 13.828 | 14.277 | 13.984 | 14.030 |
| W01: Book: patient 90 books doctor 217's 10:30 slot on Friday 3 July 2026 | WRITE | 0.892 | 0.599 | 0.562 | 0.684 |
| W02: Reception: check in the earliest BOOKED in-clinic appointment of 1 July 2026 | WRITE | 0.399 | 0.224 | 0.184 | 0.269 |
| W03: Doctor: add notes and a follow-up date to the prescription of appointment 18872 | WRITE | 0.155 | 0.138 | 0.134 | 0.142 |
| W04: Nightly job (run at 00:00 on 2 July 2026): BOOKED appointments whose slot has ended become NO_SHOW | WRITE | 13.733 | 3.193 | 4.142 | 7.023 |
| W05: Doctor on leave: cancel and refund all of doctor 504's appointments on 3 July 2026 | WRITE | 0.239 | 0.204 | 0.204 | 0.216 |
| **Total (sum of all 30)** | | 243.042 | 217.744 | 217.347 | 226.044 |

## 4. Query Execution Plan Observations & Scan Types

The benchmark records execution plans and scan operations for each query.

### 4.1 Scan Summary
1. **Sequential scans:** Queries R08, R10, R12, R14, R15, R17, R18, R19, and R24 contain sequential scans on one or more large tables (such as `appointments`, `patients`, `doctor_reviews`, and `prescription_items`), contributing to their higher latencies.
2. **Index scans:** Several queries use indexes, including R07, R09, R11, R20, R21, R22, and R23.
3. **Bitmap scans:** Queries R01, R03, R04, R05, R13, and R19 use bitmap scans for selective filtering.
4. **Index-only scans:** Queries R17, R20, R22, and R25 use index-only scans for at least one table access.
5. **Write operations:** W01, W02, W03, and W05 have fast execution times (< 1 ms), while W04 has a higher initial execution time (13.733 ms in Run 1, settling to ~3-4 ms) due to scanning booked status records.

### 4.2 Per-Query Primary Scan Type and Performance Notes
- **R01**: Bitmap Scan on clinics / Seq Scan on specializations — moderate time (2.290 ms) filtering dermatologists across Bengaluru clinics.
- **R02**: Index Scan on `doctor_schedules` — fast (0.275 ms) due to indexed `doctor_id`.
- **R03**: Bitmap Index Scan on `appointments` — fast (0.303 ms) checking doctor schedule slots against booked appointments.
- **R04**: Bitmap Index Scan on `idx_appointments_patient_slot` — fast (0.123 ms) for patient appointment lookup.
- **R05**: Bitmap Index Scan on `idx_appointments_doctor_slot` — fast (0.407 ms) retrieving queue for single doctor and date.
- **R06**: Seq Scan on `patients` — 1.958 ms scanning 40,000 patient records by unindexed mobile number.
- **R07**: Index Scan on `prescriptions` and `prescription_items` — extremely fast (0.066 ms) using primary key lookups.
- **R08**: Seq Scan on `appointments` (150,000 rows) — slow (21.835 ms) computing no-show rates across all appointments in 2026.
- **R09**: Index Scan using `idx_appointments_slot_covering` — fast (2.493 ms) calculating average wait times.
- **R10**: Seq Scan on `appointments` and `patients` — slow (17.429 ms) joining patient allergies with prescription items without dedicated allergy index.
- **R11**: Index Scan on `prescriptions` and `appointments` — fast (1.361 ms) finding unbooked follow-ups.
- **R12**: Seq Scan on `appointments` — slow (23.160 ms) full table aggregation grouping monthly video vs in-clinic visits.
- **R13**: Seq Scan on `clinics` and `doctor_schedules` — 2.653 ms anti-join finding clinics without schedules.
- **R14**: Seq Scan on `appointments` and `doctor_reviews` — slow (18.746 ms) aggregating 30,000 reviews with appointment joins.
- **R15**: Seq Scan on `appointments`, `prescriptions`, `prescription_items` — slow (21.950 ms) multi-table join across quarter-million prescription items.
- **R16**: Index Scan on `appointments` — 2.545 ms summing fees per clinic.
- **R17**: Index Only Scan on `appointments` + Seq Scan on `patients` — slowest query (34.583 ms) grouping completed visits by age and blood group.
- **R18**: Seq Scan on `doctor_schedules` and `doctors` — 3.788 ms filtering array column `languages` with ANY.
- **R19**: Seq Scan on `doctor_schedules` and `doctors` + Bitmap Scan on `appointments` — 13.264 ms aggregating Bengaluru consultations.
- **R20**: Index Only Scan using `idx_appointments_completed_slot_patient` — 5.521 ms calculating daily running total.
- **R21**: Index Scan on `appointments` — fast (0.466 ms) filtering unpaid completed consultations.
- **R22**: Index Only Scan on `appointments` — 6.484 ms for deep offset pagination (`OFFSET 100000 LIMIT 25`).
- **R23**: Index Scan using `idx_doctors_registration_unique` — sub-millisecond (0.031 ms) unique registration lookup.
- **R24**: Seq Scan on `appointments` — slow (21.951 ms) self-joining 150,000 appointments to detect slot double bookings.
- **R25**: Index Only Scan on `appointments` + Seq Scan on `doctor_specializations` — slow (14.030 ms) grouping patients seeing ≥3 doctors.
- **W01**: Index Scan on `doctor_schedules` and `doctors` — fast (0.684 ms) insert inside rollback transaction.
- **W02**: Index Scan on `appointments` — fast (0.269 ms) status check-in update inside rollback.
- **W03**: Index Scan on `prescriptions` — fast (0.142 ms) prescription update inside rollback.
- **W04**: Bitmap Heap Scan on `appointments` — 7.023 ms updating expired booked appointments to NO_SHOW.
- **W05**: Index Scan on `appointments` — fast (0.216 ms) batch cancellation update for single doctor inside rollback.

## 5. Queries Requiring Further Investigation

Based on average execution time, the following read queries are among the slower queries in the baseline:

- **R17**: 34.583 ms (Population health: completed appointments by patient age and blood group)
- **R12**: 23.160 ms (Product analytics: video vs in-clinic appointments per month)
- **R24**: 21.951 ms (Data quality: double bookings check)
- **R15**: 21.950 ms (Pharmacy partners: most prescribed medicines per specialization)
- **R08**: 21.835 ms (Quality: no-show rate per specialization)
- **R14**: 18.746 ms (Doctor ranking: average rating and recommendation rate)
- **R10**: 17.429 ms (Patient safety: penicillin allergy vs amoxicillin prescriptions)
- **R25**: 14.030 ms (Care quality: patients seeing multiple doctors of same specialization)
- **R19**: 13.264 ms (City report: Bengaluru completed consultations)

These queries should be examined further using their execution plans to identify possible optimization opportunities in Phase 4.

Write query **W04** also deserves attention because its average execution time is 7.023 ms (with Run 1 taking 13.733 ms before index/buffer cache warmup).

## 6. Benchmark Methodology

The benchmark was executed using:

```bash
bash benchmarks/run_benchmark.sh practo_db baseline 3
```

The script:

- Splits the workload file (`queries/workload_30.sql`) into individual queries using query markers (`-- @R1`, `-- @W1`, etc.).
- Executes each query three times (`RUNS=3`).
- Uses `EXPLAIN (ANALYZE, BUFFERS)` to inspect execution plans.
- Records execution times and scan-node information.
- Saves individual query plans (`R01.txt` ... `W05.txt`) and a consolidated `summary.csv` file.

The results are stored in `benchmarks/results/baseline/` (and mirrored in `benchmarks/results/before/`).

The summary file contains 31 lines: one header and 30 query records.

## 7. Conclusion

The baseline benchmark establishes a performance reference for all 30 workload queries.

The results show that query execution times vary significantly:
- Several indexed point-lookups (such as R02, R04, R07, R23, W02, W03, W05) execute in well under 1 millisecond.
- Highly aggregated queries and analytical queries requiring sequential scans across large tables (such as R17, R12, R24, R15, R08, R14, R10, R25, R19) take between 13 ms and 35 ms.
- The total workload execution time across all 30 queries averages 226.044 ms (Run 1: 243.042 ms, Run 2: 217.744 ms, Run 3: 217.347 ms).

The execution plans provide actionable information about sequential scans, index scans, bitmap scans, and index-only scans, establishing clear targets for index tuning and query optimization in Phase 4.
