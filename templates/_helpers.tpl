{{/*
Expand the name of the chart.
*/}}
{{- define "cluster-serverless.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cluster-serverless.fullname" -}}
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
{{- define "cluster-serverless.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels (optional, for adding to resources if needed)
*/}}
{{- define "cluster-serverless.labels" -}}
helm.sh/chart: {{ include "cluster-serverless.chart" . }}
{{ include "cluster-serverless.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels (optional)
*/}}
{{- define "cluster-serverless.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cluster-serverless.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}