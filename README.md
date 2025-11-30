# Kafka on EKS

Production-ready Apache Kafka deployment on Amazon EKS using Strimzi Kafka Operator and Helm.

## Overview

Deploy Apache Kafka and Zookeeper on Amazon EKS with three pre-configured environments:
- **Sandbox** - Testing and experiments (1 broker, minimal resources)
- **Development** - Active development (1 broker, cost-effective)
- **Production** - Live workloads (3+ brokers, HA, TLS, authentication)

### Features

- ✅ **Apache Kafka 3.6.0** - Latest stable release
- ✅ **Apache Zookeeper 3.8.3** - Reliable coordination
- ✅ **Strimzi Operator 0.39.0** - Kubernetes-native management
- ✅ **Production Ready** - HA, TLS, SCRAM-SHA-512, monitoring
- ✅ **AWS Integration** - NLB, EBS gp3, optimized for EKS
- ✅ **100% Open Source** - No enterprise licenses required

## Quick Start

### Prerequisites

- Amazon EKS cluster (Kubernetes 1.24+)
- kubectl configured for your cluster
- Helm 3.8 or higher
- AWS CLI configured

### Deploy in 3 Steps

**1. Add Strimzi Helm repository:**
```bash
helm repo add strimzi https://strimzi.io/charts/
helm repo update
```

**2. Deploy Kafka:**
```bash
# Sandbox environment
./deploy.sh sandbox

# OR Development environment
./deploy.sh dev

# OR Production environment
./deploy.sh prod
```

**3. Verify deployment:**
```bash
kubectl get kafka -n kafka
kubectl get pods -n kafka
```

That's it! Kafka is now running on your EKS cluster.

## Manual Deployment

### Using Helm Directly

**Sandbox:**
```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-sandbox.yaml
```

**Development:**
```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-dev.yaml
```

**Production:**
```bash
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-prod.yaml
```

### Using Deployment Script

```bash
./deploy.sh <environment>
```

**Options:**
- `sandbox` - Testing environment (1 broker, 10Gi storage)
- `dev` - Development environment (1 broker, 5Gi storage)
- `prod` - Production environment (3 brokers, 100Gi storage, HA)

The script will:
1. ✅ Check prerequisites (kubectl, helm)
2. ✅ Create kafka namespace
3. ✅ Add Strimzi Helm repository
4. ✅ Deploy Kafka cluster
5. ✅ Wait for cluster to be ready
6. ✅ Display connection information

## Environment Comparison

| Feature | Sandbox | Development | Production |
|---------|---------|-------------|------------|
| **Kafka Brokers** | 1 | 1 | 3 |
| **Zookeeper Nodes** | 1 | 1 | 5 |
| **Storage** | 10Gi (gp2) | 5Gi (gp2) | 100Gi (gp3) |
| **Memory** | 1Gi | 1Gi | 4Gi |
| **TLS** | ❌ | ❌ | ✅ |
| **Authentication** | ❌ | ❌ | ✅ SCRAM-SHA-512 |
| **Monitoring** | ❌ | ❌ | ✅ Prometheus |
| **HA** | ❌ | ❌ | ✅ |
| **Replication Factor** | 1 | 1 | 3 |
| **Retention** | 7 days | 1 day | 7 days |

## Accessing Kafka

### Internal (from within cluster)

```
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

### External (via AWS NLB)

```bash
# Get LoadBalancer endpoint
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap
```

### Port Forwarding (local testing)

```bash
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
```

Now connect to `localhost:9092`

## Testing Kafka

### Quick Test

```bash
./test-kafka.sh
```

This script will:
1. Create a test topic
2. Send test messages (producer)
3. Consume and verify messages (consumer)

### Manual Testing

**Producer:**
```bash
kubectl run kafka-producer -ti -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 \
  --rm --restart=Never -- \
  bin/kafka-console-producer.sh \
  --bootstrap-server my-kafka-kafka-bootstrap:9092 \
  --topic test-topic
```

**Consumer:**
```bash
kubectl run kafka-consumer -ti -n kafka \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 \
  --rm --restart=Never -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server my-kafka-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

## Common Operations

### Create Topic

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

### Create User (Production)

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
        operations: [Read, Write, Describe]
