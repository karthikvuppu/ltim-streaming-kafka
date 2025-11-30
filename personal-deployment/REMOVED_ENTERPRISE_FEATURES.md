# Removed Enterprise Features

This document lists all enterprise, proprietary, and licensed components that have been removed for the personal deployment.

## ✅ What Has Been Removed

### 1. DataDog Monitoring

**Complete removal - do NOT use these directories:**

- `tooling/datadog/` - All DataDog agent configurations
- `charts/clusterlink-dashboard/` - DataDog dashboards
- `charts/cluster-tools/templates/datadog/` - DataDog secrets

**Files to ignore:**
- `tooling/datadog/production/values.yaml`
- `tooling/datadog/devtest/values.yaml`
- `charts/cluster-tools/templates/datadog/api-key-secret.yaml`

### 2. Confluent Enterprise Platform

**Replaced with Apache Kafka (open-source via Strimzi)**

**Do NOT use these directories:**
- `charts/confluent-services/` - Confluent Enterprise components
- `operator/` - Confluent for Kubernetes (CFK) operator
- `confluent-services/` - Environment-specific Confluent values

**Components removed:**
- Confluent Enterprise Kafka
- Confluent Schema Registry (enterprise features)
- Confluent KSQL
- Confluent Control Center (proprietary)
- Confluent REST Proxy
- Confluent Replicator
- Metadata Service (MDS)
- Role-Based Access Control (RBAC)

### 3. Authentication & Security

**All removed for simplified deployment:**

#### OAuth
- No OAuth configurations in the new deployment

#### mTLS (Mutual TLS)
- `charts/confluent-services/templates/confluent-secrets/tls-group.yaml`
- All certificate management removed
- `secure-deploy/assets/certs/` - Certificate files
- `tooling/cert-manager/` - Certificate manager

#### LDAP Integration
- `charts/cluster-tools/templates/ldap-proxy/` - LDAP proxy
- All Active Directory integrations
- RBAC/MDS authentication

#### SASL/SCRAM
- All SASL configurations removed
- Digest authentication for Zookeeper removed

#### Kerberos
- `charts/confluent-services/templates/confluent-secrets/keytab.yaml`
- `charts/confluent-services/templates/krb-cm.yaml`

### 4. License Files

**Removed:**
- `charts/confluent-services/templates/confluent-secrets/confluent-license.yaml`
- Confluent Enterprise JWT license keys
- All proprietary license references

### 5. External Secrets & AWS Integration

**Removed:**
- External Secrets Operator
- AWS Secrets Manager integration
- All enterprise secret management

### 6. Enterprise Tooling

**Do NOT use:**
- `tooling/filebeat/` - Log shipping (enterprise)
- `tooling/kafka-lag-exporter/` - Use Strimzi metrics instead
- `tooling/external-dns/` - AWS-specific DNS management
- `tooling/ingress/` - Traefik ingress (Scania-specific)
- `charts/kafka-endpoints-monitor/` - Custom monitoring

### 7. CI/CD Pipelines

**Removed:**
- `.gitlab-ci.yml` - GitLab CI pipeline (Scania-specific)
- `cicd/` - All CI/CD templates and scripts

### 8. Scania-Specific Configurations

**All removed:**
- Domain: `iris-streaming.prod.aws.scania.com`
- AWS Account: `676596096981`
- Region: `eu-north-1` (you can use any region)
- Internal load balancers
- VPC configurations
- Node selectors for ARM nodes

## ✅ What You Get Instead

### Open-Source Replacements

| Enterprise Component | Open-Source Alternative |
|---------------------|------------------------|
| Confluent Enterprise Kafka | Apache Kafka 3.6.0 |
| Confluent for Kubernetes | Strimzi Kafka Operator |
| DataDog Monitoring | Prometheus/JMX Exporter (optional) |
| Confluent Control Center | Kafka UI (can add separately) |
| Enterprise Authentication | None (can add later) |
| TLS/mTLS | Disabled (can add later) |
| Confluent License | Not needed |

### Simple Architecture

```
┌─────────────────────────────────┐
│         EKS Cluster             │
│                                 │
│  ┌──────────────────────────┐  │
│  │  Strimzi Operator        │  │
│  └──────────────────────────┘  │
│                                 │
│  ┌──────────────────────────┐  │
│  │  Zookeeper Ensemble      │  │
│  │  (3 nodes)               │  │
│  └──────────────────────────┘  │
│                                 │
│  ┌──────────────────────────┐  │
│  │  Kafka Brokers           │  │
│  │  (3 nodes)               │  │
│  └──────────────────────────┘  │
│                                 │
│  ┌──────────────────────────┐  │
│  │  LoadBalancer (optional) │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘
```

## 📁 Directory Structure Comparison

### ❌ Old (Enterprise - DO NOT USE)
```
ltim-streaming-kafka/
├── charts/confluent-services/     ❌ Enterprise
├── operator/                       ❌ Enterprise
├── confluent-services/            ❌ Enterprise
├── tooling/datadog/               ❌ DataDog
├── tooling/cert-manager/          ❌ Enterprise
├── secure-deploy/                 ❌ Enterprise
└── .gitlab-ci.yml                 ❌ Scania CI/CD
```

### ✅ New (Personal - USE THIS)
```
ltim-streaming-kafka/
└── personal-deployment/           ✅ Open-source
    ├── README.md
    ├── deploy.sh
    ├── undeploy.sh
    ├── test-kafka.sh
    └── kafka-cluster/
        ├── kafka-cluster.yaml
        └── kafka-topic-example.yaml
```

## 🚀 Migration Path

If you need enterprise features later:

1. **Monitoring**: Add Prometheus + Grafana
   - Strimzi already exports JMX metrics
   - Free and open-source

2. **UI Management**: Add Kafka UI
   ```bash
   helm install kafka-ui kafka-ui/kafka-ui \
     --set envs.config.KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=my-kafka-kafka-bootstrap:9092
   ```

3. **Security**: Enable TLS in Strimzi
   ```yaml
   spec:
     kafka:
       listeners:
         - name: tls
           port: 9093
           type: internal
           tls: true
   ```

4. **Authentication**: Add SCRAM-SHA-512
   ```yaml
   spec:
     kafka:
       listeners:
         - name: tls
           authentication:
             type: scram-sha-512
   ```

## 📊 Cost Savings

By removing enterprise components:

- ❌ Confluent Enterprise License: ~$10,000-50,000/year
- ❌ DataDog Monitoring: ~$15-31/host/month
- ✅ **Total Cost: $0** (just EKS infrastructure)

## 🔒 Security Notice

⚠️ **This deployment is NOT production-ready**:
- No authentication
- No encryption
- No authorization
- Suitable for personal/development use only

For production use, add:
1. TLS encryption
2. SCRAM-SHA-512 authentication
3. ACLs for authorization
4. Network policies
5. Regular backups

See Strimzi documentation: https://strimzi.io/docs/
