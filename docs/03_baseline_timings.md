
# 03. Baseline Query Performance Analysis

## 1. Overview

This document records the baseline performance measurements of the Practo Doctor Appointments database.

The purpose of baseline benchmarking is to measure query execution performance before applying further query optimizations. These measurements provide a reference for comparing database performance after optimization.

## 2. Benchmark Environment

| Parameter | Value |
|---|---|
| Database | practo_db |
| Schema | practo |
| DBMS | PostgreSQL |
| Workload file | queries/workload_30.sql |
| Total queries | 30 |
| Read queries | 25 |
| Write queries | 5 |
| Runs per query | 3 |
| Query analysis | EXPLAIN (ANALYZE, BUFFERS) |
| Benchmark phase | before |

Write queries are executed inside transactions and rolled back to avoid permanently modifying the database during benchmarking.

## 3. Baseline Benchmark Results

Execution times are measured in milliseconds (ms).

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Median (ms) | Min (ms) | Max (ms) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| R01 | Read | 2.971 | 2.111 | 1.789 | 2.290 | 2.111 | 1.789 | 2.971 |
| R02 | Read | 0.287 | 0.280 | 0.257 | 0.275 | 0.280 | 0.257 | 0.287 |
| R03 | Read | 0.452 | 0.237 | 0.220 | 0.303 | 0.237 | 0.220 | 0.452 |
| R04 | Read | 0.166 | 0.103 | 0.100 | 0.123 | 0.103 | 0.100 | 0.166 |
| R05 | Read | 0.672 | 0.265 | 0.285 | 0.407 | 0.285 | 0.265 | 0.672 |
| R06 | Read | 2.190 | 1.877 | 1.808 | 1.958 | 1.877 | 1.808 | 2.190 |
| R07 | Read | 0.099 | 0.052 | 0.047 | 0.066 | 0.052 | 0.047 | 0.099 |
| R08 | Read | 24.002 | 20.823 | 20.681 | 21.835 | 20.823 | 20.681 | 24.002 |
| R09 | Read | 2.593 | 2.473 | 2.414 | 2.493 | 2.473 | 2.414 | 2.593 |
| R10 | Read | 18.900 | 16.558 | 16.829 | 17.429 | 16.829 | 16.558 | 18.900 |
| R11 | Read | 1.719 | 1.245 | 1.120 | 1.361 | 1.245 | 1.120 | 1.719 |
| R12 | Read | 23.140 | 23.004 | 23.336 | 23.160 | 23.140 | 23.004 | 23.336 |
| R13 | Read | 2.632 | 2.614 | 2.712 | 2.653 | 2.632 | 2.614 | 2.712 |
| R14 | Read | 19.041 | 18.575 | 18.621 | 18.746 | 18.621 | 18.575 | 19.041 |
| R15 | Read | 23.271 | 21.543 | 21.035 | 21.950 | 21.543 | 21.035 | 23.271 |
| R16 | Read | 2.611 | 2.495 | 2.528 | 2.545 | 2.528 | 2.495 | 2.611 |
| R17 | Read | 35.132 | 34.286 | 34.330 | 34.583 | 34.330 | 34.286 | 35.132 |
| R18 | Read | 3.983 | 3.730 | 3.650 | 3.788 | 3.730 | 3.650 | 3.983 |
| R19 | Read | 13.783 | 13.325 | 12.684 | 13.264 | 13.325 | 12.684 | 13.783 |
| R20 | Read | 6.658 | 4.852 | 5.052 | 5.521 | 5.052 | 4.852 | 6.658 |
| R21 | Read | 0.570 | 0.423 | 0.404 | 0.466 | 0.423 | 0.404 | 0.570 |
| R22 | Read | 7.059 | 6.228 | 6.164 | 6.484 | 6.228 | 6.164 | 7.059 |
| R23 | Read | 0.041 | 0.027 | 0.026 | 0.031 | 0.027 | 0.026 | 0.041 |
| R24 | Read | 21.824 | 21.983 | 22.045 | 21.951 | 21.983 | 21.824 | 22.045 |
| R25 | Read | 13.828 | 14.277 | 13.984 | 14.030 | 13.984 | 13.828 | 14.277 |
| W01 | Write | 0.892 | 0.599 | 0.562 | 0.684 | 0.599 | 0.562 | 0.892 |
| W02 | Write | 0.399 | 0.224 | 0.184 | 0.269 | 0.224 | 0.184 | 0.399 |
| W03 | Write | 0.155 | 0.138 | 0.134 | 0.142 | 0.138 | 0.134 | 0.155 |
| W04 | Write | 13.733 | 3.193 | 4.142 | 7.023 | 4.142 | 3.193 | 13.733 |
| W05 | Write | 0.239 | 0.204 | 0.204 | 0.216 | 0.204 | 0.204 | 0.239 |


## 4. Query Execution Plan Observations

The benchmark records execution plans and scan operations for each query.

1. **Sequential scans:** Queries R08, R10, R12, R14, R15, R17, R18, R19, and R24 contain sequential scans on one or more tables.

2. **Index scans:** Several queries use indexes, including R07, R09, R11, R20, R21, R22, and R23.

3. **Bitmap scans:** Queries R01, R03, R04, R05, R13, and R19 use bitmap scans for some table accesses.

4. **Index-only scans:** Queries R17, R20, R22, and R25 use index-only scans for at least one table access.

5. **Write operations:** W01, W02, W03, and W05 have relatively low execution times, while W04 has a higher average execution time.

## 5. Queries Requiring Further Investigation

Based on average execution time, the following read queries are among the slower queries in the baseline:

| Query | Average Execution Time (ms) |
|---|---:|
| R17 | 34.583 |
| R12 | 23.160 |
| R24 | 21.951 |
| R15 | 21.950 |
| R08 | 21.835 |
| R14 | 18.746 |
| R10 | 17.429 |
| R25 | 14.030 |
| R19 | 13.264 |

These queries should be examined further using their execution plans to identify possible optimization opportunities.

Write query W04 also deserves attention because its average execution time is 7.023 ms.

## 6. Benchmark Methodology

The benchmark was executed using:

`bash benchmarks/run_benchmark.sh practo_db before 3`

The script:

- Splits the workload into individual queries using query markers.
- Executes each query three times.
- Uses EXPLAIN (ANALYZE, BUFFERS) to inspect execution plans.
- Records execution times and scan-node information.
- Saves individual query plans and a consolidated summary.csv file.

The results are stored in `benchmarks/results/before/`.

The summary file contains 31 lines: one header and 30 query records.

## 7. Conclusion

The baseline benchmark establishes a performance reference for all 30 workload queries.

The results show that query execution times vary significantly. Some queries complete in less than one millisecond, while several read queries take more than 10 milliseconds.

The execution plans provide useful information about sequential scans, index scans, bitmap scans, and index-only scans.

Further optimization should focus on queries with higher execution times while preserving the original query results and database integrity.

The same workload and benchmarking methodology should be used after optimization to make the before-and-after comparison meaningful.