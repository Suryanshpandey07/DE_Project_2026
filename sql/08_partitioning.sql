-- =====================================================================
-- Practo DBMS Project: Phase 5 — partitioning design for `appointments`
-- File: sql/08_partitioning.sql
--
-- What this script does
--   A. Creates practo.appointments_part: a copy of `appointments` that is
--      RANGE-partitioned by slot_start, one partition per month.
--   B. Creates the indexes the workload needs, once, on the parent
--      (PostgreSQL creates them on every partition automatically).
--   C. Copies the rows from `appointments` and checks nothing was lost.
--   D. Shows partition pruning with EXPLAIN.
--   E. Maintenance helpers: create next month's partition, archive an old
--      month, autovacuum settings for the "hot" (current) partition.
--   F. (Commented out) how to make the partitioned table THE appointments
--      table, and what happens to the foreign keys that point at it.
--
-- The script builds the partitioned table NEXT TO the live table, so the
-- benchmark workload (sql/06_optimized_queries.sql) is not affected.
-- It can be re-run: it drops and rebuilds appointments_part each time.
--
-- Run after 01_schema.sql, 02_load_data.sql and 05_indexes.sql:
--   psql -d practo_db -v ON_ERROR_STOP=1 -f sql/08_partitioning.sql
-- =====================================================================

SET search_path TO practo;

-- =====================================================================
-- A. Partitioned table
-- =====================================================================
-- Why appointments?   It is the largest and fastest-growing table
--                     (150k rows on seed, ~3M on large, ~15M at 100x) and
--                     22 of the 30 queries read or write it.
-- Why slot_start?     12 of the 30 queries filter on a slot_start range
--                     (a day, a month, a year): R05 R08 R09 R12 R16 R17 R19
--                     R20 R25 W02 W05, plus R03 on one slot. Those queries
--                     only read the partitions in that range (pruning).
-- Why RANGE monthly?  Data arrives in time order and old months stop
--                     changing. Monthly partitions are ~170k rows at 20x and
--                     ~850k rows at 100x: small enough to VACUUM quickly,
--                     and old months can be detached/archived as a unit.
--                     LIST does not fit a timestamp; HASH spreads every
--                     date range over ALL partitions, so nothing is pruned.
--
-- Primary-key rule for partitioned tables:
--   A PRIMARY KEY or UNIQUE constraint on a partitioned table MUST include
--   every partition-key column, because each partition can only enforce
--   uniqueness for its own rows. So the key is (appointment_id, slot_start)
--   instead of (appointment_id). appointment_id is still unique in practice
--   (it comes from one sequence), but the database cannot enforce
--   "appointment_id alone is unique" across partitions.
-- =====================================================================

DROP TABLE IF EXISTS appointments_part CASCADE;

CREATE TABLE appointments_part (
    appointment_id     BIGINT        NOT NULL,
    patient_id         INTEGER       NOT NULL REFERENCES patients(patient_id),
    doctor_id          INTEGER       NOT NULL REFERENCES doctors(doctor_id),
    clinic_id          INTEGER                REFERENCES clinics(clinic_id),
    consult_type       TEXT          NOT NULL,
    booked_at          TIMESTAMPTZ   NOT NULL,
    slot_start         TIMESTAMPTZ   NOT NULL,
    slot_end           TIMESTAMPTZ   NOT NULL,
    reason             TEXT,
    status             TEXT          NOT NULL,
    checked_in_at      TIMESTAMPTZ,
    consult_started_at TIMESTAMPTZ,
    consult_ended_at   TIMESTAMPTZ,
    fee                NUMERIC(10,2) CHECK (fee >= 0),
    payment_status     TEXT,
    CHECK (slot_end > slot_start),
    -- partition key (slot_start) must be part of the primary key
    PRIMARY KEY (appointment_id, slot_start)
) PARTITION BY RANGE (slot_start);

-- One partition per month, Jan 2025 .. Dec 2027.
-- Bounds are given in IST (+05:30) so "June 2026" means the IST month,
-- matching how the workload writes its date ranges.
-- Lower bound is inclusive, upper bound is exclusive: no gaps, no overlaps.
DO $$
DECLARE
    m date := DATE '2025-01-01';
