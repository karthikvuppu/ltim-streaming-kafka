# Modular Security Architecture

## Overview

This Kafka deployment uses a **modular security architecture** that enables the **same code** to work across all environments (sandbox, dev, production). Security features are controlled via **feature flags** rather than duplicated code.

### Key Principles

1. **Single Source of Truth**: Security logic defined once in `values-security.yaml`
2. **Feature Flags**: Environments enable/disable features via simple boolean flags
3. **No Code Duplication**: Templates reference security module, not environment-specific code
4. **Consistent Behavior**: Same security implementations across all environments

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                 Deployment Process                       │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
         ┌─────────────────────────────────┐
         │  Environment Selection           │
         │  (sandbox | dev | prod)          │
         └─────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │ Common   │   │ Security │   │ Env      │
    │ Values   │   │ Module   │   │ Override │
    └──────────┘   └──────────┘   └──────────┘
           │               │               │
           └───────────────┼───────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │   Helm Templates       │
              │   (with helpers)       │
              └────────────────────────┘
                           │
                           ▼
              ┌────────────────────────┐
              │   Kafka Cluster CRD    │
              │   (environment-aware)  │
              └────────────────────────┘
```

---

## File Structure

```
helm/kafka-eks/
├── values-common.yaml              # Base configuration (shared)
├── values-security.yaml            # Security module (authn/authz logic)
├── environments/
│   ├── sandbox.yaml                # Feature flags + overrides
│   ├── dev.yaml                    # Feature flags + overrides
│   └── production.yaml             # Feature flags + overrides
└── templates/
    ├── _security-helpers.tpl       # Security helper functions
    ├── kafka-modular.yaml          # Main Kafka CRD (modular)
    ├── kafka-users-modular.yaml    # User management (modular)
    ├── networkpolicy-modular.yaml  # Network policies (modular)
    └── storageclass-modular.yaml   # Encrypted storage (modular)
```

---

## Security Modules

### 1. Authentication Module (`values-security.yaml`)

Defines authentication methods:
- **SCRAM-SHA-512**: Password-based authentication
- **Mutual TLS**: Certificate-based authentication
- **OAuth/OIDC**: Token-based authentication

**Configuration:**
```yaml
authentication:
  methods:
    scram:
      enabled: true
      mechanism: scram-sha-512
    mtls:
      enabled: false
    oauth:
      enabled: false
  defaultMethod: scram-sha-512
```

**Environment Override:**
```yaml
# environments/production.yaml
security:
  enabled: true
  features:
    authentication: true  # Enable authentication
```

### 2. Authorization Module (`values-security.yaml`)

Defines authorization engine and roles:
- **Simple ACL**: Kafka native ACLs
- **Roles**: Predefined permission sets (producer, consumer, admin)

**Configuration:**
```yaml
authorization:
  engine:
    type: simple
    enabled: true
  superUsers:
    - User:CN=my-kafka-entity-topic-operator
  roles:
    producer:
      permissions:
        - resource:
            type: topic
            name: "*"
          operations: [Write, Describe, Create]
    consumer:
      permissions:
        - resource:
            type: topic
            name: "*"
          operations: [Read, Describe]
```

**Environment Override:**
```yaml
# environments/production.yaml
security:
  enabled: true
  features:
    authorization: true  # Enable authorization
```

### 3. Encryption Module (`values-security.yaml`)

Defines encryption settings:
- **In-Transit**: TLS for all connections
- **At-Rest**: AWS KMS encryption for storage
- **Inter-Broker**: TLS between brokers

**Configuration:**
```yaml
transport:
  tls:
    enabled: true
    listeners:
      internal:
        enabled: true
        requireAuth: true
      external:
        enabled: true
        requireAuth: true
      interBroker:
        enabled: true
        mutualAuth: true

dataProtection:
  encryptionAtRest:
    enabled: true
    provider: aws-kms
  storageClass:
    name: kafka-encrypted
    encrypted: true
```

**Environment Override:**
```yaml
# environments/production.yaml
security:
  enabled: true
  features:
    encryption:
      inTransit: true
      atRest: true
      interBroker: true
```

### 4. Network Security Module (`values-security.yaml`)

Defines network policies:
- **Ingress**: Allow/deny inbound traffic
- **Egress**: Allow/deny outbound traffic

**Configuration:**
```yaml
network:
  policies:
    enabled: true
    ingress:
      denyAll: true
      allowFromNamespaces: []
      allowMonitoring: true
    egress:
      denyAll: false
      allowDNS: true
      allowKubernetesAPI: true
```

**Environment Override:**
```yaml
# environments/production.yaml
security:
  enabled: true
  features:
    networkPolicies: true

network:
  policies:
    ingress:
      allowFromNamespaces:
        - production-apps
        - api-gateway
```

---

## Environment Configurations

### Sandbox Environment

**Purpose**: Experimentation, testing, demos
**Security**: **DISABLED**

```yaml
# environments/sandbox.yaml
security:
  enabled: false  # All security features OFF

kafka:
  replicas: 1
  storage:
    size: 10Gi
    class: gp2  # Non-encrypted storage
