{{/* Nom de base des ressources : le nom de la release. */}}
{{- define "microcrm.fullname" -}}
{{- .Release.Name | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "microcrm.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.images.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Sélecteurs : stables d'une version à l'autre (le sélecteur d'un Deployment ne peut pas changer). */}}
{{- define "microcrm.selectorLabels" -}}
app.kubernetes.io/name: {{ .root.Chart.Name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- define "microcrm.image" -}}
{{- if .digest -}}
{{- if not (regexMatch "^sha256:[0-9a-f]{64}$" .digest) -}}
{{- fail (printf "empreinte d'image invalide : %s" .digest) -}}
{{- end -}}
{{- printf "%s%s@%s" .root.Values.images.repositoryPrefix .name .digest -}}
{{- else -}}
{{- printf "%s%s:%s" .root.Values.images.repositoryPrefix .name (.root.Values.images.tag | default .root.Chart.AppVersion) -}}
{{- end -}}
{{- end -}}

{{/* Contexte de sécurité commun : utilisateur non root, aucun droit en plus, système de fichiers en lecture seule. */}}
{{- define "microcrm.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
fsGroup: 10001
seccompProfile:
  type: RuntimeDefault
{{- end -}}
