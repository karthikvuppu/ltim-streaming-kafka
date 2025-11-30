# Kafka on EKS

Production-ready Apache Kafka deployment on Amazon EKS using Strimzi Kafka Operator and Helm.

## Overview

Deploy Apache Kafka and Zookeeper on Amazon EKS with three environment configurations:
- **Sandbox** - Testing and experiments (1 broker, minimal resources)
- **Development** - Active development (1 broker, cost-effective)
- **Production** - Live workloads (3+ brokers, HA, security enabled)

### Features

- ✅ **Apache Kafka 3.6.0** - Latest stable release
- ✅ **Apache Zookeeper 3.8.3** - Reliable coordination service
- ✅ **Strimzi Operator 0.39.0** - Kubernetes-native Kafka management
- ✅ **Three Environments** - Sandbox, Dev, Prod configurations
- ✅ **Production Ready** - HA, TLS, authentication, monitoring
- ✅ **AWS NLB Integration** - External access via Network Load Balancer
- ✅ **100% Open Source** - No enterprise licenses required

## Prerequisites

- Amazon EKS cluster (1.24+)
- kubectl configured for your cluster
- Helm 3.8 or higher
- AWS CLI configured

## Quick Start

### 1. Add Strimzi Helm Repository

```bash
helm repo add strimzi https://strimzi.io/charts/
helm repo update
```

### 2. Deploy to Sandbox

```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-sandbox.yaml
```

### 3. Verify Deployment

```bash
kubectl get kafka -n kafka
kubectl get pods -n kafka
```

### 4. Test Kafka

```bash
./test-kafka.sh
```

That's it! Kafka is now running on your EKS cluster.

## Deployment Scripts

### Deploy Script

The `deploy.sh` script handles deployment for all environments:

```bash
# Deploy to sandbox
./deploy.sh sandbox

# Deploy to development
./deploy.sh dev

# Deploy to production
./deploy.sh prod
```

### Undeploy Script

```bash
# Remove deployment (keeps data)
./undeploy.sh sandbox

# Remove deployment and delete data
./undeploy.sh sandbox --delete-data
```

### Test Script

```bash
# Run Kafka producer/consumer test
./test-kafka.sh
```

## Environment Configurations

### Sandbox Environment

**Use case:** Testing, experiments, POC
**File:** `helm/kafka-eks/values-sandbox.yaml`

```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-sandbox.yaml
```

**Configuration:**
- Kafka brokers: 1
- Zookeeper nodes: 1
- Storage: 10Gi (gp2)
- Resources: Minimal (512Mi-1Gi memory)
- Security: Plain text (no TLS)
- Topics: Auto-create enabled

### Development Environment

**Use case:** Active development, integration testing
**File:** `helm/kafka-eks/values-dev.yaml`

```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-dev.yaml
```

**Configuration:**
- Kafka brokers: 1
- Zookeeper nodes: 1
- Storage: 5Gi (gp2)
- Resources: Minimal (1Gi memory)
- Security: Plain text (no TLS)
- Retention: 1 day

### Production Environment

**Use case:** Live workloads, high availability
**File:** `helm/kafka-eks/values-prod.yaml`

```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-prod.yaml
```

**Configuration:**
- Kafka brokers: 3
- Zookeeper nodes: 5
- Storage: 100Gi (gp3 - better IOPS)
- Resources: Production-grade (4-8Gi memory)
- Security: TLS + SCRAM-SHA-512 authentication
- Monitoring: Prometheus enabled
- Retention: 7 days
- Replication: Factor 3, MinISR 2

## Repository Structure

```
.
├── helm/kafka-eks/              # Helm chart
│   ├── Chart.yaml              # Chart metadata
│   ├── values.yaml             # Default values
│   ├── values-sandbox.yaml     # Sandbox environment
│   ├── values-dev.yaml         # Development environment
│   ├── values-prod.yaml        # Production environment
│   ├── templates/              # Kubernetes manifests
│   │   ├── kafka.yaml          # Kafka cluster resource
│   │   ├── kafka-topics.yaml   # Topic definitions
│   │   ├── kafka-users.yaml    # User definitions
│   │   ├── metrics-config.yaml # Prometheus metrics
│   │   ├── service-monitor.yaml# ServiceMonitor
│   │   └── pod-monitor.yaml    # PodMonitor
│   └── README.md               # Chart documentation
├── deploy.sh                    # Deployment script
├── undeploy.sh                  # Cleanup script
├── test-kafka.sh                # Testing script
├── README.md                    # This file
└── LICENSE                      # Apache 2.0
```

## Manual Deployment

### Step-by-Step Installation

**1. Create namespace:**
```bash
kubectl create namespace kafka
```

**2. Add Helm repository:**
```bash
helm repo add strimzi https://strimzi.io/charts/
helm repo update
```

**3. Install the chart:**
```bash
# Choose your environment: sandbox, dev, or prod
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-prod.yaml
```

**4. Wait for deployment:**
```bash
kubectl wait kafka/my-kafka --for=condition=Ready --timeout=300s -n kafka
```

**5. Verify:**
```bash
kubectl get kafka -n kafka
kubectl get pods -n kafka
```

## Upgrading

### Upgrade Configuration

```bash
# Edit values file
vim helm/kafka-eks/values-prod.yaml

# Upgrade deployment
helm upgrade kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-prod.yaml
```

### Dry Run (Preview Changes)

```bash
helm upgrade kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-prod.yaml \
  --dry-run --debug
```

### Rollback

```bash
# List releases
helm list -n kafka

# Rollback to previous version
helm rollback kafka-eks -n kafka

# Rollback to specific revision
helm rollback kafka-eks 1 -n kafka
```

