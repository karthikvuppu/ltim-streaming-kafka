# Kafka on EKS

Production-ready Apache Kafka deployment on Amazon EKS using **GitHub Actions CI/CD exclusively**.

## 🚀 Automated Deployment via GitHub Actions

**Push to deploy automatically:**
- Push to `sandbox` → Deploy to Sandbox
- Push to `develop` → Deploy to Development
- Push to `main` → Deploy to Production

## Quick Start

### 1. Configure GitHub Secrets

Add these secrets to your repository (**Settings → Secrets → Actions**):

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
EKS_CLUSTER_NAME_SANDBOX
EKS_CLUSTER_NAME_DEV
EKS_CLUSTER_NAME_PROD
```

### 2. Push to Deploy

```bash
# Deploy to sandbox
git checkout sandbox
git push origin sandbox

# Deploy to development
git checkout develop
git push origin develop

# Deploy to production (requires approval)
git checkout main
git push origin main
```

**That's it!** GitHub Actions handles everything automatically.

## Overview

Complete Kafka deployment solution with:
- **GitHub Actions CI/CD** - Fully automated deployments
- **Three Environments** - Sandbox, Development, Production
- **Helm Charts** - Production-ready configurations
- **Zero Manual Work** - Push to deploy
- **100% Open Source** - No licenses required

## Features

- ✅ **GitHub Actions Exclusive** - All deployments automated
- ✅ **Apache Kafka 3.6.0** - Latest stable release
- ✅ **Three Environments** - Sandbox/Dev/Prod isolation
- ✅ **Automated Testing** - Lint, validate, security scan
- ✅ **Branch-based Deployment** - Simple git push to deploy
- ✅ **Production Approval** - Manual gate for prod deployments
- ✅ **Monitoring Ready** - Optional Prometheus integration
- ✅ **Rollback Support** - Easy rollback via Helm

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                 GitHub Repository                     │
│                                                       │
│  Branch: sandbox  ──> Auto-deploy to Sandbox EKS    │
│  Branch: develop  ──> Auto-deploy to Dev EKS        │
│  Branch: main     ──> Auto-deploy to Prod EKS       │
│                       (with approval)                 │
│                                                       │
│  Pull Request     ──> Automatic validation & tests  │
└──────────────────────────────────────────────────────┘
```

## Environments

| Environment | Branch | Auto-Deploy | Brokers | Storage | Use Case |
|-------------|--------|-------------|---------|---------|----------|
| **Sandbox** | `sandbox` | ✅ Yes | 1 | 10Gi | Testing & experiments |
| **Development** | `develop` | ✅ Yes | 1 | 5Gi | Active development |
| **Production** | `main` | ⚠️ Requires approval | 3+ | 100Gi | Live workloads |

## Repository Structure

```
.
├── .github/workflows/          # GitHub Actions (PRIMARY)
│   ├── deploy.yml              # Main deployment workflow
│   └── pr-check.yml            # PR validation
├── helm/kafka-eks/             # Helm chart
│   ├── values-sandbox.yaml     # Sandbox environment
│   ├── values-dev.yaml         # Development environment
│   ├── values-prod.yaml        # Production environment
│   └── templates/              # Kubernetes manifests
├── deploy.sh                   # Manual deployment (testing only)
├── undeploy.sh                 # Manual cleanup
├── test-kafka.sh               # Verification script
├── README.md                   # This file
├── GITHUB_ACTIONS_SETUP.md     # Detailed setup guide
└── LICENSE                     # Apache 2.0
```

## GitHub Actions Setup

**Complete setup guide:** [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)

### Prerequisites

- GitHub repository with this code
- AWS account with EKS clusters
- AWS IAM user for GitHub Actions
- GitHub Secrets configured

### Step 1: Create EKS Clusters

```bash
# Create sandbox cluster
eksctl create cluster --name kafka-sandbox-eks --region us-east-1

# Create dev cluster
eksctl create cluster --name kafka-dev-eks --region us-east-1

# Create prod cluster
eksctl create cluster --name kafka-prod-eks --region us-east-1
```

### Step 2: Configure AWS IAM

Create IAM user `github-actions-kafka` with EKS access permissions.

### Step 3: Add GitHub Secrets

```bash
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set AWS_REGION
gh secret set EKS_CLUSTER_NAME_SANDBOX
gh secret set EKS_CLUSTER_NAME_DEV
gh secret set EKS_CLUSTER_NAME_PROD
```

### Step 4: Create Branches

```bash
git checkout -b sandbox && git push -u origin sandbox
git checkout -b develop && git push -u origin develop
git checkout main && git push -u origin main
```

### Step 5: Deploy!

```bash
# Deploy to sandbox
git checkout sandbox
echo "# Test change" >> README.md
git commit -am "Test deployment"
git push origin sandbox
# ✅ GitHub Actions automatically deploys to sandbox

# Deploy to dev
git checkout develop
git merge sandbox
git push origin develop
# ✅ GitHub Actions automatically deploys to dev

# Deploy to prod
git checkout main
gh pr create --base main --head develop
# After approval and merge:
# ✅ GitHub Actions automatically deploys to prod
```

## Deployment Workflows

### Automatic Deployment

**Triggered by:** Push to `sandbox`, `develop`, or `main` branch

**What it does:**
1. ✅ Lints Helm charts
2. ✅ Deploys to corresponding EKS cluster
3. ✅ Waits for Kafka cluster to be ready
4. ✅ Verifies deployment
5. ✅ Runs smoke tests (prod only)

### Pull Request Validation

**Triggered by:** Pull request to any branch

