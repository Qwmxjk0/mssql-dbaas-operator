# Manual E2E Lab (0-12)

เอกสารนี้เป็นคู่มือทดสอบแบบ manual สำหรับรันบนคลัสเตอร์ใหม่ โดยใช้ไฟล์ส่งมอบที่:
`.`

## 0) Prerequisite

```bash
kind version
kubectl version --client
helm version
docker version
```

## 1) สร้างคลัสเตอร์ใหม่

```bash
kind create cluster --name mssql-lab
kubectl config use-context kind-mssql-lab
kubectl get nodes
kubectl get storageclass
```

## 2) สร้าง namespace

```bash
kubectl create ns dbaas-mssql
```

## 3) ลง CRD (ครั้งเดียวต่อคลัสเตอร์)

```bash
kubectl apply -f ./crd/mssqlinstance-crd.yaml
kubectl apply -f ./crd/mssqlbackuppolicy-crd.yaml
kubectl apply -f ./crd/mssqlbackup-crd.yaml
kubectl apply -f ./crd/mssqlrestorerequest-crd.yaml
kubectl apply -f ./crd/mssqlrestorejob-crd.yaml
kubectl get crd | rg mssql
```

## 4) ลง operator (แบบผู้ทดสอบ)

วิธีง่ายสุด: ใช้ Helm แบบ bundled operator

```bash
helm upgrade --install mssql-src ./helm/mssql-helm \
  -n dbaas-mssql \
  -f ./helm/mssql-helm/values-bundled-operator.yaml \
  --set mssql.image.tag=2022-latest \
  --set mssql.auth.saPassword='Dummy!Passw0rd' \
  --set mssql.persistence.storageClass=standard \
  --set operator.image.repository=mssql-operator-mvp \
  --set operator.image.tag=rt-e2e3 \
  --set operator.executor.image=mssql-backup-executor \
  --set operator.executor.tag=rt-e2e
```

## 5) รอ source พร้อม

```bash
kubectl -n dbaas-mssql get pods,sts,svc
kubectl -n dbaas-mssql get mssqlinstance,mssqlbackuppolicies,cronjobs,pvc
```

ต้องเห็น:
- Pod MSSQL = `Running`
- Pod operator = `Running`
- มี `MSSQLInstance` และ `MSSQLBackupPolicy` ถูกสร้างแล้ว

## 6) Insert data ฝั่ง source

```bash
kubectl -n dbaas-mssql run sqlcmd-seed --image=mcr.microsoft.com/mssql-tools:latest --restart=Never --rm -i --command -- /bin/bash -lc '
for DB in db1 db2 db3; do
  /opt/mssql-tools/bin/sqlcmd -S mssql-src-mssql-helm-db,1433 -U sa -P "Dummy!Passw0rd" -Q "IF DB_ID('"'$DB'"') IS NULL CREATE DATABASE [$DB];";
  /opt/mssql-tools/bin/sqlcmd -S mssql-src-mssql-helm-db,1433 -U sa -P "Dummy!Passw0rd" -Q "USE [$DB]; IF OBJECT_ID('\''dbo.pitr_orders'\'','\''U'\'') IS NULL CREATE TABLE dbo.pitr_orders(id INT IDENTITY(1,1), phase NVARCHAR(32), marker NVARCHAR(64), created_at DATETIME2 DEFAULT SYSUTCDATETIME()); INSERT INTO dbo.pitr_orders(phase,marker) VALUES('\''seed'\'','\''$DB-seed-001'\'');";
done
'
```

## 7) Trigger full backup (manual 1 รอบ)

```bash
cat <<'EOFYAML' | kubectl -n dbaas-mssql apply -f -
apiVersion: dbaas.cozy.io/v1alpha1
kind: MSSQLBackup
metadata:
  name: src-full-1
spec:
  policyRef:
    name: mssql-src-mssql-helm-instance-backup-policy
  backupType: full
  databases: ["db1","db2","db3"]
  requestedAt: "2026-02-10T00:00:00Z"
EOFYAML

kubectl -n dbaas-mssql get mssqlbackup src-full-1 -w
```

## 8) Insert wave1 แล้ว trigger log

