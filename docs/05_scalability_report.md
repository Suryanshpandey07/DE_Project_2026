# 05. Scalability Report (Large Dataset Round)

**Team:** T0135 · **Phase 5 / Checkpoint 4** · **Files:** `docs/05_scalability_report.md`, `sql/08_partitioning.sql`, `benchmarks/results/large/`

> **Status of this report.** Sections 5 (architecture for 100×) and the partitioning code in `sql/08_partitioning.sql` are complete and were tested on the seed data.
> Every cell marked **⏳** must be filled from the large-dataset run (Section 1). Those numbers come only from `benchmarks/results/large/summary.csv`. Nothing in this report is an estimate presented as a measurement.

---

## 1. How the large-dataset run is done

| Step | Command | Notes |
|---|---|---|
| 1. New database | `createdb practo_large` then `psql -d practo_large -c "CREATE SCHEMA practo"` | Same laptop as Phase 3/4 (MacBook Pro M4, PostgreSQL 18.6) |
| 2. Schema | `PGOPTIONS='-c search_path=practo' psql -d practo_large -v ON_ERROR_STOP=1 -f sql/01_schema.sql` | Our unchanged Phase 2 schema |
| 3. Load | Unzip `large_data.zip` to `large_data/`, then run `sql/02_load_data.sql` with `seed_data/` replaced by `large_data/` (folder name is the only change): `sed 's#seed_data/#large_data/#' sql/02_load_data.sql \| PGOPTIONS='-c search_path=practo' psql -d practo_large -v ON_ERROR_STOP=1` | `large_data/` is in `.gitignore`; CSVs are never committed |
| 4. Indexes + stats | `psql -d practo_large -v ON_ERROR_STOP=1 -f sql/05_indexes.sql` (ends with `ANALYZE`), then `psql -d practo_large -c "VACUUM (ANALYZE) practo.appointments"` | VACUUM sets the visibility map so Index Only Scans really skip the heap |
| 5. Benchmark | `./benchmarks/run_benchmark.sh practo_large large 3 sql/06_optimized_queries.sql` | **Optimized queries only.** The original 30 are not run on the large data |
| 6. Partitioning demo | `psql -d practo_large -v ON_ERROR_STOP=1 -f sql/08_partitioning.sql > benchmarks/results/large/08_partitioning_output.txt` | Plans for Section 5.1 |

**Row counts after loading** (verify against the faculty figures):

```sql
SELECT 'appointments' t, count(*) FROM practo.appointments UNION ALL
SELECT 'prescriptions', count(*) FROM practo.prescriptions UNION ALL
SELECT 'prescription_items', count(*) FROM practo.prescription_items UNION ALL
SELECT 'patients', count(*) FROM practo.patients UNION ALL
SELECT 'doctor_schedules', count(*) FROM practo.doctor_schedules UNION ALL
SELECT 'doctors', count(*) FROM practo.doctors;
```

| Table | Seed rows | Expected large rows | Measured large rows |
|---|---:|---:|---:|
| appointments | 150,000 | ≈ 3,000,000 | ⏳ |
| prescriptions | 97,234 | ≈ 1,945,000 | ⏳ |
| prescription_items | 243,085 | ≈ 4,862,000 | ⏳ |
| patients | 40,000 | ≈ 800,000 | ⏳ |
| doctor_schedules | 30,499 | ≈ 610,000 | ⏳ |
| doctors | 3,000 | (not stated) | ⏳ |

### 1.1 Fix needed before the run: R13 still uses `NOT IN`

While preparing this phase we re-ran R13 from `sql/06_optimized_queries.sql` against the seed data. The file still contains the original `NOT IN` version:

| Version of R13 | Rows returned (seed) |
|---|---:|
| `WHERE c.clinic_id NOT IN (SELECT sc.clinic_id FROM doctor_schedules sc)` (currently in `06`) | **0** |
| `WHERE NOT EXISTS (SELECT 1 FROM doctor_schedules sc WHERE sc.clinic_id = c.clinic_id)` | **292** |

`doctor_schedules.clinic_id` is NULL for video schedules, so `x NOT IN (…, NULL)` is never TRUE and the query always returns nothing. `04_optimization_report.md` describes the `NOT EXISTS` fix, but the file was not updated. It must be updated **before** step 5, for two reasons:

1. **Correctness:** the large run would otherwise time a wrong answer.
2. **Scale:** with `NOT IN`, PostgreSQL can only use a *hashed* subplan if the whole subquery result fits in `work_mem` (default 4 MB). At ≈ 610,000 schedule rows it no longer fits, and the plan falls back to a plain subplan that re-scans the materialized list for **every clinic** (clinics × schedules comparisons). That is a query that is fast on seed and can run for minutes at 20×. `NOT EXISTS` becomes a Hash Anti Join, which grows linearly.

---

## 2. Results table

Seed column = `avg_ms` from `benchmarks/results/optimized/summary.csv` (Phase 4). Large column = `avg_ms` from `benchmarks/results/large/summary.csv`.
Growth = large ÷ seed.

> ⚠️ The seed numbers in `optimized/summary.csv` (sum 749 ms) are much higher than the "After" column in `04_optimization_report.md` (sum 174 ms) and `after/summary.csv` (sum 225 ms). For a fair growth ratio, re-run the seed benchmark right before the large one, on the same laptop:
> `./benchmarks/run_benchmark.sh practo_db optimized 3 sql/06_optimized_queries.sql`

| Query | Group | Target | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what we changed |
|---|---|---:|---:|---:|---:|:---:|---|
| R01 | Interactive | < 250 | 3.396 | ⏳ | ⏳ | ⏳ | |
| R02 | Real-time | < 5 | 0.582 | ⏳ | ⏳ | ⏳ | |
| R03 | Real-time | < 5 | 0.230 | ⏳ | ⏳ | ⏳ | |
| R04 | Real-time | < 5 | 0.186 | ⏳ | ⏳ | ⏳ | |
| R05 | Real-time | < 5 | 0.147 | ⏳ | ⏳ | ⏳ | |
| R06 | Real-time | < 5 | 0.081 | ⏳ | ⏳ | ⏳ | |
| R07 | Real-time | < 5 | 0.151 | ⏳ | ⏳ | ⏳ | |
| R08 | Report | < 5,000 | 89.969 | ⏳ | ⏳ | ⏳ | |
| R09 | Report | < 5,000 | 6.979 | ⏳ | ⏳ | ⏳ | |
| R10 | Report | < 5,000 | 64.452 | ⏳ | ⏳ | ⏳ | |
| R11 | Interactive | < 250 | 4.768 | ⏳ | ⏳ | ⏳ | |
| R12 | Report | < 5,000 | 26.398 | ⏳ | ⏳ | ⏳ | |
| R13 | Interactive | < 250 | 11.080 | ⏳ | ⏳ | ⏳ | `NOT IN` → `NOT EXISTS` (Section 1.1) |
| R14 | Report | < 5,000 | 64.195 | ⏳ | ⏳ | ⏳ | |
| R15 | Report | < 5,000 | 86.890 | ⏳ | ⏳ | ⏳ | |
| R16 | Report | < 5,000 | 7.857 | ⏳ | ⏳ | ⏳ | |
| R17 | Report | < 5,000 | 94.229 | ⏳ | ⏳ | ⏳ | |
| R18 | Interactive | < 250 | 10.414 | ⏳ | ⏳ | ⏳ | |
| R19 | Report | < 5,000 | 18.825 | ⏳ | ⏳ | ⏳ | |
| R20 | Report | < 5,000 | 3.727 | ⏳ | ⏳ | ⏳ | |
| R21 | Interactive | < 250 | 0.707 | ⏳ | ⏳ | ⏳ | |
| R22 | Interactive | < 250 | 20.816 | ⏳ | ⏳ | ⏳ | |
| R23 | Real-time | < 5 | 0.065 | ⏳ | ⏳ | ⏳ | |
| R24 | Report | < 5,000 | 116.331 | ⏳ | ⏳ | ⏳ | |
| R25 | Report | < 5,000 | 82.293 | ⏳ | ⏳ | ⏳ | |
| W01 | Real-time | < 5 | 1.882 | ⏳ | ⏳ | ⏳ | |
| W02 | Real-time | < 5 | 0.687 | ⏳ | ⏳ | ⏳ | |
| W03 | Real-time | < 5 | 0.374 | ⏳ | ⏳ | ⏳ | |
| W04 | Batch | < 1,000 | 30.687 | ⏳ | ⏳ | ⏳ | |
| W05 | Interactive | < 250 | 0.965 | ⏳ | ⏳ | ⏳ | |
| **Total** | | | **749.363** | ⏳ | ⏳ | | |