BEGIN
    WHILE m < DATE '2028-01-01' LOOP
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF appointments_part
                 FOR VALUES FROM (%L) TO (%L)',
            'appointments_' || to_char(m, 'YYYY_MM'),
            m::text || ' 00:00:00+05:30',
            (m + interval '1 month')::date::text || ' 00:00:00+05:30');
        m := (m + interval '1 month')::date;
    END LOOP;
END $$;

-- Safety net: a row outside every monthly range lands here instead of
-- failing the INSERT. It should stay EMPTY (checked in section C); if it
-- fills up, the monthly job in section E has stopped running.
CREATE TABLE appointments_default PARTITION OF appointments_part DEFAULT;

-- =====================================================================
-- B. Indexes (declared once on the parent, cascaded to every partition)
-- =====================================================================
-- With pruning, the partial indexes in 05_indexes.sql that hard-code a year
-- (idx_appointments_completed_no_show_2026, idx_appointments_2026_type)
-- are no longer needed: pruning already limits those queries to 2026.
-- Each index below is a smaller per-month B-tree, so lookups are cheaper
-- and an old month's indexes leave with it when it is detached.

-- R03, R05, R19, R24, W05: doctor's appointments in a time window
CREATE INDEX ON appointments_part (doctor_id, slot_start)
    WHERE status <> 'CANCELLED';
CREATE INDEX ON appointments_part (doctor_id, status, slot_start)
    INCLUDE (patient_id, slot_end, checked_in_at, consult_ended_at);

-- R04, R11: a patient's appointments. These queries do NOT filter on
-- slot_start, so they probe this index in every partition (see D3).
CREATE INDEX ON appointments_part (patient_id, status, slot_start)
    INCLUDE (doctor_id, clinic_id, consult_type);

-- R09, R17, R20, R25: completed consultations in a period
CREATE INDEX ON appointments_part (slot_start, patient_id)
    INCLUDE (doctor_id, clinic_id, consult_type, consult_started_at, fee)
    WHERE status = 'COMPLETED';

-- R16, R22: everything in a period / newest first
CREATE INDEX ON appointments_part (slot_start)
    INCLUDE (patient_id, doctor_id, status, clinic_id, payment_status, fee);

-- W02: earliest BOOKED appointment of the day
CREATE INDEX ON appointments_part (slot_start)
    INCLUDE (consult_type)
    WHERE status = 'BOOKED';

-- W04: nightly NO_SHOW job
CREATE INDEX ON appointments_part (slot_end)
    WHERE status IN ('BOOKED', 'CHECKED_IN') AND consult_ended_at IS NULL;

-- R21: completed but unpaid
CREATE INDEX ON appointments_part (slot_start)
    INCLUDE (patient_id, clinic_id, fee)
    WHERE status = 'COMPLETED' AND payment_status = 'PENDING';

-- =====================================================================
-- C. Copy the data and verify
-- =====================================================================
INSERT INTO appointments_part
SELECT appointment_id, patient_id, doctor_id, clinic_id, consult_type,
       booked_at, slot_start, slot_end, reason, status, checked_in_at,
       consult_started_at, consult_ended_at, fee, payment_status
FROM appointments;

ANALYZE appointments_part;

-- C1. Same number of rows, same ids, same total fee
SELECT 'appointments'      AS tbl, count(*) AS rows,
       sum(appointment_id) AS id_checksum, sum(fee) AS fee_checksum
FROM appointments
UNION ALL
SELECT 'appointments_part', count(*), sum(appointment_id), sum(fee)
FROM appointments_part;

-- C2. Row-by-row comparison: both directions must return 0
SELECT 'missing in partitioned' AS check_name, count(*) AS rows
FROM (SELECT * FROM appointments EXCEPT ALL SELECT * FROM appointments_part) x
UNION ALL
SELECT 'extra in partitioned', count(*)
FROM (SELECT * FROM appointments_part EXCEPT ALL SELECT * FROM appointments) y;

