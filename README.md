# MSSQL DBaaS Core Handover Package

Release date: 2026-02-10  
Package path: `.`

This repository is prepared for Core team handover in a CNPG-style operator model:
- tenant/user config is declared once at instance creation
- operator reconciles backup/log/PITR resources continuously
- Core team owns platform RBAC and shared operator runtime

## 1) Validated and tested
- CRDs for `MSSQLInstance`, `MSSQLBackupPolicy`, `MSSQLBackup`, `MSSQLRestoreRequest`, `MSSQLRestoreJob`
- Helm chart `helm/mssql-helm` for source/target MSSQL deployment
- Runtime E2E evidence for backup + PITR in `local_pvc` mode
- Manual E2E walkthrough (steps 0-12) in `manual-e2e-lab.md`

## 2) In progress
- One-click restore with automatic target instance provisioning
- Additional production soak/performance tests under concurrent tenants

## 3) Known limitations
- Current PITR flow expects target MSSQL instance to exist before restore request
- RTO 1-minute target still requires repeated measurements in production-like load
- Core-managed RBAC must be provided before operator reconciliation can run successfully

## 4) Planned next tests
- High-concurrency backup/restore stress test
- Failure-injection tests (node restart, pod restart, PVC pressure)
- Upgrade/rollback rehearsal with data-consistency checks

## Package layout
- `crd/`: all required CRDs
- `helm/mssql-helm/`: deployment chart
- `docs/`: architecture contract, runbooks, UI mapping, production gates
- `tests/`: latest runtime evidence and metrics
- `manual-e2e-lab.md`: copy/paste manual validation flow

## Quick start (Core-managed)
```bash
kubectl apply -f ./crd/mssqlinstance-crd.yaml
kubectl apply -f ./crd/mssqlbackuppolicy-crd.yaml
kubectl apply -f ./crd/mssqlbackup-crd.yaml
kubectl apply -f ./crd/mssqlrestorerequest-crd.yaml
kubectl apply -f ./crd/mssqlrestorejob-crd.yaml

helm upgrade --install mssql-src ./helm/mssql-helm \
  -n dbaas-mssql \
  -f ./helm/mssql-helm/values-core-managed.yaml \
  --set mssql.image.tag=2022-latest \
  --set mssql.persistence.storageClass=standard
```

## Required tenant inputs
- namespace
- instance/release name
- storageClass
- dataSizeGi
- backupSizeGi
- retentionDays (1..30)
- logBackupIntervalMinutes (set `5` for RPO 5m objective)
- fullBackupSchedule (cron)
- sa password secret name/key

## Key documents
- `docs/README.md`
- `docs/MSSQL-operator-rbac-contract-th.md`
- `docs/MSSQL-Core-Migration-Test-Runbook.md`
- `docs/MSSQL-production-gates-checklist.md`
- `docs/UI-Field-by-Field-Spec.md`
- `manual-e2e-lab.md`

## Evidence
- `tests/16-runtime-e2e-core-managed-localpvc-run.md`
- `tests/07-metrics-go-no-go.md`
- `tests/06a-source-validation.txt`
- `tests/06b-target-validation.txt`
