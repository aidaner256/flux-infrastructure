{{/*
Expand the name of the chart.
*/}}
{{- define "order-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "order-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "order-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "order-app.labels" -}}
helm.sh/chart: {{ include "order-app.chart" . }}
{{ include "order-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "order-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "order-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "order-app.serviceAccountName" -}}
{{- if .Values.vault.enabled }}
{{- default "order-app-sa" .Values.vault.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.vault.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
MongoDB labels
*/}}
{{- define "mongodb.labels" -}}
app: mongodb
component: database
{{ include "order-app.labels" . }}
{{- end }}

{{/*
Redis labels
*/}}
{{- define "redis.labels" -}}
app: redis
component: cache
{{ include "order-app.labels" . }}
{{- end }}

{{/*
Kafka labels
*/}}
{{- define "kafka.labels" -}}
app: kafka
component: message-broker
{{ include "order-app.labels" . }}
{{- end }}

{{/*
Zookeeper labels
*/}}
{{- define "zookeeper.labels" -}}
app: zookeeper
component: coordination
{{ include "order-app.labels" . }}
{{- end }}

{{/*
RabbitMQ labels
*/}}
{{- define "rabbitmq.labels" -}}
app: rabbitmq
component: message-broker
{{ include "order-app.labels" . }}
{{- end }}

{{/*
Application labels
*/}}
{{- define "app.labels" -}}
app: {{ .Values.app.name }}
component: application
{{ include "order-app.labels" . }}
{{- end }}
