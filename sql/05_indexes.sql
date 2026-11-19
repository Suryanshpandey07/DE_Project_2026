
-- R17: Optimize completed appointment filtering

SET search_path TO practo;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Core appointment access patterns
CREATE INDEX IF NOT EXISTS idx_appointments_status_slot
ON appointments (status, slot_start DESC)
INCLUDE (appointment_id, patient_id, doctor_id, clinic_id, consult_type, slot_end,
         consult_started_at, consult_ended_at, fee, payment_status);

CREATE INDEX IF NOT EXISTS idx_appointments_patient_status_slot
ON appointments (patient_id, status, slot_start DESC)
INCLUDE (appointment_id, doctor_id, clinic_id, consult_type);

CREATE INDEX IF NOT EXISTS idx_appointments_doctor_status_slot
ON appointments (doctor_id, status, slot_start DESC)
INCLUDE (appointment_id, patient_id, slot_end, checked_in_at, consult_ended_at);

CREATE INDEX IF NOT EXISTS idx_appointments_completed_slot_patient
ON appointments (slot_start, patient_id)
INCLUDE (appointment_id, doctor_id, clinic_id, consult_type)
WHERE status = 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_appointments_completed_date_covering
ON appointments (slot_start DESC)
INCLUDE (appointment_id, patient_id, doctor_id, clinic_id, consult_type,
         consult_started_at, fee)
WHERE status = 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_appointments_completed_no_show_2026
ON appointments (slot_start, doctor_id)
INCLUDE (status)
WHERE status IN ('COMPLETED', 'NO_SHOW')
  AND slot_start >= '2026-01-01'
  AND slot_start < '2027-01-01';

CREATE INDEX IF NOT EXISTS idx_appointments_2026_type
ON appointments (slot_start, consult_type)
WHERE slot_start >= '2026-01-01'
  AND slot_start < '2027-01-01';

CREATE INDEX IF NOT EXISTS idx_appointments_pending_in_clinic
ON appointments (slot_start DESC)
INCLUDE (appointment_id, patient_id, clinic_id, fee)
WHERE status = 'COMPLETED' AND payment_status = 'PENDING';

CREATE INDEX IF NOT EXISTS idx_appointments_active_doctor_slot
ON appointments (doctor_id, slot_start, appointment_id)
WHERE status <> 'CANCELLED';

CREATE INDEX IF NOT EXISTS idx_appointments_booked_slot
ON appointments (slot_start, appointment_id)
INCLUDE (patient_id, doctor_id, clinic_id, consult_type, slot_end,
         consult_ended_at, payment_status)
WHERE status = 'BOOKED';

CREATE INDEX IF NOT EXISTS idx_appointments_nightly_job
ON appointments (slot_end)
INCLUDE (appointment_id, status)
WHERE status IN ('BOOKED', 'CHECKED_IN') AND consult_ended_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_appointments_slot_covering
ON appointments (slot_start DESC)
INCLUDE (appointment_id, patient_id, doctor_id, status);

-- Join, lookup, and report indexes
CREATE INDEX IF NOT EXISTS idx_patients_phone
ON patients (phone);

CREATE INDEX IF NOT EXISTS idx_patients_allergies_gin
ON patients USING GIN (allergies);

CREATE INDEX IF NOT EXISTS idx_doctors_languages_gin
ON doctors USING GIN (languages);

CREATE INDEX IF NOT EXISTS idx_doctor_specializations_primary
ON doctor_specializations (doctor_id, spec_id)
INCLUDE (is_primary)
WHERE is_primary;

CREATE INDEX IF NOT EXISTS idx_prescriptions_follow_up_patient
ON prescriptions (follow_up_date, appointment_id)
INCLUDE (prescription_id);

CREATE INDEX IF NOT EXISTS idx_prescriptions_issued_at
ON prescriptions (issued_at, appointment_id)
INCLUDE (prescription_id);

CREATE INDEX IF NOT EXISTS idx_prescription_items_medicine_name
ON prescription_items (medicine_name);

CREATE INDEX IF NOT EXISTS idx_prescription_items_medicine_trgm
ON prescription_items USING GIN (medicine_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_doctor_reviews_rating
ON doctor_reviews (appointment_id)
INCLUDE (rating, recommends);

ANALYZE;
