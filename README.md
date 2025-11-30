# Kafka on EKS

Production-ready Apache Kafka deployment on Amazon EKS using Strimzi Kubernetes Operator.

## Quick Start

```bash
./deploy.sh
```

## Overview

This project provides an easy way to deploy Apache Kafka with Zookeeper on Amazon EKS (Elastic Kubernetes Service). It uses the Strimzi Kafka Operator, an open-source project for running Apache Kafka on Kubernetes.

## Features

- **Apache Kafka 3.6.0** - Latest stable release
- **Zookeeper ensemble** - 3-node cluster for high availability
- **Automated deployment** - One-command deployment script
- **Monitoring ready** - Optional Prometheus/Grafana integration
- **Production patterns** - Best practices for Kafka on Kubernetes
- **100% open source** - No licenses or subscriptions required

## Prerequisites

- Running Amazon EKS cluster
- `kubectl` configured to access your cluster
- `helm` 3.x installed

## Architecture

```
┌─────────────────────────────────────┐
│         EKS Cluster                 │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  Strimzi Operator            │  │
│  │  (Manages Kafka resources)   │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  Zookeeper Ensemble          │  │
│  │  (3 nodes)                   │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  Kafka Cluster               │  │
│  │  (3 brokers)                 │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  AWS NLB (optional)          │  │
│  │  (External access)           │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Repository Structure

```
.
├── README.md                      # This file
├── deploy.sh                      # Automated deployment script
├── undeploy.sh                    # Cleanup script
├── test-kafka.sh                  # Verification script
├── kafka-cluster/                 # Kafka configuration
│   ├── kafka-cluster.yaml         # Main cluster definition
│   └── kafka-topic-example.yaml   # Example topic configurations
└── monitoring-optional/           # Optional monitoring setup
    ├── README.md                  # Monitoring documentation
    ├── prometheus-servicemonitor.yaml
    └── prometheus-pod-monitor.yaml
```

## Installation

### Step 1: Deploy Kafka Cluster

Run the automated deployment script:

```bash
./deploy.sh
```

This will:
1. Create a `kafka` namespace
2. Install Strimzi Kafka Operator (v0.39.0)
3. Deploy a 3-node Zookeeper ensemble
4. Deploy a 3-broker Kafka cluster
5. Configure JMX metrics exporters

The deployment takes approximately 5-10 minutes.

### Step 2: Verify Deployment

Check the deployment status:

```bash
./test-kafka.sh
```

Or manually check:

```bash
# Check cluster status
kubectl get kafka -n kafka

# Check pods
kubectl get pods -n kafka

# Check services
kubectl get svc -n kafka
```

## Usage

### Accessing Kafka

**From within the Kubernetes cluster:**

```
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

**From your local machine:**

```bash
# Port forward to local machine
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092

# Connect to localhost:9092
```

**Via LoadBalancer (external access):**

```bash
# Get the LoadBalancer address
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap

# Use the EXTERNAL-IP on port 9094
```

### Creating Topics

Use the included example:

```bash
kubectl apply -f kafka-cluster/kafka-topic-example.yaml
```

Or create your own:

```yaml
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
```

### Testing Kafka

**Producer:**

```bash
kubectl run kafka-producer -ti \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 \
  --rm=true --restart=Never -- \
  bin/kafka-console-producer.sh \
  --bootstrap-server my-kafka-kafka-bootstrap:9092 \
  --topic test-topic
```

**Consumer:**

```bash
kubectl run kafka-consumer -ti \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 \
  --rm=true --restart=Never -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server my-kafka-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

## Configuration

### Scaling Kafka Brokers

Edit `kafka-cluster/kafka-cluster.yaml`:

```yaml
spec:
  kafka:
    replicas: 5  # Increase from 3 to 5
```

Apply changes:

```bash
kubectl apply -f kafka-cluster/kafka-cluster.yaml
```

Strimzi will perform a rolling update automatically.

### Scaling Zookeeper

Edit `kafka-cluster/kafka-cluster.yaml`:

```yaml
spec:
  zookeeper:
    replicas: 5  # Must be odd number
```

Apply changes:

```bash
kubectl apply -f kafka-cluster/kafka-cluster.yaml
```

### Storage Configuration

Default configuration uses:
- **Kafka**: 10GB per broker (gp2 storage class)
- **Zookeeper**: 5GB per node (gp2 storage class)

To modify, edit the `storage` section in `kafka-cluster/kafka-cluster.yaml`.

### Resource Limits

Default resource allocation:

**Kafka brokers:**
- Requests: 500m CPU, 2Gi memory
- Limits: 2000m CPU, 4Gi memory

**Zookeeper nodes:**
- Requests: 250m CPU, 1Gi memory
- Limits: 1000m CPU, 2Gi memory

Adjust in `kafka-cluster/kafka-cluster.yaml` as needed.

## Monitoring

### Option 1: Prometheus + Grafana

See [monitoring-optional/README.md](monitoring-optional/README.md) for detailed setup instructions.

Quick install:

```bash
# Install Prometheus operator stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Apply Kafka metrics monitors
kubectl apply -f monitoring-optional/
```

### Option 2: Kafka UI

Lightweight web UI for Kafka:

```bash
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm install kafka-ui kafka-ui/kafka-ui \
  --set envs.config.KAFKA_CLUSTERS_0_NAME=my-kafka \
  --set envs.config.KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=my-kafka-kafka-bootstrap.kafka:9092 \
  --namespace kafka

# Access via port-forward
kubectl port-forward -n kafka svc/kafka-ui 8080:80
```

## Security

The default deployment is configured for ease of use without authentication or encryption.

### Adding TLS

Update `kafka-cluster/kafka-cluster.yaml`:

```yaml
spec:
  kafka:
    listeners:
      - name: tls
        port: 9093
        type: internal
        tls: true
```

### Adding Authentication

Enable SCRAM-SHA-512:

```yaml
spec:
  kafka:
    listeners:
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: scram-sha-512
```

Create users:

```yaml
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
```

## Cleanup

Remove all resources:

```bash
./undeploy.sh
```

This will delete:
- Kafka cluster
- Zookeeper ensemble
- Strimzi operator
- Persistent volume claims
- Namespace (optional)

## Troubleshooting

### Check Operator Logs

```bash
kubectl logs -n kafka deployment/strimzi-cluster-operator
```

### Check Kafka Broker Logs

```bash
kubectl logs -n kafka my-kafka-kafka-0 -c kafka
```

### Check Zookeeper Logs

```bash
kubectl logs -n kafka my-kafka-zookeeper-0
```

### Common Issues

**Pods stuck in Pending:**
- Check if your EKS cluster has sufficient resources
- Verify storage class exists: `kubectl get storageclass`

**LoadBalancer not provisioning:**
- Ensure AWS Load Balancer Controller is installed in your cluster
- Check service annotations for correct AWS configuration

**Connection refused:**
- Verify Kafka is ready: `kubectl get kafka -n kafka`
- Check service endpoints: `kubectl get endpoints -n kafka`

## Technology Stack

| Component | Version | License |
|-----------|---------|---------|
| Apache Kafka | 3.6.0 | Apache 2.0 |
| Apache Zookeeper | 3.8.3 | Apache 2.0 |
| Strimzi Operator | 0.39.0 | Apache 2.0 |

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## License

This project is open source and available under the Apache 2.0 License.

---

**Get started in 5 minutes:**

```bash
./deploy.sh
```
