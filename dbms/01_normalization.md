# Database Normalization – Practo Doctor Appointments

## 1. Introduction

Normalization is the process of organizing database tables to reduce data redundancy, prevent insertion, update and deletion anomalies, and maintain data integrity.

The Practo Doctor Appointments database is designed using relational database principles. It contains information about cities, clinics, patients, doctors, specializations, schedules, appointments, prescriptions, prescription items and doctor reviews.

The database is structured to achieve 3NF (Third Normal Form), with primary keys, foreign keys, composite keys and integrity constraints.

## 2. First Normal Form (1NF)

A relation satisfies First Normal Form when:

- Each column contains a single value.
- Each row can be uniquely identified.
- There are no repeating groups of columns.
- Each attribute contains an atomic value.

### Initial design considerations

A single unnormalized appointment-management relation could contain information about patients, doctors, clinics, specializations, appointments and multiple prescribed medicines together.

For example, storing multiple medicines in columns such as `medicine_1`, `medicine_2` and `medicine_3` would create repeating groups.

Similarly, storing multiple specializations in one field would make searching and updating difficult.

### Conversion to 1NF

The data is separated into individual relations:

1. `cities`
2. `clinics`
3. `patients`
4. `doctors`
5. `specializations`
6. `doctor_specializations`
7. `doctor_schedules`
8. `appointments`
9. `prescriptions`
10. `prescription_items`
11. `doctor_reviews`

Each relation has a primary key. Repeating prescription medicines are stored as separate rows in `prescription_items`, identified by the composite key `(prescription_id, line_no)`.

Doctors and their specializations are separated into `doctor_specializations`, which represents their many-to-many relationship.

**Note:** The current PostgreSQL implementation stores `patients.allergies` and `doctors.languages` as `TEXT[]` arrays for convenience. These are multi-valued attributes and are not strictly atomic under classical 1NF. For strict 1NF, they could be moved into separate child tables such as `patient_allergies(patient_id, allergy)` and `doctor_languages(doctor_id, language)`.

## 3. Second Normal Form (2NF)

A relation satisfies Second Normal Form when:

- It is already in 1NF.
- Every non-key attribute is fully dependent on the entire candidate key.
- There are no partial dependencies on a part of a composite key.

### Problem addressed

Consider the `doctor_specializations` relation:

| doctor_id | spec_id | is_primary |
|---|---|---|
| 101 | 1 | TRUE |
| 101 | 2 | FALSE |
| 102 | 1 | TRUE |

The composite primary key is `(doctor_id, spec_id)`.

The attribute `is_primary` depends on the complete combination of doctor and specialization.

It does not depend only on `doctor_id` or only on `spec_id`.

### Conversion to 2NF

The database separates doctor information and specialization information into their own tables:

- `doctors` stores doctor details.
- `specializations` stores specialization details.
- `doctor_specializations` stores the relationship between doctors and specializations.

The `prescription_items` table also uses a composite primary key:

`(prescription_id, line_no)`

The medicine details depend on the complete composite key, because a line number identifies an item within a particular prescription.

This design avoids partial dependencies and supports 2NF for relations with composite keys.

## 4. Third Normal Form (3NF)

A relation satisfies Third Normal Form when:

- It is already in 2NF.
- It has no transitive dependencies of non-key attributes on a candidate key.
- Non-key attributes depend on the key, the whole key and nothing but the key.

### Problems addressed

If clinic information were stored repeatedly in appointment records, changing clinic details could require updating multiple rows.

Similarly, if specialization names were stored repeatedly with every doctor, the same specialization information would be duplicated.

### Conversion to 3NF

The database separates independent entities into their own tables.

Examples:

**Cities and clinics**

- `cities` stores city information.
- `clinics` stores clinic information and references `cities` through `city_id`.

**Doctors and specializations**

- `doctors` stores doctor details.
- `specializations` stores specialization details.
- `doctor_specializations` connects the two entities.

**Patients and appointments**

