{{- define "preview-app.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "preview-app.labels" -}}
app.kubernetes.io/name: {{ include "preview-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
platform.tibor.sh/type: preview
platform.tibor.sh/pull-request: {{ .Values.preview.pullRequest | quote }}
{{- end -}}
