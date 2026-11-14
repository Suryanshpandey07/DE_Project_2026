# Schema Design – Practo Doctor Appointments

## 1. Database Overview

The database is designed for a Practo-style doctor appointment management system.

It stores information about patients, doctors, clinics, cities, specializations, doctor schedules, appointments, prescriptions, prescription items, and doctor reviews.

The database uses PostgreSQL. The design supports the existing 30-query workload, including appointment searches, doctor discovery, patient safety checks, prescription analysis, clinic analytics, and appointment updates.

## 2. Tables and Attributes

### 2.1 cities

Stores city and state information.

| Column | Description |
|---|---|
| city_id | Primary key |
| city_name | Name of the city |
| state | State name |

### 2.2 clinics

Stores clinic information and its location.

| Column | Description |
|---|---|
| clinic_id | Primary key |
| clinic_name | Name of the clinic |
| city_id | Foreign key referencing cities |
| locality | Clinic locality |
| latitude | Geographic latitude |
| longitude | Geographic longitude |
| phone | Clinic contact number |

### 2.3 patients

Stores patient personal and medical information.

| Column | Description |
|---|---|
| patient_id | Primary key |
| full_name | Patient name |
| phone | Patient phone number |
| email | Patient email |
| dob | Date of birth |
| gender | Patient gender |
| blood_group | Patient blood group |
| allergies | Array of patient allergies |
| city_id | Foreign key referencing cities |
| created_at | Patient creation timestamp |

The `allergies` column uses a PostgreSQL text array so that allergy checks can use array operators.

### 2.4 doctors

Stores doctor profiles and professional information.

| Column | Description |
|---|---|
| doctor_id | Primary key |
| full_name | Doctor name |
| registration_no | Medical council registration number |
| gender | Doctor gender |
| experience_years | Years of experience |
| consultation_fee | In-clinic consultation fee |
| video_fee | Video consultation fee |
| languages | Array of languages spoken |
| is_verified | Doctor verification status |
| joined_on | Date the doctor joined |

The `languages` column uses a PostgreSQL text array to support language-based searches.

### 2.5 specializations

Stores available medical specializations.

| Column | Description |
|---|---|
| spec_id | Primary key |
| spec_name | Specialization name |

### 2.6 doctor_specializations

Implements the many-to-many relationship between doctors and specializations.

| Column | Description |
|---|---|
| doctor_id | Foreign key referencing doctors |
| spec_id | Foreign key referencing specializations |
| is_primary | Indicates the doctor's primary specialization |

The combination of `doctor_id` and `spec_id` identifies a doctor-specialization association.

### 2.7 doctor_schedules

Stores the weekly working schedules of doctors.

| Column | Description |
|---|---|
| doctor_id | Foreign key referencing doctors |
| weekday | Day of the week |
| start_time | Schedule start time |
| end_time | Schedule end time |
| clinic_id | Foreign key referencing clinics; nullable |
| slot_minutes | Duration of each appointment slot |

A doctor can have schedules at multiple clinics. A NULL `clinic_id` is allowed for video consultation schedules.

A generated schedule identifier can be used as the primary key because the supplied CSV does not contain a schedule ID.

### 2.8 appointments

Stores patient appointment and consultation information.

| Column | Description |
|---|---|
| appointment_id | Primary key |
| patient_id | Foreign key referencing patients |
| doctor_id | Foreign key referencing doctors |
| clinic_id | Foreign key referencing clinics |
| consult_type | Consultation type |
| booked_at | Appointment booking timestamp |
| slot_start | Appointment start timestamp |
| slot_end | Appointment end timestamp |
| reason | Reason for consultation |
| status | Appointment status |
| checked_in_at | Patient check-in timestamp |
| consult_started_at | Consultation start timestamp |
| consult_ended_at | Consultation end timestamp |
| fee | Appointment fee |
| payment_status | Payment status |

Each appointment is associated with one patient and one doctor. A patient and a doctor can each have multiple appointments.

### 2.9 prescriptions

Stores prescriptions issued during consultations.

| Column | Description |
|---|---|
| prescription_id | Primary key |
| appointment_id | Foreign key referencing appointments |
| diagnosis | Diagnosis information |
| notes | Prescription notes |
| follow_up_date | Recommended follow-up date |
| issued_at | Prescription issue timestamp |

### 2.10 prescription_items

Stores individual medicines included in a prescription.

