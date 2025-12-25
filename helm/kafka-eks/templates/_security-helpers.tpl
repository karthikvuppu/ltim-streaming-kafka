{{/*
Security Helper Templates
Modular security functions used across all templates
*/}}

{{/*
Check if security is enabled
*/}}
{{- define "kafka-eks.security.enabled" -}}
{{- if .Values.security }}
{{- if .Values.security.enabled }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if authentication is enabled
*/}}
{{- define "kafka-eks.security.authentication.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.authentication }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if authorization is enabled
*/}}
{{- define "kafka-eks.security.authorization.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.authorization }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if TLS is enabled
*/}}
{{- define "kafka-eks.security.tls.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.encryption.inTransit }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if inter-broker TLS is enabled
*/}}
{{- define "kafka-eks.security.interBrokerTLS.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.encryption.interBroker }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if encryption at rest is enabled
*/}}
{{- define "kafka-eks.security.encryptionAtRest.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.encryption.atRest }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if network policies are enabled
*/}}
{{- define "kafka-eks.security.networkPolicies.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.networkPolicies }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if pod security is enabled
*/}}
{{- define "kafka-eks.security.podSecurity.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.podSecurity }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if audit logging is enabled
*/}}
{{- define "kafka-eks.security.auditLogging.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.auditLogging }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Get authentication method
*/}}
{{- define "kafka-eks.security.authMethod" -}}
{{- if include "kafka-eks.security.authentication.enabled" . }}
{{- .Values.authentication.defaultMethod | default "scram-sha-512" }}
{{- end }}
{{- end }}

{{/*
Get storage class name
*/}}
{{- define "kafka-eks.security.storageClass" -}}
{{- if include "kafka-eks.security.encryptionAtRest.enabled" . }}
{{- .Values.dataProtection.storageClass.name | default "kafka-encrypted" }}
{{- else }}
{{- .Values.kafka.storage.class | default "gp2" }}
{{- end }}
{{- end }}

{{/*
Get Zookeeper storage class name
*/}}
{{- define "kafka-eks.security.zookeeperStorageClass" -}}
{{- if include "kafka-eks.security.encryptionAtRest.enabled" . }}
{{- .Values.dataProtection.storageClass.name | default "kafka-encrypted" }}
{{- else }}
{{- .Values.zookeeper.storage.class | default "gp2" }}
{{- end }}
{{- end }}

{{/*
Should plaintext listener be enabled?
*/}}
{{- define "kafka-eks.security.plaintextEnabled" -}}
{{- if not (include "kafka-eks.security.enabled" .) }}
{{- .Values.kafka.listeners.plain.enabled | default true }}
{{- else }}
{{- false }}
{{- end }}
{{- end }}

{{/*
Should TLS listener be enabled?
*/}}
{{- define "kafka-eks.security.tlsListenerEnabled" -}}
{{- if include "kafka-eks.security.tls.enabled" . }}
{{- true }}
{{- else }}
{{- .Values.kafka.listeners.tls.enabled | default false }}
{{- end }}
{{- end }}

{{/*
Get inter-broker protocol
*/}}
{{- define "kafka-eks.security.interBrokerProtocol" -}}
{{- if include "kafka-eks.security.interBrokerTLS.enabled" . }}
{{- .Values.kafka.broker.interBroker.protocol | default "SSL" }}
{{- else }}
{{- "PLAINTEXT" }}
{{- end }}
{{- end }}