**Generating the filled rows.** After step 5, this prints every row of the table with growth and target check, ready to paste over the rows above:

```bash
awk -F, '
  BEGIN { split("R02 R03 R04 R05 R06 R07 R23 W01 W02 W03", a, " "); for (i in a) tg[a[i]] = 5
          split("R01 R11 R13 R18 R21 R22 W05", b, " ");             for (i in b) tg[b[i]] = 250
          split("R08 R09 R10 R12 R14 R15 R16 R17 R19 R20 R24 R25", c, " "); for (i in c) tg[c[i]] = 5000
          tg["W04"] = 1000 }
  FNR == 1 { next }
  NR == FNR { seed[$1] = $3; next }
  { ok = ($3 < tg[$1]) ? "✅" : "❌"
    printf "| %s | %.3f | %.3f | %.1f× | %s (< %d ms) | |\n", $1, seed[$1], $3, $3 / seed[$1], ok, tg[$1] }
' benchmarks/results/optimized/summary.csv benchmarks/results/large/summary.csv
```

### 2.1 R22 and `OFFSET`

R22 still pages with `OFFSET 100000 LIMIT 25` (we kept the original semantics in Phase 4). The cost of `OFFSET` depends on the **offset**, not on the table size: PostgreSQL walks 100,025 entries of `idx_appointments_slot_covering` and discards the first 100,000. On 3 M rows the offset is still 100,000, so R22 should stay roughly flat (only the B-tree is one level deeper).

The real problem is *deeper pages*: page 40,000 at 20× would walk 1 M entries. The scalable version is **keyset pagination**:

```sql
-- page N+1: the app passes the (slot_start, appointment_id) of the LAST row it showed on page N
SELECT appointment_id, patient_id, doctor_id, status, slot_start
FROM appointments
WHERE (slot_start, appointment_id) < (:last_slot_start, :last_appointment_id)
ORDER BY slot_start DESC, appointment_id DESC
LIMIT 25;
```

- **How the "last seen" value is chosen:** it is never computed by the database. The support console keeps the `(slot_start, appointment_id)` of the 25th row of the page it just rendered and sends it with the "next page" request. `appointment_id` is added as a tie-breaker because many appointments share a `slot_start`; without it, rows with the same slot time could be skipped or shown twice.
- **To reproduce page 4,001 exactly in a benchmark**, the boundary row is looked up once: `SELECT slot_start, appointment_id FROM appointments ORDER BY slot_start DESC, appointment_id DESC OFFSET 99999 LIMIT 1;` and its values are pasted into the keyset query.
- Cost: one index descent + 25 entries, i.e. O(log n) at any page depth. It needs an index on `(slot_start DESC, appointment_id DESC)`.
- Trade-off: the console can no longer jump straight to "page 4,001"; it can only go next/previous. For a support console that is acceptable.

---

## 3. Growth analysis

The data grows ≈ 20×. How a query's time grows depends on **how many rows it must touch**, not on how big the table is. The groups below are our *expectation from the seed plans*. The "Measured growth" column confirms or refutes each one.

### 3.1 Expected to stay about the same (≈ 1–2×)

| Query | Seed plan | Why it should not grow | Measured growth |
|---|---|---|---:|
| R02, R03, R05, W01 | Index Scan on `idx_doctor_schedules_doctor` / `idx_appointments_active_doctor_slot` / `idx_appointments_doctor_slot` | One doctor's schedule or one doctor-day. B-tree depth grows with log n (≈ 3 → 4 levels); rows returned stay ≈ the same | ⏳ |
| R04 | Index Only Scan `idx_appointments_patient_status_slot` | One patient's BOOKED appointments. Patients also grow 20×, so appointments *per patient* stay the same | ⏳ |
| R06, R23 | Index Scan on `idx_patients_phone` / `idx_doctors_registration_unique` | Unique point lookup: log n | ⏳ |
| R07, W03 | Index Scan `idx_prescriptions_appointment` + PK of `prescription_items` | One prescription, ≈ 2.5 items | ⏳ |
| R21 | Index Only Scan `idx_appointments_pending_in_clinic` | `LIMIT 100` from a partial index already in the right order: stops after 100 entries | ⏳ |
| R22 | Index Only Scan `idx_appointments_slot_covering` | Fixed `OFFSET 100000` (Section 2.1) | ⏳ |
| W02 | Index Only Scan `idx_appointments_booked_slot` + `LIMIT 1` | First BOOKED row of the day from a small partial index | ⏳ |
| W05 | Index Scan `idx_appointments_booked_slot` | One doctor-day | ⏳ |

