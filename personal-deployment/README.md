# Personal Kafka & Zookeeper Deployment on EKS

This is a simplified, open-source deployment of Apache Kafka and Zookeeper on your personal EKS cluster.

## What's Removed

- ✅ Confluent Enterprise (replaced with Apache Kafka)
- ✅ DataDog monitoring
- ✅ OAuth authentication
- ✅ mTLS authentication
- ✅ LDAP integration
- ✅ All proprietary licenses
- ✅ Enterprise-specific configurations

## What You Get

- Apache Kafka (open-source)
- Zookeeper ensemble
- Strimzi Kafka Operator (open-source)
- Simple, unsecured deployment (suitable for personal/dev use)
- Optional: Prometheus metrics (open-source monitoring)

## Prerequisites

1. Running EKS cluster
2. kubectl configured to access your cluster
3. Helm 3.x installed

## Deployment Steps

### Step 1: Install Strimzi Kafka Operator

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Create namespace
kubectl create namespace kafka

# Install Strimzi operator
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace kafka \
  --version 0.39.0
```

### Step 2: Deploy Kafka Cluster with Zookeeper

```bash
# Deploy Kafka cluster (includes Zookeeper)
kubectl apply -f kafka-cluster/kafka-cluster.yaml -n kafka

# Wait for deployment to complete
kubectl wait kafka/my-kafka --for=condition=Ready --timeout=300s -n kafka
```

### Step 3: Verify Deployment

```bash
# Check Kafka cluster status
kubectl get kafka -n kafka

# Check all pods
kubectl get pods -n kafka

# Check Kafka logs
kubectl logs -n kafka my-kafka-kafka-0 -c kafka
```

### Step 4: Access Kafka

```bash
# Port-forward to access Kafka from your local machine
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092

# Kafka brokers are now accessible at localhost:9092
```

## Configuration Files

- `kafka-cluster/kafka-cluster.yaml` - Main Kafka cluster definition
- `kafka-cluster/kafka-topic-example.yaml` - Example topic creation
- `kafka-cluster/kafka-user-example.yaml` - Example user (if needed later)
- `monitoring-optional/prometheus-rules.yaml` - Optional Prometheus monitoring

## Scaling

### Scale Kafka Brokers

Edit `kafka-cluster/kafka-cluster.yaml` and change:
```yaml
spec:
  kafka:
    replicas: 3  # Change to desired number
```

Then apply:
```bash
kubectl apply -f kafka-cluster/kafka-cluster.yaml -n kafka
```

### Scale Zookeeper

Edit `kafka-cluster/kafka-cluster.yaml` and change:
```yaml
spec:
  zookeeper:
    replicas: 3  # Change to desired number (must be odd)
```

## Storage

- Uses EKS default storage class (gp2)
- 10GB per Kafka broker
- 5GB per Zookeeper node
- Adjust in `kafka-cluster.yaml` as needed

## Security Notes

⚠️ **This deployment is NOT production-ready**:
- No authentication enabled
- No encryption (TLS)
- No authorization
- Suitable for personal/development use only

To add security later, refer to Strimzi documentation:
https://strimzi.io/docs/operators/latest/overview.html

## Troubleshooting

```bash
# Check operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator

# Check Kafka cluster status
kubectl describe kafka my-kafka -n kafka

# Check Zookeeper pods
kubectl get pods -n kafka -l strimzi.io/name=my-kafka-zookeeper

# Check Kafka pods
kubectl get pods -n kafka -l strimzi.io/name=my-kafka-kafka
```

## Clean Up

```bash
# Delete Kafka cluster
kubectl delete kafka my-kafka -n kafka

# Uninstall operator
helm uninstall strimzi-kafka-operator -n kafka

# Delete namespace
kubectl delete namespace kafka
```