-- C3. appointment_id is still unique (the PK alone no longer guarantees it)
SELECT count(*) AS duplicate_appointment_ids
FROM (SELECT appointment_id FROM appointments_part
      GROUP BY appointment_id HAVING count(*) > 1) d;

-- C4. Rows per partition (the default partition should be 0)
SELECT tableoid::regclass AS partition, count(*) AS rows,
       min(slot_start) AS first_slot, max(slot_start) AS last_slot
FROM appointments_part
GROUP BY 1
ORDER BY 1;

-- =====================================================================
-- D. Partition pruning
-- =====================================================================
-- D1. R05 (doctor's queue for one day): only appointments_2026_06 is read.
--     Look for a single partition under "Append" (or no Append at all).
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT a.appointment_id, a.slot_start, a.status, a.checked_in_at
FROM appointments_part a
WHERE a.doctor_id = 16
  AND a.slot_start >= '2026-06-30 00:00:00+05:30'
  AND a.slot_start <  '2026-07-01 00:00:00+05:30'
ORDER BY a.slot_start;

-- D2. R12 (video vs in-clinic per month in 2026): only the 12 partitions of
--     2026 are scanned; all 2025 and 2027 partitions are pruned at plan time.
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT date_trunc('month', slot_start) AS month, consult_type, count(*)
FROM appointments_part
WHERE slot_start >= '2026-01-01 00:00:00+05:30'
  AND slot_start <  '2027-01-01 00:00:00+05:30'
GROUP BY 1, 2
ORDER BY 1, 2;

-- D3. The cost of partitioning: R04 ("my appointments") has no slot_start
--     filter, so the planner must probe the patient index in EVERY
--     partition (37 small index probes instead of 1). Still fast, but it is
--     why the number of partitions must stay moderate (monthly, not daily).
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT appointment_id, consult_type, slot_start
FROM appointments_part
WHERE patient_id = 90 AND status = 'BOOKED'
ORDER BY slot_start;

-- D4. Run-time pruning: with a parameter the bound is unknown at plan
--     time; the executor still skips partitions ("Subplans Removed").
PREPARE day_queue(int, timestamptz) AS
SELECT appointment_id, slot_start, status
FROM appointments_part
WHERE doctor_id = $1
  AND slot_start >= $2
  AND slot_start <  $2 + interval '1 day';
SET plan_cache_mode = force_generic_plan;
EXPLAIN (ANALYZE, COSTS OFF) EXECUTE day_queue(16, '2026-06-30 00:00:00+05:30');
RESET plan_cache_mode;
DEALLOCATE day_queue;

-- =====================================================================
-- E. Maintenance
-- =====================================================================
-- E1. Create a month's partition ahead of time (run monthly, e.g. from
--     pg_cron or an OS cron job: SELECT practo.create_appointments_partition(
--     (date_trunc('month', now()) + interval '3 months')::date);
--     Keeping 2-3 future months ready means bookings never fall into the
--     default partition.
CREATE OR REPLACE FUNCTION create_appointments_partition(p_month date)
RETURNS text
LANGUAGE plpgsql AS $$
DECLARE
    m    date := date_trunc('month', p_month)::date;
    name text := 'appointments_' || to_char(m, 'YYYY_MM');
BEGIN
    IF to_regclass('practo.' || name) IS NOT NULL THEN
        RETURN name || ' already exists';
    END IF;
    EXECUTE format(
        'CREATE TABLE practo.%I PARTITION OF practo.appointments_part
             FOR VALUES FROM (%L) TO (%L)',
        name,
        m::text || ' 00:00:00+05:30',
        (m + interval '1 month')::date::text || ' 00:00:00+05:30');
    RETURN name || ' created';
END $$;

SELECT create_appointments_partition(DATE '2028-01-01');   -- creates Jan 2028
SELECT create_appointments_partition(DATE '2028-01-15');   -- already exists

-- E2. Hot partition: the current month gets most of the UPDATEs
--     (check-in, consult start/end, payment, W04 no-show job, W05 cancel).
--     The default autovacuum_vacuum_scale_factor = 0.2 waits until 20% of a
--     table is dead; on a 15M-row unpartitioned table that is 3M dead rows.
--     Per partition we can vacuum the hot month aggressively and leave
--     closed months alone (they are frozen once and never change).
ALTER TABLE appointments_2026_07 SET (
    autovacuum_vacuum_scale_factor  = 0.02,   -- vacuum at 2% dead rows
    autovacuum_analyze_scale_factor = 0.01,   -- fresh stats for the planner
    autovacuum_vacuum_cost_limit    = 1000    -- let it finish quickly
);

-- E3. Archive an old month (example, not executed).
--     DETACH is a metadata change: no rows are copied or deleted, and the
--     month's indexes leave with it. Note: DETACH ... CONCURRENTLY is not
--     allowed while a DEFAULT partition exists, so use the plain form in a
--     quiet window, or drop the default partition first.
--
-- ALTER TABLE appointments_part DETACH PARTITION appointments_2025_01;
-- CREATE SCHEMA IF NOT EXISTS practo_archive;
-- ALTER TABLE appointments_2025_01 SET SCHEMA practo_archive;
--   -- or: pg_dump -t practo_archive.appointments_2025_01 ... and DROP it

-- E4. Size per partition (table + its indexes)
SELECT c.relname AS partition,
       pg_size_pretty(pg_relation_size(c.oid))       AS table_size,
       pg_size_pretty(pg_indexes_size(c.oid))        AS index_size,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
WHERE i.inhparent = 'practo.appointments_part'::regclass
ORDER BY c.relname;

-- =====================================================================
-- F. Cut-over: make the partitioned table the real `appointments`
--    (commented out — run in a maintenance window, not during benchmarks)
-- =====================================================================
-- Foreign-key problem: prescriptions.appointment_id and
-- doctor_reviews.appointment_id reference appointments(appointment_id).
-- A foreign key must point at a UNIQUE/PK constraint, and on a partitioned
-- table that constraint must include slot_start. Two options:
--   1. Add slot_start to prescriptions and doctor_reviews and use a
--      composite FK (appointment_id, slot_start). Fully enforced, but it
--      duplicates a column in two tables.
--   2. Keep the child tables as they are, drop the two FKs, and enforce
--      "the appointment exists" in the application / with a trigger.
-- We choose option 1: the database keeps enforcing integrity, and the extra
-- column also lets prescription queries prune appointment partitions.
--
-- BEGIN;
-- ALTER TABLE prescriptions  ADD COLUMN appt_slot_start TIMESTAMPTZ;
-- ALTER TABLE doctor_reviews ADD COLUMN appt_slot_start TIMESTAMPTZ;
-- UPDATE prescriptions  p SET appt_slot_start = a.slot_start
--   FROM appointments a WHERE a.appointment_id = p.appointment_id;
-- UPDATE doctor_reviews r SET appt_slot_start = a.slot_start
--   FROM appointments a WHERE a.appointment_id = r.appointment_id;
-- ALTER TABLE prescriptions  ALTER COLUMN appt_slot_start SET NOT NULL;
-- ALTER TABLE doctor_reviews ALTER COLUMN appt_slot_start SET NOT NULL;
-- ALTER TABLE prescriptions  DROP CONSTRAINT prescriptions_appointment_id_fkey;
-- ALTER TABLE doctor_reviews DROP CONSTRAINT doctor_reviews_appointment_id_fkey;
-- ALTER TABLE appointments      RENAME TO appointments_old;
-- ALTER TABLE appointments_part RENAME TO appointments;
-- ALTER TABLE prescriptions ADD CONSTRAINT prescriptions_appointment_fkey
--   FOREIGN KEY (appointment_id, appt_slot_start)
--   REFERENCES appointments (appointment_id, slot_start) ON DELETE CASCADE;
-- ALTER TABLE doctor_reviews ADD CONSTRAINT doctor_reviews_appointment_fkey
--   FOREIGN KEY (appointment_id, appt_slot_start)
--   REFERENCES appointments (appointment_id, slot_start) ON DELETE CASCADE;
-- COMMIT;
-- -- after checking everything: DROP TABLE appointments_old;
