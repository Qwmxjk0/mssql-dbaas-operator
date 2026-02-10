# MSSQL DBaaS UI Field-by-Field Spec (MVP)

สถานะเอกสาร: Draft v1  
อัปเดตล่าสุด: 2026-02-10

## FACT / ASSUMPTION / UNKNOWN
FACT:
- Backend ที่ทดสอบผ่านแล้วรองรับ `MSSQLInstance`, `MSSQLBackup`, `MSSQLRestoreRequest`
- Runtime e2e ผ่านในโหมด `local_pvc` ตามรายงานทดสอบ

ASSUMPTION:
- หน้าเว็บจะเรียก backend API ของทีม Core เพื่อสร้าง/อัปเดต CR

UNKNOWN:
- One-click restore แบบ auto-provision target instance ในคำสั่งเดียว (ยังไม่ validated)

## 1) Create Source Instance
| Field | Type | Required | Default | Validation | CR Mapping |
|---|---|---:|---|---|---|
| `instanceName` | text | Yes | - | `^[a-z0-9-]{3,30}$` | `MSSQLInstance.metadata.name` |
| `namespace` | text/select | Yes | `dbaas-mssql` | namespace ต้องมีจริง | `metadata.namespace` |
| `storageClass` | select | Yes | cluster default | ต้องมีใน cluster | `spec.storage.sourceData.storageClassName`, `spec.storage.backupData.storageClassName`, `spec.storage.targetData.storageClassName` |
| `dataSizeGi` | number | Yes | `50` | `>=20` | `spec.storage.sourceData.size` |
| `backupSizeGi` | number | Yes | `100` | `>= dataSizeGi` แนะนำ | `spec.storage.backupData.size` |
| `retentionDays` | number | Yes | `30` | `1..30` | `spec.retentionDays` |
| `logBackupIntervalMinutes` | number | Yes | `5` | `>=1` | `spec.logBackupIntervalMinutes` |
| `fullBackupSchedule` | cron text | Yes | `0 0 * * *` | cron 5-field | `spec.fullBackupSchedule` |
| `allDatabases` | checkbox | Yes | `true` | - | `spec.allDatabases` |
| `mode` | select | Yes | `local_pvc` | `local_pvc/native_url/disk_then_upload` | `spec.mode` |
| `saPasswordSecretName` | text | Yes | - | secret ต้องมีจริง | `spec.connection.passwordSecretRef.name` |
| `saPasswordSecretKey` | text | Yes | `SA_PASSWORD` | key ต้องมีจริง | `spec.connection.passwordSecretRef.key` |

## 2) Run Full Backup Now
| Field | Type | Required | Default | Validation | CR Mapping |
|---|---|---:|---|---|---|
| `policyName` | hidden/select | Yes | auto from instance | policy ต้องมีจริง | `MSSQLBackup.spec.policyRef.name` |
| `backupType` | hidden | Yes | `full` | fixed value | `MSSQLBackup.spec.backupType` |
| `databases` | multi-select | No | empty | ถ้าเลือกต้องเป็นชื่อ DB ถูกต้อง | `MSSQLBackup.spec.databases` |
| `requestedAt` | hidden | Yes | now UTC | RFC3339 | `MSSQLBackup.spec.requestedAt` |

## 3) Create Target Instance (ก่อน PITR)
| Field | Type | Required | Default | Validation | Mapping |
|---|---|---:|---|---|---|
| `targetInstanceName` | text | Yes | - | ชื่อไม่ซ้ำ | release/instance เป้าหมาย |
| `storageClass` | select | Yes | same as source | ต้องมีใน cluster | target storage class |
| `dataSizeGi` | number | Yes | same as source | `>=20` | target data size |
| `autoBackupEnabled` | checkbox | Yes | `false` | สำหรับ target restore ชั่วคราวแนะนำปิด | target values |

## 4) PITR Restore
| Field | Type | Required | Default | Validation | CR Mapping |
|---|---|---:|---|---|---|
| `sourceInstance` | select | Yes | - | ต้อง `Ready` | `MSSQLRestoreRequest.spec.instanceRef.name` |
| `targetInstance` | select | Yes | - | ต้อง `Ready` | `spec.newInstanceName` + `spec.targetConnection` |
| `targetTime` | datetime UTC | Yes | - | RFC3339 และไม่เกินปัจจุบัน | `spec.targetTime` |
| `databases` | multi-select | No | empty | ถ้าเลือกต้องเป็นชื่อ DB ถูกต้อง | `spec.databases` |
| `targetPVCName` | hidden/readonly | Yes | derive จาก target | PVC ต้องมีจริง | `spec.targetStorage.pvcName` |
| `targetStorageClass` | hidden/readonly | Yes | derive จาก target | storageClass ต้องตรง target | `spec.targetStorage.storageClassName` |

## 5) Status ที่ UI ต้องแสดง
- `MSSQLInstance.status.phase`, `MSSQLInstance.status.message`
- `MSSQLBackupPolicy.status.phase`, `MSSQLBackupPolicy.status.message`
- `MSSQLBackup.status.phase`, `MSSQLBackup.status.message`, `startedAt`, `completedAt`
- `MSSQLRestoreRequest.status.phase`, `MSSQLRestoreRequest.status.message`
- `MSSQLRestoreJob.status.phase`, `MSSQLRestoreJob.status.message`, `lastAppliedLogTime`

## 6) Error Mapping (ขั้นต่ำ)
- Secret ไม่พบ: `passwordSecretRef not found`
- Policy ไม่พบ: `policyRef <name> not found`
- `targetTime` ผิดรูปแบบ: `targetTime must be valid RFC3339 time`
- Storage/PVC ผิด: แสดงข้อความจาก `status.message` ของ CR ต้นทาง

## 7) Out of Scope (รอบนี้)
- Auto-provision target instance จาก restore request ในคลิกเดียว
- Tenant UI authorization model
- Billing/Quota UI
