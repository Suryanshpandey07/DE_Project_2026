# AP Query Execution Timings

## Methodology

- Database: PostgreSQL.
- Dataset and query workload: the project's baseline benchmark.
- Each query was executed three times.
- Execution times are taken from PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` output.
- Average is calculated from the three recorded execution times.
- Scan operations are taken from the recorded execution plans.
- Write queries are executed inside a transaction and rolled back.

## Results

| Query | Type | What it does | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type(s) |
|---|---|---|---:|---:|---:|---:|---|
| R01 | READ | Find a doctor: verified dermatologists practising in Bengaluru, most experienced first | 2.971 | 2.111 | 1.789 | 2.290 | Seq Scan on doctor_specializations ; Seq Scan on specializations ; Index Scan using doctors_pkey on doctors ; Index Scan using idx_doctor_schedules_doctor on doctor_schedules ; Bitmap Heap Scan on clinics ; Bitmap Index Scan on idx_clinics_city |
| R02 | READ | Doctor profile: doctor 217's weekly timetable with clinic names | 0.287 | 0.280 | 0.257 | 0.275 | Index Scan using idx_doctor_schedules_doctor on doctor_schedules ; Seq Scan on clinics |
| R03 | READ | Slot picker: doctor 217's free in-clinic slots on Friday 3 July 2026 | 0.452 | 0.237 | 0.220 | 0.303 | Index Scan using idx_doctor_schedules_doctor on doctor_schedules ; Bitmap Heap Scan on appointments ; Bitmap Index Scan on idx_appointments_doctor_slot |
| R04 | READ | "My appointments": patient 90's upcoming appointments | 0.166 | 0.103 | 0.100 | 0.123 | Bitmap Heap Scan on appointments ; Bitmap Index Scan on idx_appointments_patient_slot ; Index Scan using doctors_pkey on doctors ; Index Scan using clinics_pkey on clinics |
| R05 | READ | Doctor's queue: doctor 16's appointments on 30 June 2026 | 0.672 | 0.265 | 0.285 | 0.407 | Bitmap Heap Scan on appointments ; Bitmap Index Scan on idx_appointments_doctor_slot ; Index Scan using patients_pkey on patients |
| R06 | READ | Sign-in with mobile number | 2.190 | 1.877 | 1.808 | 1.958 | Seq Scan on patients |
| R07 | READ | Prescription view: the prescription and medicines of appointment 18872 | 0.099 | 0.052 | 0.047 | 0.066 | Index Scan using idx_prescriptions_appointment on prescriptions ; Index Scan using prescription_items_pkey on prescription_items |
| R08 | READ | Quality: no-show rate per specialization in 2026 | 24.002 | 20.823 | 20.681 | 21.835 | Seq Scan on appointments ; Seq Scan on doctor_specializations ; Index Scan using specializations_pkey on specializations |
| R09 | READ | Clinic experience: average minutes patients waited after their slot time, per clinic (June 2026) | 2.593 | 2.473 | 2.414 | 2.493 | Index Scan using idx_appointments_slot_covering on appointments |
| R10 | READ | Patient safety: patients allergic to penicillin who were prescribed amoxicillin | 18.900 | 16.558 | 16.829 | 17.429 | Seq Scan on appointments ; Seq Scan on patients ; Index Scan using idx_prescriptions_appointment on prescriptions ; Index Scan using prescription_items_pkey on prescription_items |
| R11 | READ | Care team: follow-ups due in the first week of July 2026 that the patient has not booked yet | 1.719 | 1.245 | 1.120 | 1.361 | Index Scan using idx_prescriptions_follow_up on prescriptions ; Index Scan using appointments_pkey on appointments ; Index Scan using idx_appointments_patient_slot on appointments |
| R12 | READ | Product analytics: video vs in-clinic appointments per month in 2026 | 23.140 | 23.004 | 23.336 | 23.160 | Seq Scan on appointments |
| R13 | READ | Clinic partnerships: clinics where no doctor has any schedule | 2.632 | 2.614 | 2.712 | 2.653 | Seq Scan on clinics ; Seq Scan on doctor_schedules |
| R14 | READ | Doctor ranking: average rating and recommendation rate (at least 10 reviews) | 19.041 | 18.575 | 18.621 | 18.746 | Seq Scan on appointments ; Seq Scan on doctor_reviews |
| R15 | READ | Pharmacy partners: most prescribed medicines per primary specialization in June 2026 | 23.271 | 21.543 | 21.035 | 21.950 | Seq Scan on appointments ; Seq Scan on prescription_items ; Seq Scan on prescriptions ; Seq Scan on doctor_specializations ; Seq Scan on specializations |
| R16 | READ | Finance: fees collected per clinic in June 2026 | 2.611 | 2.495 | 2.528 | 2.545 | Index Scan using idx_appointments_slot_covering on appointments ; Seq Scan on clinics |
| R17 | READ | Population health: completed appointments by patient age group and blood group (2026) | 35.132 | 34.286 | 34.330 | 34.583 | Index Only Scan using idx_appointments_completed_slot_patient on appointments ; Seq Scan on patients |
| R18 | READ | Search filter: Tamil-speaking doctors with Chennai clinics | 3.983 | 3.730 | 3.650 | 3.788 | Seq Scan on doctor_schedules ; Seq Scan on doctors ; Bitmap Heap Scan on clinics ; Bitmap Index Scan on idx_clinics_city |
| R19 | READ | City report: June 2026 completed consultations and latest consultation of every doctor with a Bengaluru clinic | 13.783 | 13.325 | 12.684 | 13.264 | Seq Scan on doctor_schedules ; Bitmap Heap Scan on clinics ; Bitmap Index Scan on idx_clinics_city ; Seq Scan on doctors ; Bitmap Heap Scan on appointments ; Bitmap Index Scan on idx_appointments_doctor_slot |
| R20 | READ | Platform analytics: completed appointments per day and running total, June 2026 | 6.658 | 4.852 | 5.052 | 5.521 | Index Only Scan using idx_appointments_completed_slot_patient on appointments |
| R21 | READ | Finance: completed in-clinic consultations whose fee is still unpaid | 0.570 | 0.423 | 0.404 | 0.466 | Index Scan using idx_appointments_slot_covering on appointments |
| R22 | READ | Support console: all appointments, newest first, page 4,001 (25 per page) | 7.059 | 6.228 | 6.164 | 6.484 | Index Only Scan using idx_appointments_slot_covering on appointments |
| R23 | READ | Verification team: look up a doctor by medical council registration number | 0.041 | 0.027 | 0.026 | 0.031 | Index Scan using idx_doctors_registration_unique on doctors |
| R24 | READ | Data quality: two active appointments of the same doctor in the same slot (double bookings) | 21.824 | 21.983 | 22.045 | 21.951 | Seq Scan on appointments |
| R25 | READ | Care quality: patients who saw 3 or more different doctors of the same specialization in 2026 | 13.828 | 14.277 | 13.984 | 14.030 | Index Only Scan using idx_appointments_slot_covering on appointments ; Seq Scan on doctor_specializations |
| W01 | WRITE | Book: patient 90 books doctor 217's 10:30 slot on Friday 3 July 2026 | 0.892 | 0.599 | 0.562 | 0.684 | Index Scan using idx_doctor_schedules_doctor on doctor_schedules ; Index Scan using doctors_pkey on doctors |
| W02 | WRITE | Reception: check in the earliest BOOKED in-clinic appointment of 1 July 2026 | 0.399 | 0.224 | 0.184 | 0.269 | Index Scan using idx_appointments_slot_covering on appointments ; Index Scan using appointments_pkey on appointments |
| W03 | WRITE | Doctor: add notes and a follow-up date to the prescription of appointment 18872 | 0.155 | 0.138 | 0.134 | 0.142 | Index Scan using idx_prescriptions_appointment on prescriptions |
| W04 | WRITE | Nightly job (run at 00:00 on 2 July 2026): BOOKED appointments whose slot has ended become NO_SHOW | 13.733 | 3.193 | 4.142 | 7.023 | Bitmap Heap Scan on appointments ; Bitmap Index Scan on idx_appointments_status |
| W05 | WRITE | Doctor on leave: cancel and refund all of doctor 504's appointments on 3 July 2026 | 0.239 | 0.204 | 0.204 | 0.216 | Index Scan using idx_appointments_doctor_slot on appointments |

## Raw Execution Plans

The `plans/` directory contains the original baseline EXPLAIN output for all 30 queries. Each file includes all three recorded runs.
