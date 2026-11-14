# Practo Doctor Appointments Database – Problem Understanding

## 1. Project Overview

The Practo Doctor Appointments Database manages doctor discovery, patient appointments, clinic schedules, consultations, prescriptions, and reviews. The objective is to build a reliable database that supports efficient appointment management and accurate reporting.

## 2. Business Problems and Stakeholders

| Problem | Business Requirement | Stakeholders | Classification |
|---|---|---|---|
| P1 – Doctor Search and Slot Picker | Search doctors by specialization, city, and language, view profiles, and find available appointment slots. | Patients, Doctors | Customer-facing / Real-time |
| P2 – Appointments and Prescriptions | Support appointment booking, patient sign-in, appointment history, and prescription access. | Patients, Support Team | Customer-facing / Real-time |
| P3 – Clinic Reception | Display doctor queues and allow reception staff to check patients in. | Reception Staff, Doctors | Customer-facing / Real-time |
| P4 – Patient Safety | Identify allergy conflicts, missed follow-ups, and patients consulting multiple doctors for related conditions. | Patients, Care Team | Customer-facing / Real-time |
| P5 – Clinic Partnerships | Identify clinics that do not have doctor schedules. | Clinic Partnerships Team | Reporting / Analytics |
| P6 – Quality Reports | Generate reports on no-shows, waiting times, doctor ratings, and double bookings. | Quality Team, Clinic Management | Reporting / Analytics |
| P7 – Finance and Population Health | Support financial, pharmacy, and population-health reports and future growth. | Finance Team, Pharmacy Partners, Management | Reporting / Analytics |

## 3. Assumptions

1. A patient can book multiple appointments.
2. A doctor can work at multiple clinics.
3. Doctors can have multiple specializations.
4. Each appointment is associated with one patient and one doctor.
5. Consultations may include prescriptions.
6. Patient allergy information must be available for safety checks.
7. Appointment records must preserve accurate timestamps and payment details.
8. PostgreSQL will be used as the database management system.
9. Query optimization must preserve the original query results.

## 4. Expected Outcome

The project aims to build a normalized, reliable, and efficient database that supports appointment management, patient safety, fast queries, analytical reporting, and future scalability.