```bash
kubectl -n dbaas-mssql run sqlcmd-wave1 --image=mcr.microsoft.com/mssql-tools:latest --restart=Never --rm -i --command -- /bin/bash -lc '
for DB in db1 db2 db3; do
  /opt/mssql-tools/bin/sqlcmd -S mssql-src-mssql-helm-db,1433 -U sa -P "Dummy!Passw0rd" -Q "USE [$DB]; INSERT INTO dbo.pitr_orders(phase,marker) VALUES('\''wave1'\'','\''$DB-wave1-001'\'');";
done
'

cat <<'EOFYAML' | kubectl -n dbaas-mssql apply -f -
apiVersion: dbaas.cozy.io/v1alpha1
kind: MSSQLBackup
metadata:
  name: src-log-1
spec:
  policyRef:
    name: mssql-src-mssql-helm-instance-backup-policy
  backupType: log
  databases: ["db1","db2","db3"]
  requestedAt: "2026-02-10T00:05:00Z"
EOFYAML

kubectl -n dbaas-mssql get mssqlbackup src-log-1 -w
```

## 9) สร้าง target instance

```bash
helm upgrade --install mssql-tgt ./helm/mssql-helm \
  -n dbaas-mssql \
  --set mssql.image.tag=2022-latest \
  --set mssql.auth.saPassword='Dummy!Passw0rd' \
  --set mssql.persistence.storageClass=standard \
  --set autoBackup.enabled=false \
  --set operator.enabled=false
```

## 10) ตั้ง `targetTime` แล้ว insert wave2

เลือกเวลา `targetTime` ให้อยู่ “หลัง wave1 ก่อน wave2”

ตัวอย่างสร้างเวลาแบบ UTC อัตโนมัติ (แนะนำ):

```bash
TARGET_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "$TARGET_TIME"
```

จากนั้น insert wave2:

```bash
kubectl -n dbaas-mssql run sqlcmd-wave2 --image=mcr.microsoft.com/mssql-tools:latest --restart=Never --rm -i --command -- /bin/bash -lc '
for DB in db1 db2 db3; do
  /opt/mssql-tools/bin/sqlcmd -S mssql-src-mssql-helm-db,1433 -U sa -P "Dummy!Passw0rd" -Q "USE [$DB]; INSERT INTO dbo.pitr_orders(phase,marker) VALUES('\''wave2'\'','\''$DB-wave2-001'\'');";
done
'
```

## 11) ส่ง PITR restore request

ให้แทนค่า `targetTime` เป็นเวลาจริงที่เลือกไว้จากข้อ 10

```bash
cat <<'EOFYAML' | kubectl -n dbaas-mssql apply -f -
apiVersion: dbaas.cozy.io/v1alpha1
kind: MSSQLRestoreRequest
metadata:
  name: src-pitr-1
spec:
  instanceRef:
    name: mssql-src-mssql-helm-instance
  targetTime: "2026-02-10T06:54:34Z"
  newInstanceName: mssql-tgt
  databases: ["db1","db2","db3"]
  targetConnection:
    host: mssql-tgt-mssql-helm-db
    port: 1433
    user: sa
    passwordSecretRef:
      name: mssql-tgt-mssql-helm-sa
      key: SA_PASSWORD
  targetStorage:
    pvcName: data-mssql-tgt-mssql-helm-db-0
    storageClassName: standard
    size: 50Gi
    accessModes: ["ReadWriteOnce"]
EOFYAML

kubectl -n dbaas-mssql get mssqlrestorerequests,mssqlrestorejobs -w
```

## 12) Validate หลัง restore

```bash
kubectl -n dbaas-mssql run sqlcmd-validate --image=mcr.microsoft.com/mssql-tools:latest --restart=Never --rm -i --command -- /bin/bash -lc '
for DB in db1 db2 db3; do
  /opt/mssql-tools/bin/sqlcmd -S mssql-tgt-mssql-helm-db,1433 -U sa -P "Dummy!Passw0rd" -Q "USE [$DB]; SELECT DB_NAME() AS dbname, SUM(CASE WHEN phase='\''seed'\'' THEN 1 ELSE 0 END) seed_cnt, SUM(CASE WHEN phase='\''wave1'\'' THEN 1 ELSE 0 END) wave1_cnt, SUM(CASE WHEN phase='\''wave2'\'' THEN 1 ELSE 0 END) wave2_cnt FROM dbo.pitr_orders;";
done
'
```

## หมายเหตุ
- ถ้าจะยืนยันผล PITR ให้ชัด: ต้องเห็น `seed/wave1` และไม่ควรมี `wave2` ที่ฝั่ง target (ขึ้นกับ `targetTime` ที่เลือก)
- ถ้า image operator/executor อยู่ local เท่านั้น ให้ `kind load docker-image` ก่อน `helm upgrade --install`
