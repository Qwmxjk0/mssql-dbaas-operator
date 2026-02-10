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
- Operator and executor images must be reachable by the cluster runtime (local load or internal registry)

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

## Image Pull Strategy (important)
Use one of these two modes before running PITR:

1. `kind/local lab` mode
- Build/load images into kind and force `pullPolicy=Never`
- Example:
```bash
kind load docker-image --name mssql-lab mssql-operator-mvp:rt-e2e3
kind load docker-image --name mssql-lab mssql-backup-executor:rt-e2e

helm upgrade --install mssql-src ./helm/mssql-helm \
  -n dbaas-mssql \
  -f ./helm/mssql-helm/values-bundled-operator.yaml \
  --set operator.image.repository=mssql-operator-mvp \
  --set operator.image.tag=rt-e2e3 \
  --set operator.image.pullPolicy=Never \
  --set operator.executor.image=mssql-backup-executor \
  --set operator.executor.tag=rt-e2e \
  --set operator.executor.pullPolicy=Never
```

2. `core/prod` internal registry mode (recommended)
- Push both images to internal registry and use immutable tags
- Suggested naming:
- `registry.internal/dbaas/mssql-operator-mvp:<version>`
- `registry.internal/dbaas/mssql-backup-executor:<version>`
- Example:
```bash
helm upgrade --install mssql-src ./helm/mssql-helm \
  -n dbaas-mssql \
  -f ./helm/mssql-helm/values-bundled-operator.yaml \
  --set operator.image.repository=registry.internal/dbaas/mssql-operator-mvp \
  --set operator.image.tag=v0.1.0 \
  --set operator.executor.image=registry.internal/dbaas/mssql-backup-executor \
  --set operator.executor.tag=v0.1.0
```
- Ensure image pull secret exists and is bound to service accounts used by operator and jobs.
- Example:
```bash
kubectl -n dbaas-mssql create secret docker-registry regcred \
  --docker-server=registry.internal \
  --docker-username=<user> \
  --docker-password=<password>

kubectl -n dbaas-mssql patch serviceaccount mssql-src-mssql-helm-operator \
  -p '{\"imagePullSecrets\":[{\"name\":\"regcred\"}]}'
kubectl -n dbaas-mssql patch serviceaccount default \
  -p '{\"imagePullSecrets\":[{\"name\":\"regcred\"}]}'
```

## Image Pull Preflight
```bash
kubectl -n dbaas-mssql get pods
kubectl -n dbaas-mssql describe pod -l app.kubernetes.io/component=operator
kubectl -n dbaas-mssql get events --sort-by=.metadata.creationTimestamp | tail -n 20
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
- `docs/mssql-operator-rbac-contract.th.md`
- `docs/mssql-core-migration-test-runbook.md`
- `docs/mssql-production-gates-checklist.md`
- `docs/ui-field-by-field-spec.md`
- `manual-e2e-lab.md`

## Evidence
- `tests/runtime-e2e-core-managed-local-pvc.md`
- `tests/metrics-go-no-go.md`
- `tests/source-validation.txt`
- `tests/target-validation.txt`
