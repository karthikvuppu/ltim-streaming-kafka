# Kafka on EKS Helm Chart

Production-ready Helm chart for deploying Apache Kafka on Amazon EKS using Strimzi Kafka Operator.

---

## 🚀 Deployment

**This chart is deployed automatically via GitHub Actions.**

👉 **See [../../README.md](../../README.md) for deployment instructions**

Simply push to deploy:
- Push to `sandbox` branch → GitHub Actions deploys with `values-sandbox.yaml`
- Push to `develop` branch → GitHub Actions deploys with `values-dev.yaml`
- Push to `main` branch → GitHub Actions deploys with `values-prod.yaml` (requires approval)

**All `helm` commands are executed by GitHub Actions workflows in `.github/workflows/deploy.yml`**

---

## 📋 Chart Information

### What This Chart Deploys

- **Strimzi Kafka Operator** (0.39.0)
- **Apache Kafka** cluster (3.6.0)
- **Apache Zookeeper** ensemble (3.8.3)
- **Entity Operators** (Topic & User management)
- **Optional**: Prometheus metrics exporters
- **Optional**: ServiceMonitor/PodMonitor for monitoring

### Dependencies

This chart automatically installs:
```yaml
dependencies:
  - name: strimzi-kafka-operator
    version: "0.39.0"
    repository: "https://strimzi.io/charts/"
```

GitHub Actions handles the `helm repo add` and `helm repo update` automatically.

---

## ⚙️ Configuration

### Environment Files

| File | Environment | Kafka Brokers | Storage | Use Case |
|------|-------------|---------------|---------|----------|
| `values-sandbox.yaml` | Sandbox | 1 | 10Gi (gp2) | Testing & experiments |
| `values-dev.yaml` | Development | 1 | 5Gi (gp2) | Active development |
| `values-prod.yaml` | Production | 3 | 100Gi (gp3) | Live workloads with HA |

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kafka.replicas` | Number of Kafka brokers | `3` |
| `kafka.version` | Kafka version | `3.6.0` |
| `kafka.storage.size` | Storage size per broker | `10Gi` |
| `kafka.storage.class` | Storage class (gp2/gp3) | `gp2` |
| `kafka.resources.requests.memory` | Memory request | `2Gi` |
| `kafka.resources.requests.cpu` | CPU request | `500m` |
| `kafka.listeners.plain.enabled` | Enable plain listener (9092) | `true` |
| `kafka.listeners.external.enabled` | Enable external LoadBalancer | `true` |
| `kafka.listeners.tls.enabled` | Enable TLS listener (9093) | `false` (prod: `true`) |
| `zookeeper.replicas` | Number of Zookeeper nodes | `3` |
| `zookeeper.storage.size` | Storage size per node | `5Gi` |
| `monitoring.serviceMonitor.enabled` | Enable Prometheus monitoring | `false` (prod: `true`) |
| `topics.enabled` | Auto-create example topics | `false` |

### Modifying Configuration

To change configuration for any environment, edit the corresponding values file and push:

```bash
# Edit configuration
vim helm/kafka-eks/values-dev.yaml

# Commit and push
git add helm/kafka-eks/values-dev.yaml
git commit -m "Update dev Kafka configuration"
git push origin develop

# GitHub Actions automatically deploys the updated configuration
```

### Example: Increasing Kafka Brokers

**File:** `helm/kafka-eks/values-prod.yaml`
```yaml
kafka:
  replicas: 5  # Increase from 3 to 5
  storage:
    size: 100Gi
    class: gp3
```

**Deploy:**
```bash
git add helm/kafka-eks/values-prod.yaml
git commit -m "Scale prod Kafka to 5 brokers"
git push origin main
# GitHub Actions deploys automatically (after approval)
```

### Example: Enabling TLS + Authentication

**File:** `helm/kafka-eks/values-prod.yaml`
```yaml
kafka:
  listeners:
    tls:
      enabled: true
      port: 9093
      type: internal
      authentication:
        type: scram-sha-512  # Enable SCRAM authentication
```

### Example: Enabling Monitoring

**File:** `helm/kafka-eks/values-prod.yaml`
```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    interval: 30s
  podMonitor:
    enabled: true
    namespace: monitoring
    interval: 30s
