# Test Run — Runtime E2E (Core-managed Helm + Operator, local_pvc)

วันที่: 2026-02-10
ประเภท: Non-dry-run e2e
Cluster: `kind-seaweed-ext`
Namespace: `dbaas-mssql-rt`

## 1) Test Objective
- พิสูจน์ runtime flow จริงตาม runbook:
- multi-DB workload (`db1`,`db2`,`db3`)
- full + log backup จริง
- PITR ไป new instance
- วัด `RPO`/`RTO` จาก timestamp จริง

## 2) Minimal Architecture / Design
- Source release: `mssql-rt` (MSSQL 2022 + `MSSQLInstance` + operator)
- Target release: `mssql-rt-target` (MSSQL 2022, ไม่มี autoBackup)
- Backup mode: `local_pvc`
- Storage:
- source data PVC: StatefulSet (`data-mssql-rt-mssql-helm-db-0`)
- backup PVC: `mssql-rt-mssql-helm-instance-backup-store`
- target data PVC: `data-mssql-rt-target-mssql-helm-db-0`
- Executor image: `mssql-backup-executor:rt-e2e`

## 3) FACT / ASSUMPTION / UNKNOWN
FACT:
- backup/restore runtime ผ่านจริงแบบ non-dry-run
- PITR restore ไป target instance สำเร็จ (`Completed`)
- data validation ผ่าน:
- Source: `seed=1, wave1=1, wave2=1`
- Target: `seed=1, wave1=1, wave2=0`
- Metric จาก evidence:
- `RPO gap = 99s` (ผ่านเป้า `<= 5m`)
- `RTO job = 12s`
- `RTO e2e (request->complete) = 31s`

ASSUMPTION:
- การทดสอบนี้เป็น representative สำหรับ single-node kind และ storage class `standard`

UNKNOWN:
- behavior ภายใต้ multi-node + production storage backend จริง
- long-run stability/chaos (node restart, network drop, pvc detach)

## 4) Defects Found During Run and Fixes
1. Defect: backup job ใช้ image ที่ไม่มี `sqlcmd` ใน `PATH`
- Impact: `sqlcmd: not found`
- Fix: ใช้ executor image ภายใน `mssql-backup-executor:rt-e2e`

2. Defect: `local_pvc` backup path ไม่ถูกต้อง (สั่ง SQL backup ไป `/backup-store` โดยตรง)
- Impact: SQL Server เขียนไฟล์ไม่ได้ (`Access is denied`)
- Fix ใน operator:
- backup: เขียนที่ `/var/opt/mssql/backup-mssql` แล้ว copy ไป `/backup-store`
- restore: copy จาก `/backup-store` ไป `/var/opt/mssql/restore-staging` แล้ว `RESTORE ... FROM DISK`

## 5) Step-by-step (Executed)
1. Seed ข้อมูลใน `db1/db2/db3` (`phase=seed`)
2. Trigger `MSSQLBackup(full)` สำเร็จ
3. Insert `wave1`
4. Trigger `MSSQLBackup(log)` รอบที่ 1
5. กำหนด `targetTime=2026-02-10T06:54:34Z`
6. Insert `wave2` (หลัง targetTime)
7. Trigger `MSSQLBackup(log)` รอบที่ 2
8. Deploy target instance (`mssql-rt-target`)
9. ส่ง `MSSQLRestoreRequest` -> ได้ `MSSQLRestoreJob` และ K8s restore job
10. Validate data บน target

## 6) Success Criteria + Metrics
- [x] Full backup สำเร็จ
- [x] Log backup สำเร็จอย่างน้อย 2 รอบ
- [x] Restore request/job สำเร็จ
- [x] Target DB `ONLINE`
- [x] Data validation ผ่าน (wave2 ไม่ถูก restore)
- [x] `RPO <= 5m` (จริง = 99s)

Metrics อ้างอิง:
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/07-metrics-go-no-go.md`

## 7) Evidence Artifacts
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/04g-full-backup-final.txt`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/04i-log1-backup.txt`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/04l-log2-backup.txt`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/05b-restore-request-run.txt`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/05d-restore-job-log.txt`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/05g-backup-store-files.txt`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/06a-source-validation.txt`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/06b-target-validation.txt`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/07-metrics-go-no-go.md`
- `docs/mssql/tests/artifacts/core-migration-20260210-runtime/08-cleanup-after-run.txt`

## 8) Go / No-Go
- Decision: `GO` สำหรับ scope นี้ (runtime local_pvc e2e + RPO target 5 นาที)
- หมายเหตุ:
- รอบนี้มี manual reconcile assist เพื่อปิด status เร็วขึ้นในเทสต์
- production cutover ต้องยืนยัน behavior เดียวกันภายใต้ Core operator deployment จริง (ไม่มี manual assist)

## 9) Cleanup Status
หลังทดสอบ:
- ลบ `MSSQLBackup`, `MSSQLRestoreRequest`, `MSSQLRestoreJob`, one-shot jobs/pods ที่เป็น temporary แล้ว
- คงไว้เฉพาะ source/target instance + backup policy/cronjobs เพื่อใช้งานต่อ
