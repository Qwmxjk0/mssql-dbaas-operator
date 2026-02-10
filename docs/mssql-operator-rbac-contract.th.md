# MSSQL Operator RBAC Contract (Core-owned)

## 1) What is validated (tested) right now
- Operator `mssql-operator-mvp` ต้องใช้สิทธิ์ Kubernetes API เพื่อ reconcile CRD/Job/CronJob
- ทีม DBaaS ไม่เป็น owner RBAC ใน production

## 2) What is currently under testing
- ทดสอบว่า RBAC ที่ Core ให้เพียงพอสำหรับ backup + PITR flow
- ทดสอบ least-privilege (ไม่มีสิทธิ์เกินจำเป็น)

## 3) Known limitations / constraints
- หาก RBAC ไม่ครบ operator จะ fail ด้วย `Forbidden`
- หาก RBAC กว้างเกินไปจะไม่ผ่าน security baseline

## 4) Planned next tests / improvements
- เพิ่ม `kubectl auth can-i` check ใน pre-deploy pipeline
- เก็บ evidence ทุกครั้งก่อน release

## Required permissions (namespace scope)
ServiceAccount: `mssql-operator-mvp`
Namespace: `dbaas-mssql`

Resources/verbs ขั้นต่ำ:
- `mssqlbackuppolicies.dbaas.cozy.io`: `get,list,watch,patch,update`
- `mssqlbackups.dbaas.cozy.io`: `get,list,watch,create,patch,update`
- `mssqlrestorejobs.dbaas.cozy.io`: `get,list,watch,patch,update`
- `jobs.batch`: `get,list,watch,create,patch,update,delete`
- `cronjobs.batch`: `get,list,watch,create,patch,update,delete`

## Preflight commands
```bash
kubectl auth can-i list mssqlbackuppolicies.dbaas.cozy.io \
  --as=system:serviceaccount:dbaas-mssql:mssql-operator-mvp -n dbaas-mssql
kubectl auth can-i create cronjobs.batch \
  --as=system:serviceaccount:dbaas-mssql:mssql-operator-mvp -n dbaas-mssql
kubectl auth can-i create jobs.batch \
  --as=system:serviceaccount:dbaas-mssql:mssql-operator-mvp -n dbaas-mssql
kubectl auth can-i patch mssqlbackups.dbaas.cozy.io/status \
  --as=system:serviceaccount:dbaas-mssql:mssql-operator-mvp -n dbaas-mssql
kubectl auth can-i patch mssqlrestorejobs.dbaas.cozy.io/status \
  --as=system:serviceaccount:dbaas-mssql:mssql-operator-mvp -n dbaas-mssql
```