```

**Features:**
- ❌ No authentication
- ❌ No authorization
- ❌ No TLS encryption
- ❌ No network policies
- ✅ Fast startup
- ✅ Easy testing

### Development Environment

**Purpose**: Development, integration testing
**Security**: **PARTIAL**

```yaml
# environments/dev.yaml
security:
  enabled: true

  features:
    authentication: true       # ✅ Enabled
    authorization: true        # ✅ Enabled
    encryption:
      inTransit: true          # ✅ Enabled
      atRest: false            # ❌ Disabled (cost saving)
      interBroker: false       # ❌ Disabled (performance)
    networkPolicies: false     # ❌ Disabled (easier debugging)
    podSecurity: true          # ✅ Enabled
    auditLogging: false        # ❌ Disabled (noise reduction)

kafka:
  replicas: 1
  storage:
    size: 5Gi
    class: gp2
```

**Features:**
- ✅ Authentication (SCRAM-SHA-512)
- ✅ Authorization (ACLs)
- ✅ TLS encryption (client-broker)
- ❌ No encryption at rest
- ❌ No network policies
- ✅ Pod security standards
- ❌ No audit logging

### Production Environment

**Purpose**: Production workloads
**Security**: **FULL**

```yaml
# environments/production.yaml
security:
  enabled: true

  features:
    authentication: true       # ✅ Enabled
    authorization: true        # ✅ Enabled
    encryption:
      inTransit: true          # ✅ Enabled
      atRest: true             # ✅ Enabled
      interBroker: true        # ✅ Enabled
    networkPolicies: true      # ✅ Enabled
    podSecurity: true          # ✅ Enabled
    auditLogging: true         # ✅ Enabled

kafka:
  replicas: 3
  storage:
    size: 100Gi
    class: kafka-encrypted  # Encrypted storage class

network:
  policies:
    ingress:
      allowFromNamespaces:
        - production-apps
        - api-gateway
```

**Features:**
- ✅ Authentication (SCRAM-SHA-512)
- ✅ Authorization (ACLs with roles)
- ✅ TLS encryption (all connections)
- ✅ Encryption at rest (AWS KMS)
- ✅ Network policies (namespace isolation)
- ✅ Pod security standards (non-root, no privesc)
- ✅ Audit logging (authorization events)
- ✅ Inter-broker TLS

---

## Template Helpers

Security helpers make templates environment-aware:

### Example: `_security-helpers.tpl`

```yaml
{{/* Check if security is enabled */}}
{{- define "kafka-eks.security.enabled" -}}
{{- if .Values.security }}
{{- if .Values.security.enabled }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}

