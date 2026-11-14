
-- R17: Optimize completed appointment filtering

CREATE INDEX IF NOT EXISTS idx_appointments_completed_slot_patient
ON practo.appointments (slot_start, patient_id)
WHERE status = 'COMPLETED';



-- R22: Optimize appointment pagination and ordering
CREATE INDEX IF NOT EXISTS idx_appointments_slot_covering
ON practo.appointments (slot_start DESC)
INCLUDE (appointment_id, patient_id, doctor_id, status);
