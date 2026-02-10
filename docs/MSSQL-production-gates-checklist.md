# MSSQL Production Gates Checklist

Status: Release gate checklist for Core handover

## 1) Validated and tested now
- [ ] CRDs installed and version-locked in cluster
- [ ] Helm chart deploys source MSSQL instance successfully
- [ ] `MSSQLInstance` reconciles to `Ready`
- [ ] `MSSQLBackupPolicy` reconciles to `Ready`
- [ ] Manual `full` and `log` backup CRs complete successfully
- [ ] PITR restore request completes to target instance
- [ ] Data validation confirms target matches expected targetTime window

## 2) In-progress tests
- [ ] Multi-tenant concurrency test (N instances in parallel)
- [ ] Long-run soak test (>=24h with periodic log backups)
- [ ] Failure-injection test (operator restart, pod eviction, node restart)

## 3) Known constraints
- [ ] Target instance must exist before PITR restore request
- [ ] Core-managed RBAC is mandatory for operator reconciliation
- [ ] RTO 1-minute objective must be validated in production-like workload

## 4) Planned next improvements
- [ ] One-click restore with auto target provisioning
- [ ] Automated e2e pipeline in CI for each release tag
- [ ] Backup integrity verification job (checksum + restore smoke)

## Pre-Go-Live technical gates
- [ ] RBAC preflight passes (`kubectl auth can-i`) for operator service account
- [ ] StorageClass for source/backup/target PVC is available and healthy
- [ ] Image tags pinned (no floating tag in production)
- [ ] Resource limits/requests set for MSSQL + operator + executor jobs
- [ ] Alerting configured for failed cronjobs and failed restore jobs
- [ ] Runbook validated by a second engineer (peer validation)

## Evidence artifacts required
- [ ] `tests/07-metrics-go-no-go.md` updated for current run
- [ ] Source/target data validation outputs attached
- [ ] `kubectl get` snapshots attached (pods, crds, crs, jobs, pvc)
- [ ] Operator logs for backup + restore windows attached

## Go/No-Go decision
- Go only if all mandatory gates above are checked.
- No-Go if any critical gate fails (RBAC, backup failure, restore failure, data mismatch).