### 3.2 Expected to grow about 20×

These read a **fixed share** of a table (a month, a year, all reviews), and that share is 20× bigger.

| Query | What it reads | Measured growth |
|---|---|---:|
| R08, R12, R17, R25 | All 2026 appointments (≈ 1/3 of the table) | ⏳ |
| R09, R16, R20 | June 2026 appointments | ⏳ |
| R14 | All reviews joined to appointments | ⏳ |
| R15 | June prescriptions → items | ⏳ |
| R10 | All amoxicillin items of penicillin-allergic patients | ⏳ |
| R11 | Follow-ups due in one week (20× more prescriptions per week) | ⏳ |
| R13, R18, R19 | Whole `doctor_schedules` (610 k rows) | ⏳ |
| R01 | Dermatologists with a Bengaluru clinic (if `doctors` also grows 20×) | ⏳ |
| R24 | All non-cancelled appointments, self-joined | ⏳ |
| W04 | Every expired BOOKED/CHECKED_IN appointment; each update maintains every `appointments` index | ⏳ |

### 3.3 Could grow more than 20× (watch list)

A query grows *faster* than the data when an operation that fitted in memory on seed stops fitting at scale, or when its work is quadratic:

| Query | Risk at 3 M rows | What to look for in the plan | Measured growth |
|---|---|---|---:|
| R13 (if `NOT IN` is kept) | Hashed subplan no longer fits `work_mem` → plain subplan, clinics × schedules | `SubPlan` without `hashed` | ⏳ |
| R24 | Hash join of 3 M × 3 M rows spills to disk | `Batches: N` (N > 1) on the Hash node, `temp read/written` in Buffers | ⏳ |
| R25 | `count(DISTINCT doctor_id)` sorts per group; 1 M+ rows sort externally | `Sort Method: external merge  Disk: …` | ⏳ |
| R15, R10 | Hash join on `prescription_items` (4.9 M rows) spills | `Batches` > 1, temp buffers | ⏳ |
| R17 | Join of ≈ 1 M completed 2026 appointments to 800 k patients | Hash `Batches` > 1 | ⏳ |
| R19 | One correlated `max(consult_ended_at)` sub-query **per Bengaluru doctor** | `SubPlan` loops = number of doctors | ⏳ |

---

## 4. What broke at scale and how we fixed it

For every query marked ❌ in Section 2, add one subsection: plan **before** (from `benchmarks/results/large/<ID>.txt`), the fix, plan **after**, and the result check. The fixes below are ready to use. Each was tested on the seed data and returns **exactly the same rows** as the query it replaces (`EXCEPT ALL` in both directions = 0 rows).

### 4.1 R13: `NOT IN` → `NOT EXISTS` (required: correctness)

```sql
SELECT c.clinic_id, c.clinic_name, c.city_id
FROM clinics c
WHERE NOT EXISTS (SELECT 1 FROM doctor_schedules sc WHERE sc.clinic_id = c.clinic_id);
```
Uses `idx_doctor_schedules_clinic`; plan becomes a Hash/Merge Anti Join. Seed result: 292 rows (the `NOT IN` version: 0).

| | Plan (large) | Time (large) |
|---|---|---:|
| Before | ⏳ | ⏳ |
| After | ⏳ | ⏳ |

### 4.2 R24: find duplicate slots first, then pair them (if it misses 5 s)

The original self-joins *every* non-cancelled appointment to every other one of the same doctor and slot. Only a few hundred slots are actually double-booked (559 pairs on seed). Grouping first lets PostgreSQL read `idx_appointments_active_doctor_slot` `(doctor_id, slot_start, appointment_id) WHERE status <> 'CANCELLED'` in order (no hash table at all), and the join then touches only the duplicate slots.

