# MSSQL Core Migration Test Runbook

Status: Draft v2  
Date: 2026-02-10  
Scope: Validate Core-managed operator model with `mssql-helm` handover package.

## FACT / ASSUMPTION / UNKNOWN
FACT:
- `mssql-helm` supports MSSQL 2022 + `MSSQLInstance` bootstrap.
- Operator supports split ownership flags: `manageSourcePVC`, `manageBackupPVC`, `manageTargetPVC`.
- Default handover profile is Core-managed mode (`operator.enabled=false`).

ASSUMPTION:
- Core deploys and maintains the shared operator runtime and RBAC.
- Cluster has a working StorageClass for source/backup/target PVCs.

UNKNOWN:
- Production behavior under large concurrent tenant load (needs dedicated stress run).

## 1) Test Objective
- Verify no ownership conflict between Helm resources and operator-managed resources.
- Verify backup/log/PITR flow under Core-managed mode.
- Verify RPO objective with 5-minute log backup interval.

## 2) Ownership model
- Helm owner: StatefulSet, Service, Secret, source data PVC.
- Operator owner: `MSSQLBackupPolicy`, backup/log jobs, restore jobs, backup/target PVC.
- Core owner: operator Deployment, ServiceAccount, RBAC.

## 3) Preconditions
- Apply CRDs from:
- `./crd/`
- Core operator is running in target namespace.
- MSSQL SA password secret is present or provided through Helm values.
- Executor image includes required tooling (`sqlcmd`, backup/restore scripts).

## 4) Test matrix
| Case | Deployment Mode | Expected |
|---|---|---|
| C1 | Core-managed (`operator.enabled=false`) | Helm deploys MSSQL + `MSSQLInstance`; shared operator reconciles |
| C2 | Bundled mode (`operator.enabled=true`) | Self-contained lab deployment works |
| C3 | PITR restore | Restore to target instance completes and data validation passes |
| C4 | Ownership guard | No source PVC recreation attempt by operator |

## 5) Procedure
### Step A: Static checks
```bash
helm lint ./helm/mssql-helm
helm template mssql-src ./helm/mssql-helm -n dbaas-mssql > /tmp/mssql-helm-rendered.yaml
```

### Step B: Install Core-managed release
```bash
kubectl create ns dbaas-mssql --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install mssql-src ./helm/mssql-helm \
  -n dbaas-mssql \
  -f ./helm/mssql-helm/values-core-managed.yaml \
  --set mssql.auth.saPassword='ChangeThis!StrongP@ssw0rd' \
  --set mssql.persistence.storageClass=standard \
  --set autoBackup.logBackupIntervalMinutes=5
```

### Step C: Verify ownership and policy
```bash
kubectl -n dbaas-mssql get sts,svc,secret,pvc
kubectl -n dbaas-mssql get mssqlinstance,mssqlbackuppolicies,cronjobs
```
Checklist:
- [ ] Source PVC is created by StatefulSet.
- [ ] Backup/target PVC is managed by operator according to spec.
- [ ] No ownership conflict errors in operator logs.

### Step D: Backup and PITR validation
- Seed data into multiple DBs (`db1`, `db2`, `db3`).
- Trigger one full backup and at least two log backups.
- Submit PITR restore request with chosen target time.
- Validate data shape on target instance.

Reference flow:
- `./manual-e2e-lab.md`

## 6) Success criteria
- [ ] `MSSQLInstance.status.phase=Ready`
- [ ] `MSSQLBackupPolicy.status.phase=Ready`
- [ ] Backup jobs and restore jobs complete successfully
- [ ] PITR target data matches expected time window
- [ ] RPO measured <= 5 minutes
- [ ] No source PVC ownership conflict

## 7) Failure modes / troubleshooting
- Pending PVC: verify `storageClass`, capacity, and provisioner health.
- `policyRef not found`: verify policy name and namespace.
- Restore cannot find backup chain: verify full/log file continuity and timestamps.
- `Forbidden` errors: verify Core RBAC contract.

## 8) Evidence output
Minimum artifacts:
- cluster snapshot (`pods`, `crs`, `jobs`, `pvc`)
- backup and restore CR YAML status
- source/target validation query output
- go/no-go summary with RPO/RTO measurements

## 9) Go / No-Go
Go if all success criteria are met.
No-Go if any critical control fails (RBAC, backup chain, restore completion, data mismatch).

## 10) Rollback
- Roll back Helm release revision if deployment regression occurs.
- Keep source instance untouched during target validation window.
- Preserve failed restore artifacts for root-cause analysis before retest.