## Accessing Kafka

### Internal Access (from within cluster)

```bash
# Bootstrap server
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

### External Access (via LoadBalancer)

```bash
# Get LoadBalancer endpoint
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap

# Use the EXTERNAL-IP to connect from outside the cluster
```

### Port Forwarding (for local testing)

```bash
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
```

Now connect to `localhost:9092`

## Creating Topics

### Via Kubernetes CRD

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
    retention.ms: 604800000  # 7 days
    compression.type: producer
    min.insync.replicas: 2
EOF
```

### Via Auto-Creation (Sandbox/Dev)

Topics can be auto-created when `auto.create.topics.enable: true` in values file.

### Enable Example Topics

Edit values file:
```yaml
topics:
  enabled: true
  topics:
    - name: test-topic
      partitions: 3
      replicas: 1
```

Then upgrade:
```bash
helm upgrade kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-sandbox.yaml
```

## Testing Kafka

### Using Included Script

```bash
./test-kafka.sh
```

### Manual Producer Test

```bash
kubectl run kafka-producer -ti -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 \
  --rm --restart=Never -- \
  bin/kafka-console-producer.sh \
  --bootstrap-server my-kafka-kafka-bootstrap:9092 \
  --topic test-topic
```

### Manual Consumer Test

```bash
kubectl run kafka-consumer -ti -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 \
  --rm --restart=Never -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server my-kafka-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

## Security

### Production Security Features

**TLS Encryption:**
```yaml
kafka:
  listeners:
    tls:
      enabled: true
      port: 9093
```

**SCRAM-SHA-512 Authentication:**
```yaml
kafka:
  listeners:
    tls:
      enabled: true
      authentication:
        type: scram-sha-512
```

### Creating Kafka Users

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
          - Describe
EOF
```

### Retrieving User Credentials

```bash
# Get password
kubectl get secret my-user -n kafka -o jsonpath='{.data.password}' | base64 -d
```

## Monitoring

### Enable Prometheus Monitoring

Edit `values-prod.yaml`:
```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    interval: 30s
  podMonitor:
    enabled: true
```

### View Metrics

```bash
# Port-forward to Kafka metrics
kubectl port-forward -n kafka my-kafka-kafka-0 9404:9404

# Access metrics
curl http://localhost:9404/metrics
```

### Prometheus Targets

Kafka exposes metrics on:
- Kafka: `<pod>:9404/metrics`
- Zookeeper: `<pod>:9405/metrics`

## Troubleshooting

### Check Cluster Status

```bash
kubectl get kafka -n kafka
kubectl describe kafka my-kafka -n kafka
```

### Check Pods

```bash
kubectl get pods -n kafka
kubectl logs -n kafka my-kafka-kafka-0 -c kafka
kubectl logs -n kafka my-kafka-zookeeper-0
```

### Check Operator Logs

```bash
kubectl logs -n kafka deployment/strimzi-cluster-operator
```

### Common Issues

**Pods not starting:**
```bash
kubectl describe pod <pod-name> -n kafka
# Check events for resource constraints or image pull errors
```

**PVCs not binding:**
```bash
kubectl get pvc -n kafka
kubectl get storageclass
# Ensure gp2 or gp3 storage class exists in your cluster
```

**LoadBalancer not provisioning:**
```bash
kubectl get svc -n kafka
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka
# Check AWS Load Balancer Controller is installed
```

## Configuration Examples

### Scale Kafka Brokers

```yaml
kafka:
  replicas: 5  # Scale to 5 brokers
```

### Increase Storage

```yaml
kafka:
  storage:
    size: 200Gi  # Increase to 200Gi
```

### Change Resource Limits

```yaml
kafka:
  resources:
    requests:
      memory: 8Gi
      cpu: 4000m
    limits:
      memory: 16Gi
      cpu: 8000m
```

### Enable AWS NLB Annotations

```yaml
kafka:
  listeners:
    external:
      enabled: true
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-internal: "true"
```

## Cleanup

### Remove Deployment (Keep Data)

```bash
helm uninstall kafka-eks -n kafka
```

### Remove Deployment and Data

```bash
# Uninstall chart
helm uninstall kafka-eks -n kafka

# Delete PVCs (WARNING: This deletes all data!)
kubectl delete pvc -n kafka --all

# Delete namespace
kubectl delete namespace kafka
```

### Using Undeploy Script

```bash
# Keep data
./undeploy.sh prod

# Delete data
./undeploy.sh prod --delete-data
```

## Technology Stack

| Component | Version | License |
|-----------|---------|---------|
| Apache Kafka | 3.6.0 | Apache 2.0 |
| Apache Zookeeper | 3.8.3 | Apache 2.0 |
| Strimzi Operator | 0.39.0 | Apache 2.0 |
| Helm | 3.8+ | Apache 2.0 |

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Helm Documentation](https://helm.sh/docs/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## License

Apache 2.0 - See [LICENSE](LICENSE) file.

---

## Quick Reference

```bash
# Deploy
./deploy.sh sandbox    # Sandbox environment
./deploy.sh dev        # Development environment
./deploy.sh prod       # Production environment

# Test
./test-kafka.sh        # Run producer/consumer test

# Undeploy
./undeploy.sh sandbox  # Remove sandbox deployment

# Manual Helm commands
helm install kafka-eks ./helm/kafka-eks -n kafka --create-namespace -f ./helm/kafka-eks/values-prod.yaml
helm upgrade kafka-eks ./helm/kafka-eks -n kafka -f ./helm/kafka-eks/values-prod.yaml
helm uninstall kafka-eks -n kafka
```

---

**Ready to deploy Kafka on EKS!** 🚀