```

---

## 🔍 Chart Structure

```
helm/kafka-eks/
├── Chart.yaml                  # Chart metadata and dependencies
├── values.yaml                 # Default values (base template)
├── values-sandbox.yaml         # Sandbox environment config
├── values-dev.yaml            # Development environment config
├── values-prod.yaml           # Production environment config
├── templates/
│   ├── kafka.yaml             # Kafka cluster resource
│   ├── kafka-topics.yaml      # Optional Kafka topics
│   ├── kafka-users.yaml       # Optional Kafka users
│   ├── metrics-config.yaml    # Prometheus metrics configuration
│   ├── service-monitor.yaml   # Prometheus ServiceMonitor
│   ├── pod-monitor.yaml       # Prometheus PodMonitor
│   └── _helpers.tpl           # Template helpers
└── README.md                  # This file
```

---

## 📊 Deployed Resources

When deployed via GitHub Actions, this chart creates:

### Kubernetes Resources

- **Namespace**: `kafka`
- **Kafka CRD**: `kafka.strimzi.io/v1beta2`
  - Kafka StatefulSet (1-5 pods depending on environment)
  - Zookeeper StatefulSet (1-5 pods depending on environment)
- **Services**:
  - `my-kafka-kafka-bootstrap` (internal access, port 9092)
  - `my-kafka-kafka-external-bootstrap` (LoadBalancer, port 9094)
  - `my-kafka-zookeeper-client` (Zookeeper client access)
- **PersistentVolumeClaims**: One per Kafka/Zookeeper pod
- **ConfigMaps**: Metrics configuration
- **Operators**:
  - Strimzi Cluster Operator
  - Entity Operator (Topic + User operators)

### Access Points

**Internal (from within cluster):**
```
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

**External (via AWS NLB):**
```bash
# Get LoadBalancer endpoint
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap
```

---

## 🧪 Topics Management

### Auto-Create Topics on Deploy

Edit values file to enable:

**File:** `helm/kafka-eks/values-sandbox.yaml`
```yaml
topics:
  enabled: true
  topics:
    - name: test-topic
      partitions: 3
      replicas: 1
      config:
        retention.ms: 604800000  # 7 days
        compression.type: producer
```

Push to deploy:
```bash
git add helm/kafka-eks/values-sandbox.yaml
git commit -m "Enable test topics in sandbox"
git push origin sandbox
```

### Create Topics After Deployment

```bash
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: my-kafka
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 604800000
    min.insync.replicas: 2
EOF
```

---

## 🔐 Security Configuration

### Production Security (values-prod.yaml)

```yaml
kafka:
  listeners:
    # TLS encryption
    tls:
      enabled: true
      port: 9093
      type: internal
      # SCRAM-SHA-512 authentication
      authentication:
        type: scram-sha-512

  # Secure Kafka settings
  config:
    min.insync.replicas: 2
    unclean.leader.election.enable: false
```

### Creating Kafka Users (SCRAM)

```bash
kubectl apply -f - <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-user
  namespace: kafka
  labels:
    strimzi.io/cluster: my-kafka
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: my-topic
        operations:
          - Read
          - Write
EOF
```

---

## 📈 Monitoring

### Metrics Endpoints

Kafka and Zookeeper expose Prometheus metrics on:
- Kafka: `<pod>:9404/metrics`
- Zookeeper: `<pod>:9405/metrics`

### ServiceMonitor (Automatic)

When `monitoring.serviceMonitor.enabled: true`, the chart creates ServiceMonitor resources that Prometheus automatically discovers.

### View Metrics

```bash
# Port-forward to Kafka metrics
kubectl port-forward -n kafka my-kafka-kafka-0 9404:9404

# Access metrics
curl http://localhost:9404/metrics
```

---

## 🔧 Troubleshooting

### Check Deployment Status

```bash
# Via GitHub Actions
# Go to: https://github.com/<your-repo>/actions

# Via kubectl
kubectl get kafka -n kafka
kubectl get pods -n kafka
kubectl describe kafka my-kafka -n kafka
```

### Check Kafka Cluster

```bash
# Kafka pods
kubectl get pods -n kafka -l strimzi.io/name=my-kafka-kafka

# Kafka logs
kubectl logs -n kafka my-kafka-kafka-0 -c kafka

# Zookeeper logs
kubectl logs -n kafka my-kafka-zookeeper-0
```

### Check Operator

```bash
kubectl logs -n kafka deployment/strimzi-cluster-operator
```

### Common Issues

**PVCs not binding:**
```bash
kubectl get pvc -n kafka
kubectl get storageclass
# Solution: Ensure gp2/gp3 storage class exists
```

**LoadBalancer pending:**
```bash
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap
# Solution: Check AWS NLB creation, verify EKS cluster has LB controller
```

---

## 📚 Resources

- **Main Deployment Guide**: [../../README.md](../../README.md)
- **GitHub Actions Setup**: [../../GITHUB_ACTIONS_SETUP.md](../../GITHUB_ACTIONS_SETUP.md)
- **Strimzi Documentation**: https://strimzi.io/docs/
- **Apache Kafka Documentation**: https://kafka.apache.org/documentation/
- **Helm Documentation**: https://helm.sh/docs/

---

## 🎯 Quick Reference

### Deploy to Sandbox
```bash
git checkout sandbox
vim helm/kafka-eks/values-sandbox.yaml
git commit -am "Update sandbox config"
git push origin sandbox
```

### Deploy to Dev
```bash
git checkout develop
vim helm/kafka-eks/values-dev.yaml
git commit -am "Update dev config"
git push origin develop
```

### Deploy to Prod
```bash
git checkout main
# Create PR from develop
gh pr create --base main --head develop --title "Deploy to production"
# After approval and merge, GitHub Actions deploys automatically
```

**All Helm operations are handled by GitHub Actions - no manual commands needed!** 🚀