```sql
WITH dup AS (
    SELECT doctor_id, slot_start
    FROM appointments
    WHERE status <> 'CANCELLED'
    GROUP BY doctor_id, slot_start
    HAVING count(*) > 1
)
SELECT a.doctor_id, a.slot_start, a.appointment_id,
       b.appointment_id AS other_appointment_id
FROM dup d
JOIN appointments a ON a.doctor_id = d.doctor_id AND a.slot_start = d.slot_start
                   AND a.status <> 'CANCELLED'
JOIN appointments b ON b.doctor_id = d.doctor_id AND b.slot_start = d.slot_start
                   AND b.status <> 'CANCELLED' AND b.appointment_id > a.appointment_id
ORDER BY a.slot_start DESC;
```
Seed check: 559 rows, identical to the original.

| | Plan (large) | Time (large) |
|---|---|---:|
| Before | ⏳ | ⏳ |
| After | ⏳ | ⏳ |

### 4.3 R19: one grouped pass instead of two sub-queries per doctor

```sql
WITH blr AS (
    SELECT DISTINCT sc.doctor_id
    FROM doctor_schedules sc
    JOIN clinics c ON c.clinic_id = sc.clinic_id
    WHERE c.city_id = 1
),
stats AS (
    SELECT a.doctor_id,
           count(*) FILTER (WHERE a.status = 'COMPLETED'
                              AND a.slot_start >= '2026-06-01'
                              AND a.slot_start <  '2026-07-01') AS june_consults,
           max(a.consult_ended_at) AS last_consult_at
    FROM appointments a
    JOIN blr USING (doctor_id)
    GROUP BY a.doctor_id
)
SELECT d.doctor_id, d.full_name,
       coalesce(s.june_consults, 0) AS june_consults, s.last_consult_at
FROM blr
JOIN doctors d USING (doctor_id)
LEFT JOIN stats s USING (doctor_id)
ORDER BY june_consults DESC;
```
Seed check: 480 rows, identical to the original (`coalesce` keeps the `count(*) = 0` of doctors without appointments, `LEFT JOIN` keeps their NULL `last_consult_at`).

| | Plan (large) | Time (large) |
|---|---|---:|
| Before | ⏳ | ⏳ |
| After | ⏳ | ⏳ |

### 4.4 Heavy yearly reports (R17, R25, R14): summary table, if needed

If a yearly report is still over 5 s, it does not need live data (P6/P7 are reporting teams). A materialized view computed once per night removes the work from the query path:

```sql
CREATE MATERIALIZED VIEW practo.mv_doctor_rating AS
SELECT a.doctor_id, round(avg(r.rating), 2) AS avg_rating,
       round(100.0 * count(*) FILTER (WHERE r.recommends) / count(*), 1) AS recommend_pct,
       count(*) AS reviews
FROM practo.doctor_reviews r
JOIN practo.appointments a ON a.appointment_id = r.appointment_id
GROUP BY a.doctor_id;
CREATE UNIQUE INDEX ON practo.mv_doctor_rating (doctor_id);   -- needed for CONCURRENTLY
-- nightly, after W04:  REFRESH MATERIALIZED VIEW CONCURRENTLY practo.mv_doctor_rating;
```
R14 then becomes `SELECT … FROM mv_doctor_rating WHERE reviews >= 10 ORDER BY avg_rating DESC, reviews DESC LIMIT 20` (a scan of one row per doctor). Results are up to one day old, which must be stated on the report screen.

### 4.5 Things to rule out before changing SQL

- **Stale statistics / visibility map:** if a plan shows `Heap Fetches` in the hundreds of thousands on an Index Only Scan, run `VACUUM (ANALYZE) practo.appointments;` and re-measure (step 4 in Section 1).
- **Estimated vs actual rows:** a 100× mismatch on a node means stale or too-coarse statistics; `ALTER TABLE … ALTER COLUMN status SET STATISTICS 1000; ANALYZE;`.
- **We do not raise `work_mem` or disable plan types** (not allowed by the project rules); the fixes above change the query or the access path instead.

---

## 5. Storage

### 5.1 Seed vs large

Seed figures are from Phase 4 (`04_optimization_report.md`, Section 7). Large figures come from:

```sql
SELECT pg_size_pretty(pg_database_size(current_database())) AS database_size;

SELECT relname,
       pg_size_pretty(pg_relation_size(c.oid))       AS table_size,
       pg_size_pretty(pg_indexes_size(c.oid))        AS index_size,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
       round(pg_indexes_size(c.oid)::numeric / nullif(pg_relation_size(c.oid), 0), 2) AS index_to_table
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'practo' AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;
```