{{/* Check if authentication is enabled */}}
{{- define "kafka-eks.security.authentication.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.authentication }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}
```

### Usage in Templates

```yaml
# templates/kafka-modular.yaml
listeners:
  # Plaintext listener (only if security is disabled)
  {{- if include "kafka-eks.security.plaintextEnabled" . }}
  - name: plain
    port: 9092
    type: internal
    tls: false
  {{- end }}

  # TLS listener (if security is enabled)
  {{- if include "kafka-eks.security.tlsListenerEnabled" . }}
  - name: tls
    port: 9093
    type: internal
    tls: true
    {{- if include "kafka-eks.security.authentication.enabled" . }}
    authentication:
      type: {{ include "kafka-eks.security.authMethod" . }}
    {{- end }}
  {{- end }}
```

**Result:**
- **Sandbox**: Only plaintext listener created
- **Dev**: Plaintext disabled, TLS listener with auth
- **Production**: TLS listener with auth + encryption

---

## Deployment

### Using Modular Deployment Script

```bash
# Deploy to sandbox (no security)
./deploy-modular.sh sandbox

# Deploy to development (partial security)
./deploy-modular.sh dev

# Deploy to production (full security)
./deploy-modular.sh production
```

### Manual Helm Deployment

```bash
# Deploy with merged values
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  -f helm/kafka-eks/values-common.yaml \
  -f helm/kafka-eks/values-security.yaml \
  -f helm/kafka-eks/environments/production.yaml \
  --set environment=production
```

---

## Adding New Security Features

### Step 1: Define Feature in Security Module

```yaml
# values-security.yaml
myNewFeature:
  enabled: true
  setting1: value1
  setting2: value2
```

### Step 2: Add Feature Flag

```yaml
# values-common.yaml
security:
  features:
    myNewFeature: false  # Default OFF
```

### Step 3: Enable in Environment

```yaml
# environments/production.yaml
security:
  features:
    myNewFeature: true  # Enable in prod
```

### Step 4: Create Helper

```yaml
# templates/_security-helpers.tpl
{{- define "kafka-eks.security.myNewFeature.enabled" -}}
{{- if include "kafka-eks.security.enabled" . }}
{{- if .Values.security.features.myNewFeature }}
{{- true }}
{{- end }}
{{- end }}
{{- end }}
```

### Step 5: Use in Template

```yaml
# templates/kafka-modular.yaml
{{- if include "kafka-eks.security.myNewFeature.enabled" . }}
# Feature-specific configuration here
{{- end }}
```

---

## User Management

### Automatic User Provisioning

Users are auto-created based on roles:

```yaml
# values-security.yaml
users:
  defaultUsers:
    - name: app-producer
      role: producer
      authentication:
        type: scram-sha-512

    - name: app-consumer
      role: consumer
      authentication:
        type: scram-sha-512
```

**Environment Control:**
```yaml
# environments/production.yaml
users:
  provisioning:
    enabled: true  # Auto-create users
```

### Role-Based Permissions

Roles defined in security module:

```yaml
authorization:
  roles:
    producer:
      permissions:
        - resource:
            type: topic
            name: "*"
          operations: [Write, Describe, Create]

    consumer:
      permissions:
        - resource:
            type: topic
            name: "*"
          operations: [Read, Describe]

    admin:
      permissions:
        - resource:
            type: topic
            name: "*"
          operations: [All]
```

---

## Best Practices

### 1. Never Modify Security Module Directly

❌ **Bad:**
```yaml
# environments/production.yaml
authentication:
  defaultMethod: tls  # DON'T override security module
```

✅ **Good:**
```yaml
# environments/production.yaml
security:
  features:
    authentication: true  # Use feature flags
```

### 2. Use Environment Overrides for Resources Only

✅ **Good:**
```yaml
# environments/production.yaml
kafka:
  replicas: 3
  storage:
    size: 100Gi
  resources:
    requests:
      memory: 4Gi
```

❌ **Bad:**
```yaml
# environments/production.yaml
kafka:
  listeners:  # DON'T duplicate listener config
    tls:
      enabled: true
```

### 3. Test Security Features Incrementally

```bash
# Test in dev first
./deploy-modular.sh dev

# Verify authentication works
kubectl exec -it my-kafka-kafka-0 -n kafka -- kafka-console-producer \
  --bootstrap-server localhost:9093 \
  --topic test \
  --producer.config /tmp/client.properties

# Then promote to production
./deploy-modular.sh production
```

### 4. Document Custom Overrides

If you need environment-specific customization:

```yaml
# environments/production.yaml
# CUSTOM OVERRIDE: Allow specific namespace for ML workloads
network:
  policies:
    ingress:
      allowFromNamespaces:
        - production-apps
        - ml-training  # Custom addition for ML team
```

---

## Troubleshooting

### Security Feature Not Applied

**Problem**: Feature enabled but not working

**Solution**: Check helper function

```bash
# Debug Helm template rendering
helm template kafka-eks ./helm/kafka-eks \
  -f helm/kafka-eks/values-common.yaml \
  -f helm/kafka-eks/values-security.yaml \
  -f helm/kafka-eks/environments/production.yaml \
  | grep -A 10 "authentication"
```

### Values File Conflicts

**Problem**: Settings from wrong file applied

**Solution**: Verify merge order

```bash
# Helm merges in order: common -> security -> environment
# Later files override earlier ones
helm install --dry-run --debug kafka-eks ./helm/kafka-eks \
  -f helm/kafka-eks/values-common.yaml \
  -f helm/kafka-eks/values-security.yaml \
  -f helm/kafka-eks/environments/production.yaml
```

### Authentication Failing

**Problem**: Clients can't authenticate

**Solution**: Verify security.enabled flag

```yaml
# Check current deployment
kubectl get kafka my-kafka -n kafka -o yaml | grep -A 5 "authentication"

# Should show:
#   authentication:
#     type: scram-sha-512
```

---

## Migration Guide

### From Old (Non-Modular) to New (Modular)

**Step 1**: Identify current environment
```bash
# Check current values
helm get values kafka-eks -n kafka
```

**Step 2**: Map to new structure

| Old File | New Files |
|----------|-----------|
| `values.yaml` | `values-common.yaml` |
| `values-prod.yaml` | `values-common.yaml` + `values-security.yaml` + `environments/production.yaml` |
| `values-dev.yaml` | `values-common.yaml` + `values-security.yaml` + `environments/dev.yaml` |

**Step 3**: Deploy with new structure
```bash
# Backup current deployment
helm get values kafka-eks -n kafka > backup-values.yaml

# Upgrade to modular
helm upgrade kafka-eks ./helm/kafka-eks \
  -f helm/kafka-eks/values-common.yaml \
  -f helm/kafka-eks/values-security.yaml \
  -f helm/kafka-eks/environments/production.yaml
```

---

## Summary

### Benefits of Modular Security

✅ **Single Source of Truth**: Security logic in one place
✅ **No Code Duplication**: Same templates across environments
✅ **Easy Testing**: Toggle features with flags
✅ **Clear Separation**: Environment config vs. security logic
✅ **Scalable**: Add features without touching environments
✅ **Maintainable**: Update security module, all environments benefit

### Quick Reference

| Environment | Security | Use Case |
|-------------|----------|----------|
| **Sandbox** | Disabled | Experimentation, demos |
| **Dev** | Partial | Development, integration testing |
| **Production** | Full | Production workloads |

**Deploy Command:**
```bash
./deploy-modular.sh [sandbox|dev|production]
```

---

**Version**: 1.0.0
**Last Updated**: 2025-12-16
**Architecture**: Modular Security with Feature Flags
