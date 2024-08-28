{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "eric-oss.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create release name used for cluster role.
*/}}
{{- define "eric-oss.release.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "eric-oss.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create Ericsson product app.kubernetes.io info
*/}}
{{- define "eric-oss.kubernetes-io-info" -}}
app.kubernetes.io/name: {{ .Chart.Name | quote }}
app.kubernetes.io/version: {{ .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}

{{/*
Create Ericsson Product Info
*/}}
{{- define "eric-oss.helm-annotations" -}}
ericsson.com/product-name: "OSS"
ericsson.com/product-number: "N/A"
ericsson.com/product-revision: "R1A"
{{- end}}

{{/*
Create logging info enabling it when logging path does not exist in the Values
*/}}
{{- define "eric-oss.logging.enabled" -}}
{{ if hasKey (.Values.logging) "enabled" }}
    {{- print .Values.logging.enabled -}}
{{ else }}
    {{- print "true" -}}
{{ end }}
{{- end}}

{{/*
Create backup controller enabling option
*/}}
{{- define "eric-oss.backup-controller.enabled" -}}
{{ if hasKey (index .Values "backup-controller") "enabled" }}
  {{- print (index .Values "backup-controller").enabled -}}
{{ else }}
  {{- print "true" -}}
{{ end }}
{{- end}}

{{/*
Create notification service enabling option
*/}}
{{- define "eric-oss.notification-service.enabled" -}}
{{ if hasKey (index .Values "notification-service") "enabled" }}
  {{- print (index .Values "notification-service").enabled -}}
{{ else }}
  {{- print "true" -}}
{{ end }}
{{- end}}

{{/*
Create keycloak enabling option
*/}}
{{- define "eric-oss.keycloak.enabled" -}}
{{ if hasKey (.Values.keycloak) "enabled" }}
    {{- print .Values.keycloak.enabled -}}
{{ else }}
    {{- print "true" -}}
{{ end }}
{{- end}}

{{/*
Create eric-pm-server info enabling it when eric-pm-server path does not exist in the Values
*/}}
{{- define "eric-oss.eric-pm-server.enabled" -}}
{{ if hasKey (index .Values "eric-pm-server") "enabled" }}
    {{- print (index .Values "eric-pm-server").enabled -}}
{{ else }}
    {{- print "true" -}}
{{ end }}
{{- end}}

{{/*
Create image pull secrets for keycloak client
*/}}
{{- define "eric-oss.keycloak-config.pullSecrets" -}}
{{- if .Values.imageCredentials.registry -}}
  {{- if .Values.imageCredentials.registry.pullSecret -}}
    {{- print .Values.imageCredentials.registry.pullSecret -}}
  {{- end -}}
  {{- else if .Values.global.pullSecret -}}
    {{- print .Values.global.pullSecret -}}
  {{- end -}}
{{- end -}}

{{/*
Create image pull secrets for gas patcher
*/}}
{{- define "eric-oss.gas-patcher.pullSecrets" -}}
{{- if .Values.imageCredentials.registry -}}
  {{- if .Values.imageCredentials.registry.pullSecret -}}
    {{- print .Values.imageCredentials.registry.pullSecret -}}
  {{- end -}}
  {{- else if .Values.global.registry.pullSecret -}}
    {{- print .Values.global.registry.pullSecret -}}
  {{- else if .Values.global.pullSecret -}}
    {{- print .Values.global.pullSecret -}}
  {{- end -}}
{{- end -}}

{{/*
Define urls for protected logging resource
*/}}
{{- define "eric-oss.logging.rbac-resources" -}}
  {{- if index .Values "rbac" "eric-data-visualizer-kb" "resources" -}}
    {{- $urlNumbers := (len  (index .Values "rbac" "eric-data-visualizer-kb" "resources")) -}}
    {{- if (gt $urlNumbers 0) -}}
      {{- range $index, $item := index .Values "rbac" "eric-data-visualizer-kb" "resources" -}}
        {{- print  $item | quote -}}{{- if (lt $index  (sub  $urlNumbers 1)) -}},{{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Define urls for protected metrics resource
*/}}
{{- define "eric-oss.metrics.rbac-resources" -}}
  {{- if index .Values "rbac" "eric-pm-server" "resources" -}}
    {{- $urlNumbers := (len (index .Values "rbac" "eric-pm-server" "resources")) -}}
    {{- if (gt $urlNumbers 0) -}}
      {{- range $index, $item := index .Values "rbac" "eric-pm-server" "resources" -}}
        {{- print  $item | quote -}}{{- if (lt $index  (sub  $urlNumbers 1)) -}},{{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Define urls for protected Backup and Restore resource
*/}}
{{- define "eric-oss.bur.rbac-resources" -}}
  {{- if index .Values "rbac" "eric-ctrl-bro" "resources" -}}
    {{- $urlNumbers := (len (index .Values "rbac" "eric-ctrl-bro" "resources")) -}}
    {{- if (gt $urlNumbers 0) -}}
      {{- range $index, $item := index .Values "rbac" "eric-ctrl-bro" "resources" -}}
        {{- print  $item | quote -}}{{- if (lt $index  (sub  $urlNumbers 1)) -}},{{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{/*
Enable Node Selector functionality
*/}}
{{- define "eric-oss.nodeSelector" -}}
{{- if .Values.nodeSelector }}
nodeSelector:
  {{ toYaml .Values.nodeSelector | trim }}
{{- else if .Values.global.nodeSelector }}
nodeSelector:
  {{ toYaml .Values.global.nodeSelector | trim }}
{{- end }}
{{- end -}}

{{/*
The keycloak-client path (DR-D1121-067)
*/}}
{{- define "eric-oss.keycloak-client-path" -}}
    {{- $productInfo := fromYaml (.Files.Get "eric-product-info.yaml") -}}
    {{- $registryUrl := $productInfo.images.keycloakClient.registry -}}
    {{- $repoPath := $productInfo.images.keycloakClient.repoPath -}}
    {{- $name := $productInfo.images.keycloakClient.name -}}
    {{- $tag := $productInfo.images.keycloakClient.tag -}}
    {{- if .Values.global -}}
        {{- if .Values.global.registry -}}
            {{- if .Values.global.registry.url -}}
                {{- $registryUrl = .Values.global.registry.url -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}
    {{- if .Values.imageCredentials -}}
        {{- if .Values.imageCredentials.keycloakClient -}}
            {{- if .Values.imageCredentials.keycloakClient.registry -}}
                {{- if .Values.imageCredentials.keycloakClient.registry.url -}}
                    {{- $registryUrl = .Values.imageCredentials.keycloakClient.registry.url -}}
                {{- end -}}
            {{- end -}}
            {{- if not (kindIs "invalid" .Values.imageCredentials.keycloakClient.repoPath) -}}
                {{- $repoPath = .Values.imageCredentials.keycloakClient.repoPath -}}
            {{- end -}}
        {{- end -}}
        {{- if not (kindIs "invalid" .Values.imageCredentials.repoPath) -}}
            {{- $repoPath = .Values.imageCredentials.repoPath -}}
        {{- end -}}
    {{- end -}}
    {{- if $repoPath -}}
        {{- $repoPath = printf "%s/" $repoPath -}}
    {{- end -}}
    {{- printf "%s/%s%s:%s" $registryUrl $repoPath $name $tag -}}
{{- end -}}

{{/*
The gas-patcher path (DR-D1121-067)
*/}}
{{- define "eric-oss.gas-patcher-path" }}
    {{- $productInfo := fromYaml (.Files.Get "eric-product-info.yaml") -}}
    {{- $registryUrl := $productInfo.images.gasPatcher.registry -}}
    {{- $repoPath := $productInfo.images.gasPatcher.repoPath -}}
    {{- $name := $productInfo.images.gasPatcher.name -}}
    {{- $tag := $productInfo.images.gasPatcher.tag -}}
    {{- if .Values.global -}}
        {{- if .Values.global.registry -}}
            {{- if .Values.global.registry.url -}}
                {{- $registryUrl = .Values.global.registry.url -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}
    {{- if .Values.imageCredentials -}}
        {{- if .Values.imageCredentials.gasPatcher -}}
            {{- if .Values.imageCredentials.gasPatcher.registry -}}
                {{- if .Values.imageCredentials.gasPatcher.registry.url -}}
                    {{- $registryUrl = .Values.imageCredentials.gasPatcher.registry.url -}}
                {{- end -}}
            {{- end -}}
            {{- if not (kindIs "invalid" .Values.imageCredentials.gasPatcher.repoPath) -}}
                {{- $repoPath = .Values.imageCredentials.gasPatcher.repoPath -}}
            {{- end -}}
        {{- end -}}
        {{- if not (kindIs "invalid" .Values.imageCredentials.repoPath) -}}
            {{- $repoPath = .Values.imageCredentials.repoPath -}}
        {{- end -}}
    {{- end -}}
    {{- if $repoPath -}}
        {{- $repoPath = printf "%s/" $repoPath -}}
    {{- end -}}
    {{- printf "%s/%s%s:%s" $registryUrl $repoPath $name $tag -}}
{{- end -}}