| Metric | Seed | Large | Growth |
|---|---:|---:|---:|
| Table data (schema `practo`) | 58 MB | ⏳ | ⏳ |
| Index storage (47 indexes) | 130 MB | ⏳ | ⏳ |
| Total | 188 MB | ⏳ | ⏳ |
| Largest index: `idx_appointments_status_slot` | 17 MB | ⏳ | ⏳ |

**Observation.** On seed, indexes are **2.2×** the size of the data. Most of that is the wide `INCLUDE` lists on `appointments` (`idx_appointments_status_slot` alone carries 10 columns). At 20× (≈ 1.2 GB tables + 2.6 GB indexes, expected) the working set is still far below the laptop's RAM. At 100× it is not, and every extra index is also paid on each `W01`/`W02`/`W04`/`W05` write. Before going to 100× we would drop indexes that no query uses (`SELECT indexrelname, idx_scan FROM pg_stat_user_indexes WHERE schemaname = 'practo' ORDER BY idx_scan;` after the benchmark).

### 5.2 Partition sizes (seed, from `sql/08_partitioning.sql`)

When we tested `08_partitioning.sql` on the seed data, each full month was ≈ 8,000–8,700 rows and ≈ 1.2 MB of table + ≈ 3.5 MB of indexes (≈ 4.7 MB total). At 20× that is ≈ 170 k rows / ≈ 95 MB per month; at 100× ≈ 850 k rows / ≈ 470 MB per month: still small enough to VACUUM in seconds and to back up or detach as one unit.

---

## 6. Architecture for 100× (≈ 15 M appointments, ≈ 24 M prescription items)

### 6.1 Partitioning

| Decision | Choice | Reason |
|---|---|---|
| Table | `appointments` (then `prescriptions`, `prescription_items`) | Largest and fastest-growing table; read or written by 22 of the 30 queries |
| Column | `slot_start` | 12 queries filter on a `slot_start` day/month/year range (R05, R08, R09, R12, R16, R17, R19, R20, R25, W02, W05; R03 on one slot), and R22 sorts by it |
| Method | **RANGE, one partition per month** | Data arrives in time order; past months stop changing; a month is the unit for archiving and for most reports. LIST does not fit a timestamp. HASH would spread every date range across *all* partitions, so nothing is pruned |
| Size | ≈ 850 k rows / month at 100× | Small B-trees per partition, fast VACUUM, and few enough partitions (≈ 36 for 3 years) that queries without a date filter stay cheap |

**DDL** (full version, with indexes, data copy and checks, in `sql/08_partitioning.sql`):

```sql
CREATE TABLE appointments_part (
    appointment_id BIGINT NOT NULL,
    patient_id     INTEGER NOT NULL REFERENCES patients(patient_id),
    doctor_id      INTEGER NOT NULL REFERENCES doctors(doctor_id),
    clinic_id      INTEGER REFERENCES clinics(clinic_id),
    -- … all other columns as in appointments …
    slot_start     TIMESTAMPTZ NOT NULL,
    slot_end       TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (appointment_id, slot_start)          -- must contain the partition key
) PARTITION BY RANGE (slot_start);

CREATE TABLE appointments_2026_06 PARTITION OF appointments_part
    FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');
-- … one per month, created by a DO loop / create_appointments_partition() …
CREATE TABLE appointments_default PARTITION OF appointments_part DEFAULT;
```

**Primary-key rule.** A PRIMARY KEY or UNIQUE constraint on a partitioned table must include all partition-key columns, because each partition enforces uniqueness only for its own rows. So the key is `(appointment_id, slot_start)`. Two consequences:

1. The database no longer enforces "`appointment_id` alone is unique". It still is in practice (one sequence), and `08_partitioning.sql` checks it (`duplicate_appointment_ids = 0`).
2. `prescriptions` and `doctor_reviews` reference `appointments(appointment_id)`, which is no longer a unique key. We add `appt_slot_start` to both tables and use a composite foreign key `(appointment_id, appt_slot_start) → appointments(appointment_id, slot_start)`. The cut-over script is section F of `08_partitioning.sql`; we tested it on the seed data inside a transaction (all 97,234 prescriptions still join to their appointment).

**Partition pruning on the seed data** (output of `08_partitioning.sql`, section D):