| Column | Description |
|---|---|
| prescription_id | Foreign key referencing prescriptions |
| line_no | Item number within the prescription |
| medicine_name | Medicine name |
| dosage | Medicine dosage |
| duration_days | Number of days |
| instructions | Medicine instructions |

The combination of `prescription_id` and `line_no` identifies each prescription item.

### 2.11 doctor_reviews

Stores patient reviews of doctors after appointments.

| Column | Description |
|---|---|
| review_id | Primary key |
| appointment_id | Foreign key referencing appointments |
| rating | Rating given by the patient |
| recommends | Whether the patient recommends the doctor |
| wait_time_bucket | Waiting-time category |
| review_text | Written review |
| created_at | Review creation timestamp |

## 3. Relationships and Cardinality

| Relationship | Cardinality | Explanation |
|---|---|---|
| cities – clinics | One-to-many | One city can contain multiple clinics. |
| cities – patients | One-to-many | One city can be associated with multiple patients. |
| doctors – doctor_specializations | One-to-many | One doctor can have multiple specialization records. |
| specializations – doctor_specializations | One-to-many | One specialization can belong to multiple doctors. |
| doctors – doctor_schedules | One-to-many | One doctor can have multiple schedules. |
| clinics – doctor_schedules | One-to-many | One clinic can have multiple doctor schedules. |
| patients – appointments | One-to-many | One patient can book multiple appointments. |
| doctors – appointments | One-to-many | One doctor can receive multiple appointments. |
| clinics – appointments | One-to-many | One clinic can be associated with multiple appointments. |
| appointments – prescriptions | One-to-many | An appointment can have prescription records. |
| prescriptions – prescription_items | One-to-many | One prescription can contain multiple medicine items. |
| appointments – doctor_reviews | One-to-many | An appointment can have associated review records. |

The relationships are implemented using primary keys and foreign keys.

## 4. Important Design Decisions

1. **Many-to-many doctor specializations:** The `doctor_specializations` table separates doctors and specializations instead of storing multiple specializations in one doctor column.

2. **Multiple clinic schedules:** The `doctor_schedules` table allows doctors to work at multiple clinics.

3. **Video consultation schedules:** `doctor_schedules.clinic_id` is nullable because a video consultation schedule may not be linked to a physical clinic.

4. **Patient allergies:** The `patients.allergies` column uses a PostgreSQL array to support allergy checks, including the patient safety workload query.

5. **Doctor languages:** The `doctors.languages` column uses a PostgreSQL array to support searches for doctors speaking a particular language.

6. **Appointment timestamps:** Booking, slot, check-in, and consultation timestamps are stored separately to support appointment tracking and waiting-time analysis.

7. **Prescription details:** Prescription headers and medicine items are stored separately to support multiple medicines per prescription.

8. **Payment tracking:** Appointment fee and payment status are stored in the appointments table to support payment and revenue queries.

9. **Follow-up tracking:** The `follow_up_date` column in prescriptions supports follow-up analysis.

10. **Doctor verification:** The `is_verified` column supports searches for verified doctors.

## 5. Integrity Constraints

The following constraints should be applied in the SQL schema:

- Every table must have a primary key.
- Foreign keys must reference valid records in their parent tables.
- Doctor registration numbers should be unique when present.
- Patient email addresses should be unique when present.
- Ratings should be restricted to the valid rating range of 1 to 5.
- Experience years and consultation fees should not be negative.
- Slot duration should be positive.
- Appointment end time must be later than appointment start time.
- Prescription item line numbers should be unique within each prescription.
- Nullable fields must remain nullable where the supplied data and business requirements permit them.

## 6. Workload Support

The schema supports the existing workload categories:

- Doctor discovery by specialization, city, language, and verification.
- Doctor schedule and available-slot searches.
- Patient appointment history and appointment booking.
- Prescription and medicine searches.
- Patient allergy safety checks.
- Doctor ratings and recommendation analysis.
- Clinic performance and revenue analysis.
- Appointment status and payment updates.
- Follow-up appointment analysis.
- Aggregation and reporting using PostgreSQL window functions and date operations.

The existing workload queries should be preserved during schema implementation. Any query optimization must maintain the original query results.

## 7. Conclusion

The proposed relational schema separates the main entities into related tables and uses primary keys and foreign keys to maintain data integrity.

It supports the project's business requirements and the existing PostgreSQL workload while allowing doctors to work at multiple clinics, patients to book multiple appointments, and prescriptions to contain multiple medicine items.
