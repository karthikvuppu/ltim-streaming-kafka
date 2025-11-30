# Kafka on EKS Helm Chart

Production-ready Helm chart for deploying Apache Kafka on Amazon EKS using Strimzi Kafka Operator.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.8+
- Running Amazon EKS cluster
- kubectl configured to access your cluster

## Installation

### Quick Start

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Install with default values
helm install kafka-eks . --namespace kafka --create-namespace
```

### Environment-Specific Installation

**Sandbox Environment:**
```bash
helm install kafka-eks . \
  --namespace kafka \
  --create-namespace \
  --values values-sandbox.yaml
```

**Development Environment:**
```bash
helm install kafka-eks . \
  --namespace kafka \
  --create-namespace \
  --values values-dev.yaml
```

**Production Environment:**
```bash
helm install kafka-eks . \
  --namespace kafka \
  --create-namespace \
  --values values-prod.yaml
```

## Configuration

### Environment Values Files

| File | Environment | Kafka Brokers | Storage | Use Case |
|------|-------------|---------------|---------|----------|
| `values-sandbox.yaml` | Sandbox | 1 | 10Gi (gp2) | Testing & experiments |
| `values-dev.yaml` | Development | 1 | 5Gi (gp2) | Active development |
| `values-prod.yaml` | Production | 3 | 100Gi (gp3) | Live workloads with HA |

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kafka.replicas` | Number of Kafka brokers | `3` |
| `kafka.version` | Kafka version | `3.6.0` |
| `kafka.storage.size` | Storage size per broker | `10Gi` |
| `kafka.storage.class` | Storage class | `gp2` |
| `kafka.resources.requests.memory` | Memory request | `2Gi` |
| `kafka.resources.requests.cpu` | CPU request | `500m` |
| `kafka.listeners.plain.enabled` | Enable plain listener (9092) | `true` |
| `kafka.listeners.external.enabled` | Enable external LoadBalancer | `true` |
| `kafka.listeners.tls.enabled` | Enable TLS listener (9093) | `false` |
| `zookeeper.replicas` | Number of Zookeeper nodes | `3` |
| `zookeeper.storage.size` | Storage size per node | `5Gi` |
| `monitoring.serviceMonitor.enabled` | Enable Prometheus monitoring | `false` |

### Custom Values

Create a custom values file:

```yaml
# my-values.yaml
kafka:
  replicas: 5
  storage:
    size: 50Gi
    class: gp3
  resources:
    requests:
      memory: 4Gi
      cpu: 2000m

zookeeper:
  replicas: 5
```

Install with custom values:

```bash
helm install kafka-eks . \
  --namespace kafka \
  --values my-values.yaml
```

## Upgrading

```bash
# Upgrade with new values
helm upgrade kafka-eks . \
  --namespace kafka \
  --values values-prod.yaml

# Dry run to see changes
helm upgrade kafka-eks . \
  --namespace kafka \
  --values values-prod.yaml \
  --dry-run --debug
```

## Uninstalling

```bash
# Uninstall the chart
helm uninstall kafka-eks --namespace kafka

# Delete PVCs (optional - this will delete data!)
kubectl delete pvc -n kafka --all

# Delete namespace (optional)
kubectl delete namespace kafka
```

## Chart Structure

```
helm/kafka-eks/
├── Chart.yaml                  # Chart metadata and dependencies
├── values.yaml                 # Default values
├── values-sandbox.yaml         # Sandbox configuration
├── values-dev.yaml            # Development configuration
├── values-prod.yaml           # Production configuration
├── templates/
│   ├── kafka.yaml             # Kafka cluster resource
│   ├── kafka-topics.yaml      # Optional Kafka topics
│   ├── kafka-users.yaml       # Optional Kafka users
│   ├── metrics-config.yaml    # Prometheus metrics config
│   ├── service-monitor.yaml   # Prometheus ServiceMonitor
│   ├── pod-monitor.yaml       # Prometheus PodMonitor
│   └── _helpers.tpl           # Template helpers
└── README.md                  # This file
```

## What Gets Deployed

### Kubernetes Resources

