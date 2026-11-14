-- Practo Doctor Appointments
-- CSV data loading script
-- Run from the project root directory.

BEGIN;

-- 1. Parent tables
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT CSV, HEADER TRUE)
\copy specializations FROM 'seed_data/specializations.csv' WITH (FORMAT CSV, HEADER TRUE)

-- 2. Main entity tables
\copy clinics FROM 'seed_data/clinics.csv' WITH (FORMAT CSV, HEADER TRUE)
\copy patients FROM 'seed_data/patients.csv' WITH (FORMAT CSV, HEADER TRUE)
\copy doctors FROM 'seed_data/doctors.csv' WITH (FORMAT CSV, HEADER TRUE)

-- 3. Doctor relationships and schedules
\copy doctor_specializations FROM 'seed_data/doctor_specializations.csv' WITH (FORMAT CSV, HEADER TRUE)

\copy doctor_schedules (doctor_id, weekday, start_time, end_time, clinic_id, slot_minutes) FROM 'seed_data/doctor_schedules.csv' WITH (FORMAT CSV, HEADER TRUE)

-- 4. Appointments
\copy appointments FROM 'seed_data/appointments.csv' WITH (FORMAT CSV, HEADER TRUE)

-- 5. Prescriptions and reviews
\copy prescriptions FROM 'seed_data/prescriptions.csv' WITH (FORMAT CSV, HEADER TRUE)
\copy doctor_reviews FROM 'seed_data/doctor_reviews.csv' WITH (FORMAT CSV, HEADER TRUE)

-- 6. Prescription medicine items
\copy prescription_items FROM 'seed_data/prescription_items.csv' WITH (FORMAT CSV, HEADER TRUE)

COMMIT;