- `patients` stores patient details.
- `appointments` stores appointment details and references the patient through `patient_id`.

**Appointments and prescriptions**

- `appointments` stores appointment information.
- `prescriptions` stores diagnosis, notes, follow-up date and issue date.
- `prescription_items` stores individual medicines for each prescription.

**Doctor reviews**

- `doctor_reviews` stores review details separately and references appointments through `appointment_id`.

These separations reduce duplicated information and avoid transitive dependencies between independent entities.

## 5. Functional Dependencies

A functional dependency describes a relationship in which one attribute or a group of attributes determines another attribute or group of attributes.

The main functional dependencies in the final schema are:

| Relation | Functional dependency |
|---|---|
| cities | city_id → city_name, state |
| clinics | clinic_id → clinic_name, city_id, locality, latitude, longitude, phone |
| patients | patient_id → full_name, phone, email, dob, gender, blood_group, allergies, city_id, created_at |
| doctors | doctor_id → full_name, registration_no, gender, experience_years, consultation_fee, video_fee, languages, is_verified, joined_on |
| specializations | spec_id → spec_name |
| doctor_specializations | (doctor_id, spec_id) → is_primary |
| doctor_schedules | schedule_id → doctor_id, weekday, start_time, end_time, clinic_id, slot_minutes |
| appointments | appointment_id → patient_id, doctor_id, clinic_id, consult_type, booked_at, slot_start, slot_end, reason, status, checked_in_at, consult_started_at, consult_ended_at, fee, payment_status |
| prescriptions | prescription_id → appointment_id, diagnosis, notes, follow_up_date, issued_at |
| prescription_items | (prescription_id, line_no) → medicine_name, dosage, duration_days, instructions |
| doctor_reviews | review_id → appointment_id, rating, recommends, wait_time_bucket, review_text, created_at |

Additional uniqueness constraints:

- `patients.email` is unique when it is not NULL.
- `doctors.registration_no` is unique when it is not NULL.

These are implemented using partial unique indexes in PostgreSQL.

## 6. Primary Keys and Foreign Keys

| Table | Primary key | Important foreign keys |
|---|---|---|
| cities | city_id | None |
| clinics | clinic_id | city_id → cities |
| patients | patient_id | city_id → cities |
| doctors | doctor_id | None |
| specializations | spec_id | None |
| doctor_specializations | doctor_id, spec_id | doctor_id → doctors; spec_id → specializations |
| doctor_schedules | schedule_id | doctor_id → doctors; clinic_id → clinics |
| appointments | appointment_id | patient_id → patients; doctor_id → doctors; clinic_id → clinics |
| prescriptions | prescription_id | appointment_id → appointments |
| prescription_items | prescription_id, line_no | prescription_id → prescriptions |
| doctor_reviews | review_id | appointment_id → appointments |

## 7. Integrity Constraints

The schema uses several constraints to maintain valid data:

- Primary keys uniquely identify records.
- Foreign keys maintain referential integrity.
- Doctor experience and consultation fees cannot be negative.
- Appointment fees cannot be negative.
- Appointment end time must be later than appointment start time.
- Schedule weekday must be between 1 and 7.
- Schedule slot duration must be positive.
- Schedule end time must be later than start time.
- Prescription item line numbers must be positive.
- Doctor review ratings must be between 1 and 5.
- Patient email and doctor registration number are unique when provided.

## 8. Conclusion

The Practo Doctor Appointments database separates independent entities into dedicated relations and uses primary keys, foreign keys and composite keys to maintain data integrity.

The design addresses redundancy and partial and transitive dependencies through normalization up to 3NF. The many-to-many relationship between doctors and specializations is handled through a junction table, while prescription items are stored separately from prescription headers.

PostgreSQL arrays are retained for patient allergies and doctor languages as a practical design choice; strict 1NF would require separate child relations for these multi-valued attributes.

Overall, the schema provides a structured foundation for doctor discovery, clinic management, scheduling, appointment booking, prescription management and doctor reviews.

