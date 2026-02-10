{{- define "mssql-helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mssql-helm.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "mssql-helm.labels" -}}
app.kubernetes.io/name: {{ include "mssql-helm.name" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mssql-helm.dbName" -}}
{{- printf "%s-db" (include "mssql-helm.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mssql-helm.saSecretName" -}}
{{- if .Values.mssql.auth.existingSecret -}}
{{- .Values.mssql.auth.existingSecret -}}
{{- else if .Values.mssql.auth.secretName -}}
{{- .Values.mssql.auth.secretName -}}
{{- else -}}
{{- printf "%s-sa" (include "mssql-helm.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mssql-helm.operatorServiceAccountName" -}}
{{- if .Values.operator.serviceAccount.name -}}
{{- .Values.operator.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-operator" (include "mssql-helm.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mssql-helm.instanceName" -}}
{{- if .Values.autoBackup.instanceName -}}
{{- .Values.autoBackup.instanceName | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-instance" (include "mssql-helm.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "mssql-helm.sourcePVCName" -}}
{{- if .Values.autoBackup.storage.sourceData.pvcName -}}
{{- .Values.autoBackup.storage.sourceData.pvcName -}}
{{- else -}}
{{- printf "data-%s-0" (include "mssql-helm.dbName" .) -}}
{{- end -}}
{{- end -}}

{{- define "mssql-helm.backupPVCName" -}}
{{- if .Values.autoBackup.storage.backupData.pvcName -}}
{{- .Values.autoBackup.storage.backupData.pvcName -}}
{{- else -}}
{{- printf "%s-backup-store" (include "mssql-helm.instanceName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