- **Namespace**: `kafka`
- **Strimzi Cluster Operator**: Manages Kafka resources
- **Kafka StatefulSet**: Kafka broker pods
- **Zookeeper StatefulSet**: Zookeeper pods
- **Services**:
  - `my-kafka-kafka-bootstrap` - Internal access (port 9092)
  - `my-kafka-kafka-external-bootstrap` - LoadBalancer (port 9094)
  - `my-kafka-zookeeper-client` - Zookeeper client
- **PersistentVolumeClaims**: Storage for Kafka/Zookeeper
- **Entity Operator**: Topic and User management

### Deployed Components

| Component | Version | Image |
|-----------|---------|-------|
| Strimzi Operator | 0.39.0 | quay.io/strimzi/operator:0.39.0 |
| Kafka | 3.6.0 | quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 |
| Zookeeper | 3.8.3 | quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 |

## Accessing Kafka

### Internal (from within cluster)

```
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

### External (via LoadBalancer)

```bash
# Get LoadBalancer endpoint
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap
```

### Port Forwarding

```bash
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
```

## Topics

### Enable Example Topics

```yaml
topics:
  enabled: true
  topics:
    - name: my-topic
      partitions: 3
      replicas: 3
      config:
        retention.ms: 604800000  # 7 days
```

### Create Topics After Installation

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
EOF
```

## Security

### Enable TLS

```yaml
kafka:
  listeners:
    tls:
      enabled: true
      port: 9093
      type: internal
```

### Enable Authentication (SCRAM-SHA-512)

```yaml
kafka:
  listeners:
    tls:
      enabled: true
      authentication:
        type: scram-sha-512
```

### Create Kafka Users

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

## Monitoring

### Enable Prometheus ServiceMonitor

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    interval: 30s
```

### View Metrics

```bash
# Port-forward Prometheus (if installed)
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Access Prometheus at http://localhost:9090
```

### Metrics Endpoints

- Kafka metrics: `<pod>:9404/metrics`
- Zookeeper metrics: `<pod>:9405/metrics`

## Troubleshooting

### Check Kafka Cluster Status

```bash
kubectl get kafka -n kafka
kubectl describe kafka my-kafka -n kafka
```

### Check Pods

```bash
kubectl get pods -n kafka
kubectl logs -n kafka my-kafka-kafka-0 -c kafka
```

### Check Strimzi Operator

```bash
kubectl logs -n kafka deployment/strimzi-cluster-operator
```

### Common Issues

**PVCs not binding:**
```bash
kubectl get pvc -n kafka
kubectl get storageclass
# Ensure gp2 or gp3 storage class exists
```

**LoadBalancer not provisioning:**
```bash
kubectl get svc -n kafka
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka
# Check AWS Load Balancer Controller is installed
```

## Configuration Examples

### Sandbox Configuration (values-sandbox.yaml)

```yaml
kafka:
  replicas: 1
  storage:
    size: 10Gi
  resources:
    requests:
      memory: 1Gi
      cpu: 500m

zookeeper:
  replicas: 1
  storage:
    size: 5Gi

topics:
  enabled: true  # Auto-create test topics
```

### Development Configuration (values-dev.yaml)

```yaml
kafka:
  replicas: 1
  storage:
    size: 5Gi
  resources:
    requests:
      memory: 1Gi
      cpu: 250m
  config:
    log.retention.hours: 24  # 1 day retention
```

### Production Configuration (values-prod.yaml)

```yaml
kafka:
  replicas: 3
  storage:
    size: 100Gi
    class: gp3
  listeners:
    tls:
      enabled: true
      authentication:
        type: scram-sha-512
  resources:
    requests:
      memory: 4Gi
      cpu: 2000m

zookeeper:
  replicas: 5
  storage:
    size: 20Gi
    class: gp3

monitoring:
  serviceMonitor:
    enabled: true
```

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Helm Documentation](https://helm.sh/docs/)

## See Also

- [Main README](../../README.md) - Deployment guides and scripts
- [deploy.sh](../../deploy.sh) - Automated deployment script
- [test-kafka.sh](../../test-kafka.sh) - Kafka testing script
