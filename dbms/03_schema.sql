-- Practo Doctor Appointments
-- PostgreSQL schema
-- CP1: Database schema design

-- 1. Cities
CREATE TABLE IF NOT EXISTS cities (
    city_id INTEGER PRIMARY KEY,
    city_name TEXT NOT NULL,
    state TEXT NOT NULL
);

-- 2. Clinics
CREATE TABLE IF NOT EXISTS clinics (
    clinic_id INTEGER PRIMARY KEY,
    clinic_name TEXT NOT NULL,
    city_id INTEGER NOT NULL REFERENCES cities(city_id),
    locality TEXT,
    latitude NUMERIC(10, 6),
    longitude NUMERIC(10, 6),
    phone TEXT
);

-- 3. Patients
CREATE TABLE IF NOT EXISTS patients (
    patient_id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    dob DATE,
    gender TEXT,
    blood_group TEXT,
    allergies TEXT[],
    city_id INTEGER REFERENCES cities(city_id),
    created_at TIMESTAMPTZ
);

-- Email must be unique when provided.
CREATE UNIQUE INDEX IF NOT EXISTS idx_patients_email_unique
ON patients(email)
WHERE email IS NOT NULL;

-- 4. Doctors
CREATE TABLE IF NOT EXISTS doctors (
    doctor_id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    registration_no TEXT,
    gender TEXT,
    experience_years INTEGER CHECK (experience_years >= 0),
    consultation_fee NUMERIC(10, 2)
        CHECK (consultation_fee >= 0),
    video_fee NUMERIC(10, 2)
        CHECK (video_fee >= 0),
    languages TEXT[],
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    joined_on DATE
);

-- Registration number must be unique when provided.
CREATE UNIQUE INDEX IF NOT EXISTS idx_doctors_registration_unique
ON doctors(registration_no)
WHERE registration_no IS NOT NULL;

-- 5. Specializations
CREATE TABLE IF NOT EXISTS specializations (
    spec_id INTEGER PRIMARY KEY,
    spec_name TEXT NOT NULL
);

-- 6. Doctor specializations
CREATE TABLE IF NOT EXISTS doctor_specializations (
    doctor_id INTEGER NOT NULL REFERENCES doctors(doctor_id),
    spec_id INTEGER NOT NULL REFERENCES specializations(spec_id),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (doctor_id, spec_id)
);

-- 7. Doctor schedules
-- schedule_id is generated because the CSV has no schedule ID.
-- clinic_id is nullable for video consultation schedules.
CREATE TABLE IF NOT EXISTS doctor_schedules (
    schedule_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(doctor_id),
    weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    clinic_id INTEGER REFERENCES clinics(clinic_id),
    slot_minutes INTEGER NOT NULL CHECK (slot_minutes > 0),
    CHECK (end_time > start_time)
);

-- 8. Appointments
CREATE TABLE IF NOT EXISTS appointments (
    appointment_id BIGINT PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(patient_id),
    doctor_id INTEGER NOT NULL REFERENCES doctors(doctor_id),
    clinic_id INTEGER REFERENCES clinics(clinic_id),
    consult_type TEXT NOT NULL,
    booked_at TIMESTAMPTZ NOT NULL,
    slot_start TIMESTAMPTZ NOT NULL,
    slot_end TIMESTAMPTZ NOT NULL,
    reason TEXT,
    status TEXT NOT NULL,
    checked_in_at TIMESTAMPTZ,
    consult_started_at TIMESTAMPTZ,
    consult_ended_at TIMESTAMPTZ,
    fee NUMERIC(10, 2) CHECK (fee >= 0),
    payment_status TEXT,
    CHECK (slot_end > slot_start)
);

-- 9. Prescriptions
CREATE TABLE IF NOT EXISTS prescriptions (
    prescription_id BIGINT PRIMARY KEY,
    appointment_id BIGINT NOT NULL REFERENCES appointments(appointment_id),
    diagnosis TEXT,
    notes TEXT,
    follow_up_date DATE,
    issued_at TIMESTAMPTZ NOT NULL
);

-- 10. Prescription items
CREATE TABLE IF NOT EXISTS prescription_items (
    prescription_id BIGINT NOT NULL
        REFERENCES prescriptions(prescription_id),
    line_no INTEGER NOT NULL CHECK (line_no > 0),
    medicine_name TEXT NOT NULL,
    dosage TEXT,
    duration_days INTEGER,
    instructions TEXT,
    PRIMARY KEY (prescription_id, line_no)
);

-- 11. Doctor reviews
CREATE TABLE IF NOT EXISTS doctor_reviews (
    review_id BIGINT PRIMARY KEY,
    appointment_id BIGINT NOT NULL
        REFERENCES appointments(appointment_id),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    recommends BOOLEAN NOT NULL,
    wait_time_bucket TEXT,
    review_text TEXT,
    created_at TIMESTAMPTZ NOT NULL
);

-- Helpful indexes for common workload joins and filters.

CREATE INDEX IF NOT EXISTS idx_clinics_city
ON clinics(city_id);

CREATE INDEX IF NOT EXISTS idx_patients_city
ON patients(city_id);

CREATE INDEX IF NOT EXISTS idx_doctor_specializations_spec
ON doctor_specializations(spec_id, doctor_id);

CREATE INDEX IF NOT EXISTS idx_doctor_schedules_doctor
ON doctor_schedules(doctor_id, weekday);

CREATE INDEX IF NOT EXISTS idx_doctor_schedules_clinic
ON doctor_schedules(clinic_id);

CREATE INDEX IF NOT EXISTS idx_appointments_patient_slot
ON appointments(patient_id, slot_start);

CREATE INDEX IF NOT EXISTS idx_appointments_doctor_slot
ON appointments(doctor_id, slot_start);

CREATE INDEX IF NOT EXISTS idx_appointments_clinic_slot
ON appointments(clinic_id, slot_start);

CREATE INDEX IF NOT EXISTS idx_appointments_status
ON appointments(status);

CREATE INDEX IF NOT EXISTS idx_prescriptions_appointment
ON prescriptions(appointment_id);

CREATE INDEX IF NOT EXISTS idx_prescriptions_follow_up
ON prescriptions(follow_up_date);

CREATE INDEX IF NOT EXISTS idx_prescription_items_medicine
ON prescription_items(medicine_name);

CREATE INDEX IF NOT EXISTS idx_doctor_reviews_appointment
ON doctor_reviews(appointment_id);
