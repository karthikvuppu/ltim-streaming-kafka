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
helm install kafka-eks ./helm/kafka-eks --namespace kafka --create-namespace
```

### Development Environment

```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-dev.yaml
```

### Staging Environment

```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-staging.yaml
```

### Production Environment

```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-prod.yaml
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kafka.replicas` | Number of Kafka brokers | `3` |
| `kafka.version` | Kafka version | `3.6.0` |
| `kafka.storage.size` | Storage size per broker | `10Gi` |
| `kafka.storage.class` | Storage class | `gp2` |
| `kafka.resources.requests.memory` | Memory request | `2Gi` |
| `kafka.resources.requests.cpu` | CPU request | `500m` |
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
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values my-values.yaml
```

## Upgrading

```bash
# Upgrade with new values
helm upgrade kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-prod.yaml

# Dry run to see changes
helm upgrade kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-prod.yaml \
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
```

**LoadBalancer not provisioning:**
```bash
kubectl get svc -n kafka
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka
```

## Examples

See `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml` for complete configuration examples.

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Helm Documentation](https://helm.sh/docs/)
