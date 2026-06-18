{{/*
Chart name — used as the resource name across all templates
*/}}
{{- define "azureshop.name" -}}
{{- .Chart.Name }}
{{- end }}

{{/*
Common labels applied to every resource
*/}}
{{- define "azureshop.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "azureshop.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: azureshop
{{- end }}

{{/*
Selector labels — used by Deployment selector and Service selector
Must be stable (never change after first deploy)
*/}}
{{- define "azureshop.selectorLabels" -}}
app.kubernetes.io/name: {{ include "azureshop.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
