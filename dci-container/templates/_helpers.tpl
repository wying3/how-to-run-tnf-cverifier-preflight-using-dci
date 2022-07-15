{{/*
Expand the name of the chart.
*/}}
{{- define "dci-container.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dci-container.fullname" -}}
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
{{- define "dci-container.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "dci-container.labels" -}}
helm.sh/chart: {{ include "dci-container.chart" . }}
{{ include "dci-container.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app: {{ .Chart.AppVersion | quote }}
{{- end }}
app/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "dci-container.selectorLabels" -}}
app: {{ include "dci-container.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "dci-container.serviceAccountName" -}}
{{- default (include "dci-container.fullname" .) .Values.serviceAccount.name }}
{{- end }}

{{- define "network_routes" }}
"routes": [
{{- range $index, $value := . }}
{{- if gt $index 0 }},{{- end }}
  { "dst": {{ trim $value.dst | quote }}, "gw": {{ trim $value.gw | quote }} }
{{- end }}
]
{{- end }}
