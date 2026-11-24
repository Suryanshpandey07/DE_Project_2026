-- Phase 5: Appointment table partitioning experiment
-- Original practo.appointments remains unchanged.
-- This is a separate partitioned copy for scalability testing.

BEGIN;

-- Create a partitioned copy of the appointments table.
-- The composite primary key includes the partition column,
-- as required by PostgreSQL.

CREATE TABLE IF NOT EXISTS practo.appointments_partitioned (
    appointment_id BIGINT NOT NULL,
    patient_id INTEGER NOT NULL,
    doctor_id INTEGER NOT NULL,
    clinic_id INTEGER,
    consult_type TEXT NOT NULL,
    booked_at TIMESTAMPTZ NOT NULL,
    slot_start TIMESTAMPTZ NOT NULL,
    slot_end TIMESTAMPTZ NOT NULL,
    reason TEXT,
    status TEXT NOT NULL,
    checked_in_at TIMESTAMPTZ,
    consult_started_at TIMESTAMPTZ,
    consult_ended_at TIMESTAMPTZ,
    fee NUMERIC,
    payment_status TEXT,

    PRIMARY KEY (appointment_id, slot_start)
)
PARTITION BY RANGE (slot_start);

-- Year-wise partitions.
-- Bounds use the same +05:30 timezone as the observed data.

CREATE TABLE IF NOT EXISTS practo.appointments_partitioned_2025
PARTITION OF practo.appointments_partitioned
FOR VALUES FROM (
    TIMESTAMPTZ '2025-01-01 00:00:00+05:30'
) TO (
    TIMESTAMPTZ '2026-01-01 00:00:00+05:30'
);

CREATE TABLE IF NOT EXISTS practo.appointments_partitioned_2026
PARTITION OF practo.appointments_partitioned
FOR VALUES FROM (
    TIMESTAMPTZ '2026-01-01 00:00:00+05:30'
) TO (
    TIMESTAMPTZ '2027-01-01 00:00:00+05:30'
);

CREATE TABLE IF NOT EXISTS practo.appointments_partitioned_2027
PARTITION OF practo.appointments_partitioned
FOR VALUES FROM (
    TIMESTAMPTZ '2027-01-01 00:00:00+05:30'
) TO (
    TIMESTAMPTZ '2028-01-01 00:00:00+05:30'
);

-- Catch dates outside the explicitly defined partitions.

CREATE TABLE IF NOT EXISTS practo.appointments_partitioned_default
PARTITION OF practo.appointments_partitioned
DEFAULT;

-- Load the existing appointment data into the partitioned copy.
-- ON CONFLICT makes rerunning the load safe for existing rows.

INSERT INTO practo.appointments_partitioned (
    appointment_id,
    patient_id,
    doctor_id,
    clinic_id,
    consult_type,
    booked_at,
    slot_start,
    slot_end,
    reason,
    status,
    checked_in_at,
    consult_started_at,
    consult_ended_at,
    fee,
    payment_status
)
SELECT
    appointment_id,
    patient_id,
    doctor_id,
    clinic_id,
    consult_type,
    booked_at,
    slot_start,
    slot_end,
    reason,
    status,
    checked_in_at,
    consult_started_at,
    consult_ended_at,
    fee,
    payment_status
FROM practo.appointments
ON CONFLICT (appointment_id, slot_start) DO NOTHING;

-- Indexes useful for common appointment queries.

CREATE INDEX IF NOT EXISTS idx_appt_partitioned_doctor_slot
ON practo.appointments_partitioned (doctor_id, slot_start);

CREATE INDEX IF NOT EXISTS idx_appt_partitioned_patient_slot
ON practo.appointments_partitioned (patient_id, slot_start);

CREATE INDEX IF NOT EXISTS idx_appt_partitioned_status_slot
ON practo.appointments_partitioned (status, slot_start);

COMMIT;

-- Verify total row count.

SELECT COUNT(*) AS partitioned_appointment_count
FROM practo.appointments_partitioned;

-- Verify distribution across partitions.

SELECT
    tableoid::regclass AS partition_name,
    COUNT(*) AS appointment_count
FROM practo.appointments_partitioned
GROUP BY tableoid
ORDER BY partition_name;

-- Verify that the yearly data matches the original table.

SELECT
    EXTRACT(YEAR FROM slot_start) AS appointment_year,
    COUNT(*) AS appointment_count
FROM practo.appointments_partitioned
GROUP BY 1
ORDER BY 1;

-- Demonstrate partition pruning for a date-range query.

EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM practo.appointments_partitioned
WHERE slot_start >= TIMESTAMPTZ '2026-05-01 00:00:00+05:30'
  AND slot_start < TIMESTAMPTZ '2026-06-01 00:00:00+05:30';