**What it does:**
1. ✅ Lints Helm charts (all environments)
2. ✅ Validates YAML syntax
3. ✅ Tests template rendering
4. ✅ Security scanning (Trivy)
5. ✅ Uploads test artifacts

### Manual Deployment

**Via GitHub UI:**
1. Go to **Actions** tab
2. Select **Deploy Kafka to EKS**
3. Click **Run workflow**
4. Choose environment and action
5. Click **Run workflow**

**Via GitHub CLI:**
```bash
gh workflow run deploy.yml -f environment=prod -f action=upgrade
```

## Configuration

### Environment-Specific Values

**Sandbox** (`helm/kafka-eks/values-sandbox.yaml`):
```yaml
kafka:
  replicas: 1
  storage:
    size: 10Gi
  # Minimal resources for testing
```

**Development** (`helm/kafka-eks/values-dev.yaml`):
```yaml
kafka:
  replicas: 1
  storage:
    size: 5Gi
  # Cost-effective for development
```

**Production** (`helm/kafka-eks/values-prod.yaml`):
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
  # Full HA setup with security
```

### Customizing Configuration

```bash
# Edit environment-specific values
git checkout develop
vim helm/kafka-eks/values-dev.yaml

# Commit and push
git add helm/kafka-eks/values-dev.yaml
git commit -m "Update dev configuration"
git push origin develop

# GitHub Actions automatically deploys the changes
```

## Monitoring Deployments

### Via GitHub Actions UI

1. Go to **Actions** tab
2. Click on running workflow
3. View real-time deployment logs
4. Check deployment status

### Via GitHub CLI

```bash
# Watch deployment
gh run watch

# List recent deployments
gh run list --workflow=deploy.yml

# View specific deployment
gh run view <run-id> --log
```

### Via kubectl

```bash
# Check Kafka cluster status
kubectl get kafka -n kafka

# Check pods
kubectl get pods -n kafka

# View logs
kubectl logs -n kafka my-kafka-kafka-0 -c kafka
```

## Usage

### Accessing Kafka

**From within cluster:**
```
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

**From local machine:**
```bash
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
```

**Via LoadBalancer:**
```bash
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap
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
    retention.ms: 604800000
EOF
```

### Testing Kafka

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

## Rollback

If a deployment fails or needs to be reverted:

### Via Git

```bash
# Revert to previous commit
git revert HEAD
git push origin main
# GitHub Actions automatically redeploys previous version
```

### Via Helm

```bash
# List releases
helm list -n kafka

# Rollback to previous release
helm rollback kafka-eks -n kafka
```

## Troubleshooting

### Deployment Failed

1. Check GitHub Actions logs: **Actions** tab → Failed workflow
2. Check Kafka cluster: `kubectl describe kafka my-kafka -n kafka`
3. Check pods: `kubectl get pods -n kafka`
4. Check operator: `kubectl logs -n kafka deployment/strimzi-cluster-operator`

### AWS Authentication Error

```
Error: Failed to authenticate to AWS
```

**Solution:**
- Verify GitHub Secrets are set correctly
- Check IAM user has EKS permissions
- Verify IAM user in EKS aws-auth ConfigMap

### Helm Installation Failed

```
Error: Helm installation failed
```

**Solution:**
- Run lint locally: `helm lint helm/kafka-eks`
- Check cluster resources: `kubectl top nodes`
- Verify storage class exists: `kubectl get sc`

## Manual Deployment (Testing Only)

For local testing, use the deployment script:

```bash
# NOT recommended for production
./deploy.sh sandbox
./deploy.sh dev
./deploy.sh prod  # Use GitHub Actions for prod!
```

**⚠️ Production deployments should ALWAYS use GitHub Actions.**

## Security

### Production Security Features

- ✅ TLS encryption enabled
- ✅ SCRAM-SHA-512 authentication
- ✅ Network policies
- ✅ Pod security policies
- ✅ Secrets management via GitHub Secrets
- ✅ AWS IAM integration

### Branch Protection

Configure in **Settings → Branches**:
- `main` - Require PR approval, status checks
- `develop` - Require status checks
- `sandbox` - Optional protections

## Best Practices

1. **Always use GitHub Actions for deployment**
2. **Test in sandbox first**
3. **Merge to develop for integration testing**
4. **Require PR approval for main**
5. **Monitor deployments via Actions tab**
6. **Use semantic commit messages**
7. **Keep environment configs in sync**
8. **Review GitHub Actions logs regularly**

## Documentation

- **[GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)** - Complete CI/CD setup guide
- **[helm/kafka-eks/README.md](helm/kafka-eks/README.md)** - Helm chart documentation
- **[.github/workflows/](. github/workflows/)** - Workflow definitions

## Technology Stack

| Component | Version | License |
|-----------|---------|---------|
| Apache Kafka | 3.6.0 | Apache 2.0 |
| Zookeeper | 3.8.3 | Apache 2.0 |
| Strimzi Operator | 0.39.0 | Apache 2.0 |
| Helm | 3.13+ | Apache 2.0 |
| GitHub Actions | Latest | - |

## Contributing

1. Fork the repository
2. Create feature branch from `develop`
3. Make changes
4. Push and create PR
5. Wait for automated checks to pass
6. Request review
7. Merge after approval

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## License

Apache 2.0 - See [LICENSE](LICENSE) file.

---

## 🎯 Get Started Now

1. **Configure GitHub Secrets** (5 minutes)
2. **Create branches** (2 minutes)
3. **Push to deploy** (1 command)

```bash
git push origin sandbox  # Deploy to sandbox!
```

**GitHub Actions handles the rest automatically!** 🚀

---

**Questions?** See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for detailed setup instructions.
