# Runtime E2E Metrics and Go/No-Go

- run_at_utc: 2026-02-10T07:02:29Z
- target_time: 2026-02-10T06:54:34Z
- restore_request: rt-pitr-065639 (Completed)
- restore_job_cr: rt-pitr-065639-job (Completed)
- restore_k8s_job: mssqlr-rt-pitr-065639-job

## RPO
- last_log_before_target: db1_LOG_20260210065255.trn
- first_log_after_target: db1_LOG_20260210065500.trn
- rpo_gap_seconds (target - last_before): 99
- next_log_after_target_seconds: 26

## RTO
- request_created_at: 2026-02-10T06:56:39Z
- restore_job_start_at: 2026-02-10T06:56:58Z
- restore_job_complete_at: 2026-02-10T06:57:10Z
- rto_job_seconds (job start->complete): 12
- rto_e2e_seconds (request->complete): 31

## Go/No-Go
- decision: GO
- criteria: restore completed + data validation pass + RPO <= 300s
- note: RTO target 60s ต้องวัดแบบ event-driven path อีกครั้ง (รอบนี้มี manual reconcile assist)
