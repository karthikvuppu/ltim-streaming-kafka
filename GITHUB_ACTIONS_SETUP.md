# GitHub Actions Setup Guide

Complete guide to set up automated Kafka deployments using GitHub Actions.

## Overview

This repository uses **GitHub Actions exclusively** for deploying Kafka to EKS across three environments:
- **Sandbox** - Testing and experimentation
- **Development** - Active development
- **Production** - Live production workloads

## Prerequisites

- GitHub repository with this code
- AWS account with EKS clusters
- AWS credentials with appropriate permissions
- GitHub repository admin access

## Architecture

```
┌─────────────────────────────────────────────────┐
│           GitHub Repository                      │
│                                                  │
│  Branch: sandbox  ──> Deploy to Sandbox EKS    │
│  Branch: develop  ──> Deploy to Dev EKS        │
│  Branch: main     ──> Deploy to Prod EKS       │
│                                                  │
│  Manual Trigger   ──> Deploy to any environment│
└─────────────────────────────────────────────────┘
```

## Step 1: Create EKS Clusters

You need three EKS clusters:

```bash
# Sandbox cluster
eksctl create cluster \
  --name kafka-sandbox-eks \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2

# Development cluster
eksctl create cluster \
  --name kafka-dev-eks \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 2

# Production cluster
eksctl create cluster \
  --name kafka-prod-eks \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.large \
  --nodes 3
```

## Step 2: Create AWS IAM User for GitHub Actions

Create an IAM user with permissions to access EKS:

### 2.1 Create IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2.2 Create IAM User

```bash
# Create user
aws iam create-user --user-name github-actions-kafka

# Attach policy
aws iam attach-user-policy \
  --user-name github-actions-kafka \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT:policy/GitHubActionsEKSPolicy

# Create access key
aws iam create-access-key --user-name github-actions-kafka
```

**Save the Access Key ID and Secret Access Key!**

### 2.3 Update EKS ConfigMap

Add the IAM user to each EKS cluster's aws-auth ConfigMap:

```bash
# For each cluster
kubectl edit -n kube-system configmap/aws-auth
```

Add this to the `mapUsers` section:

```yaml
mapUsers: |
  - userarn: arn:aws:iam::YOUR_ACCOUNT:user/github-actions-kafka
    username: github-actions-kafka
    groups:
      - system:masters
```

## Step 3: Configure GitHub Secrets

Go to your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

### Required Secrets

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS access key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `EKS_CLUSTER_NAME_SANDBOX` | Sandbox EKS cluster name | `kafka-sandbox-eks` |
| `EKS_CLUSTER_NAME_DEV` | Development EKS cluster name | `kafka-dev-eks` |
| `EKS_CLUSTER_NAME_PROD` | Production EKS cluster name | `kafka-prod-eks` |

### Adding Secrets

```bash
# Using GitHub CLI
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set AWS_REGION
gh secret set EKS_CLUSTER_NAME_SANDBOX
gh secret set EKS_CLUSTER_NAME_DEV
gh secret set EKS_CLUSTER_NAME_PROD
```

## Step 4: Create GitHub Branches

Create the required branches:

```bash
# Create sandbox branch
git checkout -b sandbox
git push -u origin sandbox

# Create develop branch
git checkout -b develop
git push -u origin develop

# Ensure main branch exists
git checkout main
git push -u origin main
```

## Step 5: Configure Branch Protection (Recommended)

### For `main` (Production)

1. Go to **Settings → Branches → Add rule**
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require a pull request before merging
   - ✅ Require approvals (at least 1)
   - ✅ Require status checks to pass before merging
   - ✅ Require conversation resolution before merging

### For `develop`

1. Branch name pattern: `develop`
2. Enable:
   - ✅ Require status checks to pass before merging

### For `sandbox`

1. Branch name pattern: `sandbox`
2. Enable:
   - ✅ Require status checks to pass before merging

## Step 6: Configure GitHub Environments

Set up environment-specific settings and approvals.

### 6.1 Sandbox Environment

1. Go to **Settings → Environments → New environment**
2. Name: `sandbox`
3. No deployment protection rules needed

### 6.2 Development Environment

1. Name: `development`
2. Optional: Add environment secrets if different from repository secrets

### 6.3 Production Environment

1. Name: `production`
2. **Required reviewers:** Add team members who must approve prod deployments
3. **Deployment branches:** Only `main` and `master`
4. Optional: Add environment-specific secrets

## Deployment Flow

### Automatic Deployments

```
┌─────────────┐
│ Code Change │
└──────┬──────┘
       │
       ├─ Push to 'sandbox'  ──> GitHub Actions ──> Sandbox EKS
       │
       ├─ Push to 'develop'  ──> GitHub Actions ──> Dev EKS
       │
       └─ Push to 'main'     ──> GitHub Actions ──> Dev EKS (first)
                                                 └──> Prod EKS (after dev success)
```

### Manual Deployments

1. Go to **Actions** tab
2. Select **Deploy Kafka to EKS**
3. Click **Run workflow**
4. Select:
   - Branch (usually main)
   - Environment (sandbox/dev/prod)
   - Action (install/upgrade/uninstall)
5. Click **Run workflow**

## Usage Examples

### Deploy to Sandbox

```bash
# Make changes
git checkout sandbox
vim helm/kafka-eks/values-sandbox.yaml

# Commit and push
git add .
git commit -m "Update sandbox configuration"
git push origin sandbox

# GitHub Actions automatically deploys to sandbox
```

