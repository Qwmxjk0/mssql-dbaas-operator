# mssql-helm Chart

This chart packages:
- MSSQL engine (`mcr.microsoft.com/mssql/server:2022-latest`)
- Optional bundled operator (`mssql-operator-mvp`)
- `MSSQLInstance` CR bootstrap for backup/log/PITR automation

## Prerequisites
- Kubernetes cluster
- CRDs applied first:
  - `./crd/mssqlinstance-crd.yaml`
  - `./crd/mssqlbackuppolicy-crd.yaml`
  - `./crd/mssqlbackup-crd.yaml`
  - `./crd/mssqlrestorerequest-crd.yaml`
  - `./crd/mssqlrestorejob-crd.yaml`

## Mode A: Core-managed operator (recommended for production)
```bash
helm upgrade --install mssql-src ./helm/mssql-helm \
  -n dbaas-mssql \
  -f ./helm/mssql-helm/values-core-managed.yaml \
  --set mssql.auth.saPassword='ChangeThis!StrongP@ssw0rd' \
  --set mssql.persistence.storageClass=standard \
  --set mssql.image.tag=2022-latest
```

## Mode B: Bundled operator (dev/lab only)
```bash
helm upgrade --install mssql-src ./helm/mssql-helm \
  -n dbaas-mssql \
  -f ./helm/mssql-helm/values-bundled-operator.yaml \
  --set mssql.auth.saPassword='ChangeThis!StrongP@ssw0rd' \
  --set mssql.persistence.storageClass=standard \
  --set operator.image.repository=mssql-operator-mvp \
  --set operator.image.tag=latest \
  --set operator.executor.image=mssql-backup-executor \
  --set operator.executor.tag=latest
```

## Image Pull Reliability
If operator pod is `ImagePullBackOff`, use one of these patterns:

1. `kind/local`:
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

2. `internal registry` (production path):
```bash
helm upgrade --install mssql-src ./helm/mssql-helm \
  -n dbaas-mssql \
  -f ./helm/mssql-helm/values-bundled-operator.yaml \
  --set operator.image.repository=registry.internal/dbaas/mssql-operator-mvp \
  --set operator.image.tag=v0.1.0 \
  --set operator.executor.image=registry.internal/dbaas/mssql-backup-executor \
  --set operator.executor.tag=v0.1.0
```
Then configure image pull secrets for the namespace/service accounts:
```bash
kubectl -n dbaas-mssql create secret docker-registry regcred \
  --docker-server=registry.internal \
  --docker-username=<user> \
  --docker-password=<password>

kubectl -n dbaas-mssql patch serviceaccount mssql-src-mssql-helm-operator \
  -p '{"imagePullSecrets":[{"name":"regcred"}]}'
kubectl -n dbaas-mssql patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"regcred"}]}'
```

## Key values
- `mssql.image.tag`: MSSQL engine tag (recommend `2022-latest`)
- `mssql.persistence.storageClass`: source data storage class
- `autoBackup.enabled`: enable/disable backup policy bootstrap
- `autoBackup.logBackupIntervalMinutes`: set `5` for RPO 5m objective
- `autoBackup.fullBackupSchedule`: full backup cron schedule
- `autoBackup.retentionDays`: retention window (`1..30`)
- `autoBackup.mode`: `local_pvc` / `native_url` / `disk_then_upload`
- `autoBackup.storage.manageSourcePVC`: usually `false` (Helm owns source PVC)
- `autoBackup.storage.manageBackupPVC`: usually `true` (operator owns backup PVC)
- `autoBackup.storage.manageTargetPVC`: usually `true` (operator owns target PVC)

## Validation commands
```bash
kubectl -n dbaas-mssql get sts,svc,pods
kubectl -n dbaas-mssql get mssqlinstance,mssqlbackuppolicies,cronjobs,mssqlbackups
kubectl -n dbaas-mssql get pvc
kubectl -n dbaas-mssql describe pod -l app.kubernetes.io/component=operator
```

## Notes
- `local_pvc` mode does not require external S3
- `native_url`/`disk_then_upload` requires destination config (`autoBackup.destination.*`)
- Full manual E2E flow is documented in:
  - `./manual-e2e-lab.md`