EOF
```

**Get password:**
```bash
kubectl get secret my-user -n kafka -o jsonpath='{.data.password}' | base64 -d
```

### Upgrade Configuration

**1. Edit values file:**
```bash
vim helm/kafka-eks/values-prod.yaml
```

**2. Apply changes:**
```bash
helm upgrade kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-prod.yaml
```

**3. Monitor rollout:**
```bash
kubectl rollout status statefulset/my-kafka-kafka -n kafka
```

### Scale Brokers

**Update values file:**
```yaml
kafka:
  replicas: 5  # Scale from 3 to 5
```

**Apply:**
```bash
helm upgrade kafka-eks ./helm/kafka-eks -n kafka -f ./helm/kafka-eks/values-prod.yaml
```

Strimzi handles rolling update and partition rebalancing automatically.

## Monitoring

### Check Cluster Status

```bash
# Kafka cluster
kubectl get kafka -n kafka

# Pods
kubectl get pods -n kafka

# Services
kubectl get svc -n kafka
```

### View Logs

```bash
# Kafka broker logs
kubectl logs -n kafka my-kafka-kafka-0 -c kafka

# Zookeeper logs
kubectl logs -n kafka my-kafka-zookeeper-0

# Operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator
```

### Prometheus Metrics

**Production environment has Prometheus integration enabled.**

Metrics endpoints:
- Kafka: `<pod>:9404/metrics`
- Zookeeper: `<pod>:9405/metrics`

Port-forward to view:
```bash
kubectl port-forward -n kafka my-kafka-kafka-0 9404:9404
curl http://localhost:9404/metrics
```

## Cleanup

### Remove Deployment (Keep Data)

```bash
./undeploy.sh <environment>
```

OR

```bash
helm uninstall kafka-eks -n kafka
```

### Remove Deployment and Data

```bash
./undeploy.sh <environment> --delete-data
```

OR

```bash
helm uninstall kafka-eks -n kafka
kubectl delete pvc -n kafka --all  # ⚠️  Deletes all data!
kubectl delete namespace kafka
```

## Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod my-kafka-kafka-0 -n kafka
kubectl logs my-kafka-kafka-0 -n kafka -c kafka
```

**Common causes:**
- Insufficient cluster resources
- PVC binding issues
- Image pull errors

### PVCs Not Binding

```bash
kubectl get pvc -n kafka
kubectl get storageclass
```

**Solution:**
- Ensure EBS CSI driver is installed
- Verify storage class exists (gp2/gp3)

### LoadBalancer Pending

```bash
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka
```

**Solution:**
- Install AWS Load Balancer Controller
- Check VPC subnet tags
- Verify IAM permissions

## Repository Structure

```
.
├── helm/kafka-eks/              # Helm chart
│   ├── Chart.yaml              # Chart metadata
│   ├── values.yaml             # Default values
│   ├── values-sandbox.yaml     # Sandbox config
│   ├── values-dev.yaml         # Development config
│   ├── values-prod.yaml        # Production config
│   └── templates/              # Kubernetes manifests
├── deploy.sh                    # Deployment script
├── undeploy.sh                  # Cleanup script
├── test-kafka.sh                # Testing script
├── README.md                    # This file
├── ARCHITECTURE.md              # Detailed architecture docs
└── LICENSE                      # Apache 2.0
```

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture, configuration reference, and advanced topics
- **[LICENSE](LICENSE)** - Apache 2.0 license

## Technology Stack

| Component | Version | Image |
|-----------|---------|-------|
| Apache Kafka | 3.6.0 | quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 |
| Apache Zookeeper | 3.8.3 | quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 |
| Strimzi Operator | 0.39.0 | quay.io/strimzi/operator:0.39.0 |
| Helm | 3.8+ | - |

## Support & Resources

- **Strimzi Documentation:** https://strimzi.io/docs/
- **Apache Kafka Documentation:** https://kafka.apache.org/documentation/
- **AWS EKS Best Practices:** https://aws.github.io/aws-eks-best-practices/

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

# Monitor
kubectl get kafka -n kafka
kubectl get pods -n kafka
kubectl logs -n kafka my-kafka-kafka-0 -c kafka

# Cleanup
./undeploy.sh sandbox
./undeploy.sh prod --delete-data

# Helm commands
helm install kafka-eks ./helm/kafka-eks -n kafka -f ./helm/kafka-eks/values-prod.yaml
helm upgrade kafka-eks ./helm/kafka-eks -n kafka -f ./helm/kafka-eks/values-prod.yaml
helm uninstall kafka-eks -n kafka
```

For detailed configuration options, architecture details, security setup, and troubleshooting, see **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

**Ready to deploy Kafka on EKS!** 🚀