R05, doctor's queue for one day. Only the June 2026 partition is touched (5 buffers):
```text
Sort (actual time=0.018..0.018 rows=3 loops=1)
  Sort Key: a.slot_start
  Buffers: shared hit=5
  ->  Index Scan using appointments_2026_06_doctor_id_status_slot_start_patient_id_idx on appointments_2026_06 a
        Index Cond: ((doctor_id = 16) AND (slot_start >= '2026-06-30 00:00:00+05:30') AND (slot_start < '2026-07-01 00:00:00+05:30'))
        Buffers: shared hit=5
```

R12, video vs in-clinic per month of 2026. The `Append` lists only `appointments_2026_01` … `appointments_2026_12`; all 2025 and 2027 partitions are pruned at plan time.

Run-time pruning (prepared statement, generic plan, the date is a parameter):
```text
Append (actual time=0.015..0.018 rows=3 loops=1)
  Subplans Removed: 36
  ->  Index Scan using appointments_2026_06_doctor_id_status_slot_start_patient_id_idx on appointments_2026_06
        Index Cond: ((doctor_id = $1) AND (slot_start >= $2) AND (slot_start < ($2 + '1 day'::interval)))
```

**The cost of partitioning.** R04 ("my appointments") and R11 have no `slot_start` filter, so they probe the patient index in **every** partition (37 probes on seed instead of 1; 0.18 ms, still far under 5 ms). This is why we use monthly, not daily, partitions. Re-run on large: ⏳.

**Next tables.** `prescriptions` RANGE by `issued_at` (monthly, aligned with appointments), and `prescription_items` HASH by `prescription_id` (8 partitions). Items are always fetched by `prescription_id` (R07, R15), so HASH keeps each lookup inside one partition and splits the 24 M rows evenly.

### 6.2 Sharding

**Options.** A patient's history spans many doctors, and a doctor's queue spans many patients, so no key keeps *everything* on one shard.

