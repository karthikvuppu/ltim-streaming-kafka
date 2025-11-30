# Kafka on EKS

Production-ready Apache Kafka deployment on Amazon EKS using Strimzi Kafka Operator, Helm charts, and GitHub Actions CI/CD.

## Quick Start

```bash
# Deploy to development
./deploy.sh dev

# Deploy to staging
./deploy.sh staging

# Deploy to production
./deploy.sh prod
```

## Overview

This project provides a complete solution for deploying Apache Kafka with Zookeeper on Amazon EKS. It includes:

- **Helm Charts** - Packaged, configurable deployments
- **GitHub Actions** - Automated CI/CD pipelines
- **Multi-Environment** - Dev, staging, and production configurations
- **Monitoring** - Optional Prometheus/Grafana integration
- **100% Open Source** - No licenses or subscriptions required

## Features

- ✅ **Apache Kafka 3.6.0** - Latest stable release
- ✅ **Helm Charts** - Easy deployment and upgrades
- ✅ **GitHub Actions** - Automated deployment workflows
- ✅ **Multi-Environment** - Separate configs for dev/staging/prod
- ✅ **Zookeeper Ensemble** - 3-5 node clusters
- ✅ **Automated Scripts** - One-command deployment
- ✅ **Monitoring Ready** - Prometheus/Grafana integration
- ✅ **Production Patterns** - Best practices for Kafka on Kubernetes

## Prerequisites

- Running Amazon EKS cluster
- `kubectl` configured to access your cluster
- `helm` 3.8+ installed
- GitHub repository (for CI/CD)

## Repository Structure

```
.
├── README.md                      # This file
├── deploy.sh                      # Automated deployment script
├── undeploy.sh                    # Cleanup script
├── test-kafka.sh                  # Verification script
├── helm/                          # Helm charts
│   └── kafka-eks/                 # Main Kafka chart
│       ├── Chart.yaml
│       ├── values.yaml            # Default values
│       ├── values-dev.yaml        # Development config
│       ├── values-staging.yaml    # Staging config
│       ├── values-prod.yaml       # Production config
│       ├── templates/             # Kubernetes templates
│       └── README.md
├── .github/workflows/             # GitHub Actions
│   ├── deploy.yml                 # Main deployment workflow
│   └── pr-check.yml               # PR validation workflow
├── kafka-cluster/                 # Legacy YAML configs
└── monitoring-optional/           # Optional monitoring setup
```

## Installation

### Option 1: Using Deployment Script (Recommended)

```bash
# Deploy to development (1 broker, minimal resources)
./deploy.sh dev

# Deploy to staging (2 brokers, moderate resources)
./deploy.sh staging

# Deploy to production (3+ brokers, full resources)
./deploy.sh prod
```

### Option 2: Using Helm Directly

```bash
# Add Strimzi repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Install for development
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-dev.yaml

# Install for production
helm install kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --create-namespace \
  --values ./helm/kafka-eks/values-prod.yaml
```

### Option 3: Using GitHub Actions

1. **Configure Secrets** in your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`
   - `EKS_CLUSTER_NAME_DEV`
   - `EKS_CLUSTER_NAME_STAGING`
   - `EKS_CLUSTER_NAME_PROD`

2. **Push to trigger deployment**:
   - Push to `develop` branch → Deploys to dev
   - Push to `main`/`master` → Deploys to staging
   - Manual workflow → Deploy to production

3. **Manual deployment** via GitHub Actions:
   - Go to Actions → Deploy Kafka to EKS
   - Click "Run workflow"
   - Select environment and action

## Configuration

### Environment Configurations

| Environment | Brokers | Zookeeper | Storage | Resources |
|-------------|---------|-----------|---------|-----------|
| **Dev** | 1 | 1 | 5Gi | Minimal (1Gi/250m) |
| **Staging** | 2 | 3 | 20Gi | Moderate (2Gi/500m) |
| **Production** | 3 | 5 | 100Gi | Full (4Gi/2000m) |

### Customization

Edit the values files in `helm/kafka-eks/`:

**values-dev.yaml** - Development environment
```yaml
kafka:
  replicas: 1
  storage:
    size: 5Gi
  resources:
    requests:
      memory: 1Gi
```

**values-staging.yaml** - Staging environment
```yaml
kafka:
  replicas: 2
  storage:
    size: 20Gi