### Deploy to Development

```bash
# Create feature branch from develop
git checkout develop
git pull
git checkout -b feature/new-config

# Make changes
vim helm/kafka-eks/values-dev.yaml

# Commit and create PR
git add .
git commit -m "Update dev configuration"
git push -u origin feature/new-config

# Create PR to develop branch
gh pr create --base develop --title "Update dev config"

# After merge, GitHub Actions deploys to dev
```

### Deploy to Production

```bash
# Create PR from develop to main
git checkout develop
git pull
gh pr create --base main --title "Release v1.0.0"

# After PR approval and merge:
# 1. GitHub Actions deploys to dev (verification)
# 2. If successful, deploys to prod (with manual approval)
```

### Manual Deployment

Via GitHub UI:
1. Actions → Deploy Kafka to EKS → Run workflow
2. Select environment and action
3. Click Run workflow

Via GitHub CLI:
```bash
# Deploy to production
gh workflow run deploy.yml \
  -f environment=prod \
  -f action=upgrade

# Check status
gh run list --workflow=deploy.yml
gh run watch
```

## Workflow Files

### `.github/workflows/deploy.yml`

Main deployment workflow:
- Lints Helm charts
- Deploys to environments based on branch
- Runs verification tests
- Sends notifications

### `.github/workflows/pr-check.yml`

Pull request validation:
- Lints Helm charts
- Validates YAML syntax
- Tests template rendering
- Security scanning

## Monitoring Deployments

### Via GitHub UI

1. Go to **Actions** tab
2. Click on running workflow
3. View real-time logs

### Via GitHub CLI

```bash
# List recent runs
gh run list --workflow=deploy.yml

# Watch a specific run
gh run watch RUN_ID

# View logs
gh run view RUN_ID --log
```

### Via kubectl

```bash
# Check deployment status
kubectl get kafka -n kafka
kubectl get pods -n kafka

# View logs
kubectl logs -n kafka my-kafka-kafka-0 -c kafka
```

## Troubleshooting

### AWS Authentication Failed

```
Error: Failed to authenticate to AWS
```

**Solution:**
- Verify AWS credentials in GitHub Secrets
- Check IAM user has EKS access permissions
- Verify IAM user added to aws-auth ConfigMap

### EKS Cluster Not Found

```
Error: Cluster not found: kafka-dev-eks
```

**Solution:**
- Verify cluster name in GitHub Secrets matches actual cluster name
- Verify AWS region is correct
- Run: `aws eks list-clusters --region us-east-1`

### Helm Installation Failed

```
Error: Helm installation failed
```

**Solution:**
- Check Helm chart syntax: `helm lint helm/kafka-eks`
- Verify values file exists
- Check cluster has sufficient resources

### Workflow Not Triggering

**Solution:**
- Verify branch name matches workflow trigger
- Check if paths filter is blocking trigger
- Ensure you pushed to correct branch

## Best Practices

### 1. Branch Strategy

```
sandbox   → Quick testing, experimental features
   ↓
develop   → Active development, integration testing
   ↓
main      → Production-ready code only
```

### 2. Commit Message Convention

```
feat: Add new Kafka configuration
fix: Correct replication factor
docs: Update deployment guide
chore: Update Helm chart version
```

### 3. PR Workflow

- Always create PRs for changes to `develop` and `main`
- Require at least 1 approval for `develop`
- Require at least 2 approvals for `main`
- Run all checks before merging

### 4. Deployment Verification

After each deployment:
```bash
# Check cluster status
kubectl get kafka -n kafka

# Verify pods are running
kubectl get pods -n kafka

# Test connectivity
kubectl run kafka-test -n kafka --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 --rm -it -- bin/kafka-broker-api-versions.sh --bootstrap-server my-kafka-kafka-bootstrap:9092
```

### 5. Rollback Strategy

If deployment fails:
```bash
# Via GitHub Actions
gh workflow run deploy.yml -f environment=prod -f action=uninstall

# Then redeploy previous version
git checkout <previous-commit>
git push origin main --force
```

Or use Helm:
```bash
# List releases
helm list -n kafka

# Rollback
helm rollback kafka-eks -n kafka
```

## Security Considerations

1. **Secrets Management**
   - Use GitHub Secrets for sensitive data
   - Rotate AWS credentials regularly
   - Use environment-specific secrets when needed

2. **Access Control**
   - Limit who can push to main branch
   - Require approvals for production deployments
   - Use CODEOWNERS file

3. **Audit Trail**
   - All deployments logged in GitHub Actions
   - Review workflow runs regularly
   - Monitor AWS CloudTrail for EKS access

## Advanced Configuration

### Custom Workflow Triggers

Add to `.github/workflows/deploy.yml`:

```yaml
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly deployment every Sunday at 2 AM
  workflow_dispatch:     # Manual trigger
  repository_dispatch:   # API trigger
    types: [deploy-kafka]
```

### Slack Notifications

Add to workflow:

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Multiple Regions

Add secrets for each region:
- `AWS_REGION_US_EAST`
- `AWS_REGION_EU_WEST`
- `EKS_CLUSTER_NAME_PROD_US`
- `EKS_CLUSTER_NAME_PROD_EU`

## Support

For issues:
1. Check workflow logs in Actions tab
2. Review this setup guide
3. Check AWS EKS cluster status
4. Open GitHub Issue with logs

---

**You're all set!** 🚀

Push to any branch and watch GitHub Actions deploy automatically!