| Shard key | Stays on one shard | Becomes cross-shard |
|---|---|---|
| **city** | Clinic queues, city reports (R16, R19) | Video consultations (no clinic, any city), patients who travel, every national report. Cities are very unequal in size (Bengaluru/Mumbai vs smaller cities) → hot shards |
| **patient_id** | R04, R06, R10, R17, R25 | **R03 slot picker and W01 booking**: a doctor's free slots and double-booking check (R24) need *all* of that doctor's appointments, spread across every shard |
| **doctor_id** ✅ | R02, R03, R05, W01, W02, W05, R11 (same patient + same doctor), R14, R19, R24 | R04 (a patient's upcoming visits), R10, R17, R25, national reports |

**Our choice: shard by `doctor_id`.** The writes that must be correct and instant (W01 booking + R03 free slots, and "no double booking") involve one doctor's calendar, so they must run on one shard in one transaction. Co-locate `doctors`, `doctor_specializations`, `doctor_schedules`, `appointments`, `prescriptions`, `prescription_items` and `doctor_reviews` by `doctor_id` (prescription tables carry `doctor_id` for routing). `cities`, `specializations` and `clinics` are small and replicated to every shard.

**Handling the cross-shard queries:**

- **R04 / R06 (patient screens, < 5 ms):** `patients` lives in a separate patient service, sharded by `patient_id`. A small global lookup table `patient_appointments(patient_id, appointment_id, doctor_id, slot_start, status)`, sharded by `patient_id` and updated with each booking, answers "my appointments" from one shard.
- **R10, R17, R25 and the reports (R08, R12, R15, R16, R20):** scatter-gather. Each shard computes a partial aggregate (count, sum, distinct sets per patient), and a coordinator combines them (the model Citus uses). Better still, run them on an analytics copy (Section 6.3).
- **R25 "doctor shopping"** needs one patient's visits across doctors: computed nightly from the analytics copy into a summary table.

**Not yet.** At 20× and even 100× (≈ 15 M appointments, a few tens of GB with indexes) a single well-partitioned PostgreSQL primary with replicas is enough. Sharding adds cross-shard transactions and operational cost, so it is the step *after* partitioning + replicas, when write volume (bookings per second) outgrows one primary.

### 6.3 Read replicas and caching

| Where | Queries | Why |
|---|---|---|
| **Primary only** | W01, W02, W03, W04, W05 | Writes |
| **Primary** | R03 (slot picker), R05 (doctor's queue) | Must see the booking / check-in that happened a second ago. A free slot shown from a lagging replica leads to a failed or double booking |
| **Primary right after a write, replica otherwise** | R04, R07 | Read-your-own-writes: the patient who just booked (W01) or the doctor who just updated a prescription (W03) must see it. The app pins the session to the primary for a few seconds after a write |
| **Replica** | R06 (sign-in), R11, R13, R21, R22, R23 | Seconds of lag are harmless |
| **Replica (analytics)** | R08, R09, R10, R12, R14, R15, R16, R17, R19, R20, R24, R25 | Long reports must not compete with bookings for CPU and buffer cache on the primary |
| **Application cache** (TTL) | R01, R18 (search results: 5–10 min), R02 (doctor's timetable: invalidate when `doctor_schedules` changes), R23 (registration lookup: 1 day), R14 (doctor ranking: refreshed nightly via the materialized view) | Same answer for thousands of users; data changes rarely |

### 6.4 Maintenance

**Autovacuum for `appointments`.** The default `autovacuum_vacuum_scale_factor = 0.2` waits until 20% of a table is dead: 600 k dead rows at 20×, 3 M at 100× for an unpartitioned table. Most updates (check-in, consult start/end, payment, W04, W05) hit the **current month**, so with partitions we tune only that partition (already in `08_partitioning.sql`, section E2):

```sql
ALTER TABLE appointments_2026_07 SET (
    autovacuum_vacuum_scale_factor  = 0.02,   -- vacuum at 2% dead rows (~17 k rows at 100x, not ~170 k)
    autovacuum_analyze_scale_factor = 0.01,   -- keep planner statistics fresh for today's queries
    autovacuum_vacuum_cost_limit    = 1000    -- let the vacuum finish quickly
);
```

Closed months receive almost no updates; one `VACUUM (FREEZE)` after a month closes means autovacuum never needs to rewrite them for transaction-ID wraparound. The W04 nightly job creates a burst of dead rows (each `status` change rewrites the row and all its index entries; `status` is in our partial-index predicates, so these are not HOT updates), so the job is followed by `VACUUM (ANALYZE)` on the current partition.

**Archiving.** Most queries only read 2026 data, but R10, R14, R21, R22 and R24 currently scan *all* history, so the retention window (e.g. 18 months) must be agreed with the patient-safety, quality and finance teams first. Each month older than that is `DETACH`ed (a metadata change: no rows are copied or deleted), moved to a `practo_archive` schema or dumped to cheap storage, and dropped. The table the live queries see stays at ≈ 18 months whatever the total history.

**New partitions.** `create_appointments_partition()` runs monthly (pg_cron or OS cron) and keeps three future months ready, so bookings never fall into `appointments_default`. A daily alert checks `SELECT count(*) FROM appointments_default` = 0.

**Summary tables.** Materialized views (Section 4.4) are refreshed `CONCURRENTLY` nightly after W04, so reports stay readable during the refresh.

---

## 7. Conclusion

**Ready for next year?** ⏳: to be answered from Section 2. Our expectation from the seed plans:

- The **real-time** group (R02–R07, R23, W01–W03) uses index lookups whose cost grows with log n, so we expect it to stay well under 5 ms.
- The **reports** read a fixed share of the data and should grow ≈ 20×. Even the slowest on seed (R24, 116 ms) would be ≈ 2.3 s at 20×, under the 5 s target, unless a hash join or sort spills to disk (Section 3.3).
- **Must fix before the run:** R13 is wrong (0 rows instead of 292) and is the query most likely to blow up at scale with `NOT IN` (Section 1.1).

**Remaining risks:**

1. **Close to target:** at 20× the seed numbers project R13 (11 ms → ≈ 220 ms), R18 (10 ms → ≈ 210 ms) and W04 (31 ms → ≈ 615 ms) close to their 250 ms / 1,000 ms targets. Any extra growth from spills pushes them over.
2. **Index footprint and write cost:** 47 indexes, 2.2× the data size. `appointments` has 17 indexes (5 from Phase 2 + 12 from Phase 4); every booking maintains each one whose predicate matches.
3. **Deep pagination:** R22 with `OFFSET` is fine at page 4,001 but grows linearly with page depth; keyset pagination (Section 2.1) is the long-term fix.
4. **Partitioned-table constraints:** `appointment_id` uniqueness and the foreign keys from `prescriptions` / `doctor_reviews` need the composite-key design in Section 6.1 before the cut-over.
5. **Benchmark noise:** three runs per query on a laptop. Sub-millisecond differences are within noise; only order-of-magnitude changes should drive design decisions.