```

**values-prod.yaml** - Production environment
```yaml
kafka:
  replicas: 3
  storage:
    size: 100Gi
    class: gp3  # Better IOPS
  listeners:
    tls:
      enabled: true
      authentication:
        type: scram-sha-512
```

See [Helm Chart README](helm/kafka-eks/README.md) for complete configuration options.

## Usage

### Accessing Kafka

**From within the Kubernetes cluster:**

```
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

**From your local machine:**

```bash
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
EOF
```

### Testing Kafka

**Producer:**

```bash
kubectl run kafka-producer -ti \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 \
  --rm=true --restart=Never -n kafka -- \
  bin/kafka-console-producer.sh \
  --bootstrap-server my-kafka-kafka-bootstrap:9092 \
  --topic test-topic
```

**Consumer:**

```bash
kubectl run kafka-consumer -ti \
  --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 \
  --rm=true --restart=Never -n kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server my-kafka-kafka-bootstrap:9092 \
  --topic test-topic \
  --from-beginning
```

## GitHub Actions CI/CD

### Workflows

**deploy.yml** - Main deployment workflow
- Lints Helm charts
- Deploys to dev/staging/prod based on branch
- Manual workflow dispatch for production
- Smoke tests after deployment

**pr-check.yml** - Pull request validation
- Lints Helm charts
- Validates YAML syntax
- Tests template rendering
- Security scanning with Trivy

### Deployment Flow

```
develop branch → Dev Environment
     ↓
main/master → Staging Environment
     ↓
Manual Trigger → Production Environment
```

### Environment Protection

Configure branch protection and environment rules in GitHub:
- `development` - Auto-deploy from `develop` branch
- `staging` - Auto-deploy from `main` branch
- `production` - Requires manual approval

## Upgrading

```bash
# Using script
./deploy.sh prod  # Will prompt to upgrade

# Using Helm
helm upgrade kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-prod.yaml

# Dry run to preview changes
helm upgrade kafka-eks ./helm/kafka-eks \
  --namespace kafka \
  --values ./helm/kafka-eks/values-prod.yaml \
  --dry-run --debug
```

## Monitoring

### Enable Prometheus Monitoring

Edit values file:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
  podMonitor:
    enabled: true
```

### Install Prometheus Stack

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

### View Metrics

```bash
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Access http://localhost:9090
```

## Security

### TLS Encryption

```yaml
kafka:
  listeners:
    tls:
      enabled: true
      port: 9093
```

### Authentication (SCRAM-SHA-512)

```yaml
kafka:
  listeners:
    tls:
      enabled: true
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

```bash
./undeploy.sh
```

This will:
1. Uninstall Helm release
2. Delete Kafka cluster
3. Delete topics
4. Optionally delete PVCs (data)
5. Optionally delete namespace

## Troubleshooting

### Check Deployment Status

```bash
# Helm release status
helm status kafka-eks -n kafka

# Kafka cluster status
kubectl get kafka -n kafka
kubectl describe kafka my-kafka -n kafka

# Pods
kubectl get pods -n kafka
kubectl logs -n kafka my-kafka-kafka-0 -c kafka

# Operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator
```

### Common Issues

**PVCs not binding:**
```bash
kubectl get pvc -n kafka
kubectl get storageclass
# Ensure storage class exists (gp2 or gp3 for AWS)
```

**LoadBalancer not provisioning:**
```bash
# Check service
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka

# Ensure AWS Load Balancer Controller is installed
kubectl get pods -n kube-system | grep aws-load-balancer
```

**Helm lint failures:**
```bash
# Lint chart
helm lint ./helm/kafka-eks

# Test template rendering
helm template kafka-eks ./helm/kafka-eks -f ./helm/kafka-eks/values-dev.yaml
```

## Technology Stack

| Component | Version | License |
|-----------|---------|---------|
| Apache Kafka | 3.6.0 | Apache 2.0 |
| Apache Zookeeper | 3.8.3 | Apache 2.0 |
| Strimzi Operator | 0.39.0 | Apache 2.0 |
| Helm | 3.8+ | Apache 2.0 |

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run lint checks: `helm lint ./helm/kafka-eks`
5. Submit a pull request

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Helm Documentation](https://helm.sh/docs/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## License

This project is open source and available under the Apache 2.0 License.

---

**Get started in 5 minutes:**

```bash
./deploy.sh dev
```

**For production deployment:**

```bash
./deploy.sh prod
```

**Using GitHub Actions:**

Configure secrets → Push to branch → Auto-deploy ✨
