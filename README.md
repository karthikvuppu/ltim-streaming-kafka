# LTIM Streaming Kafka

Self-service Kafka platform on Amazon EKS. Teams request topics through a web portal; an AI-assisted workflow validates, generates, and auto-merges the required Kafka configuration via GitOps.

---

## Architecture

```
Developer → Kafka Portal (Streamlit UI)
                ↓ Cognito JWT auth
            FastAPI (OpenAI YAML generation + OPA validation)
                ↓ GitHub PR
            gitops/sandbox/kafka/
                ↓ ArgoCD sync (webhook triggered)
            Strimzi Operator → KafkaTopic / KafkaUser
```

**Infrastructure** (Terraform → EKS, eu-north-1):
- VPC, EKS 1.32, node groups, IAM roles, OIDC, EBS CSI driver
- Strimzi Kafka Operator + Apache Kafka (KRaft mode, no ZooKeeper)
- AWS Cognito (user pool, hosted UI, JWT auth, team groups)
- OpenAI API (YAML generation + self-review)
- AWS Glue Schema Registry (Avro/JSON/Protobuf via IRSA)
- ExternalDNS → Route53 private zone (`aws.internal`)
- ArgoCD (GitOps controller, internet-facing NLB)
- ECR (container images for portal)

---

## Quick Start — Automated Deployment

The easiest way to spin up the full stack from scratch:

1. Go to **GitHub Actions → Deploy Full Stack → Run workflow**
2. Select environment (`sandbox`)
3. Click **Run workflow**

This provisions and configures everything end-to-end (~30 min total):

| Step | Job | Time |
|---|---|---|
| VPC, EKS, Cognito, ECR, Glue | `terraform` | ~15 min |
| Strimzi + Kafka broker | `deploy-kafka` | ~10 min |
| FastAPI + Streamlit portal | `deploy-portal` | ~3 min |
| ArgoCD apps + GitHub webhook | `configure-gitops` | ~1 min |

At the end the workflow prints all service URLs and credentials.

To **tear down** everything: run the workflow with the **Destroy** checkbox ticked.

**Required GitHub Secrets** (already configured):

| Secret | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM access |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret |
| `OPENAI_API_KEY` | OpenAI YAML generation |
| `DEPLOY_GITHUB_PAT` | Webhook + PR management |

---

## Repository Structure

```
.
├── terraform/
│   ├── environments/sandbox/     # Terraform entrypoint — EKS, IAM, Cognito, ArgoCD, ECR
│   └── modules/                  # vpc, eks, iam, iam-oidc
│
├── helm/
│   ├── kafka-eks/                # Strimzi operator + Kafka cluster + Kafka UI
│   └── kafka-portal/             # FastAPI + Streamlit portal
│
├── portal/
│   ├── app/                      # FastAPI — OpenAI YAML gen, JWT auth, OPA validation, GitHub PR
│   └── ui/                       # Streamlit — Cognito login, topic request form, My Topics view
│
├── gitops/sandbox/kafka/
│   ├── topics/                   # KafkaTopic YAMLs (GitOps managed by ArgoCD)
│   └── users/                    # KafkaUser YAMLs (GitOps managed by ArgoCD)
│
├── .github/workflows/
│   ├── deploy.yml                # Full-stack deploy/destroy (workflow_dispatch)
│   ├── build-push.yml            # Build + push portal images to ECR on portal/** push
│   └── auto-merge-topics.yml     # Validate + auto-merge GitOps topic PRs
│
├── deploy.sh                     # Manual Kafka deploy script (helm/kafka-eks)
├── undeploy.sh                   # Tear down Kafka
└── test-kafka.sh                 # Verify Kafka cluster health
```

---

## Manual Deployment (step-by-step)

If you prefer to deploy manually instead of using the GitHub Actions workflow:

### 1. Terraform — provision infrastructure

```bash
cd terraform/environments/sandbox
terraform init -backend-config=vars/backend.hcl
terraform apply -auto-approve   # ~15 min

# Update kubeconfig
aws eks update-kubeconfig --region eu-north-1 --name ltim-sandbox-eks
```

**What it creates:**

| Resource | Details |
|---|---|
| VPC | `10.0.0.0/16`, 3 AZs, public + private subnets, NAT gateways |
| EKS | `ltim-sandbox-eks`, Kubernetes 1.32, t3.medium × 2 nodes |
| ArgoCD | Helm-deployed, internet-facing NLB |
| Cognito | User Pool `ltim-sandbox-kafka-portal`, 5 team groups, OAuth2 App Client |
| Glue Registry | `ltim-sandbox-kafka-registry` |
| ExternalDNS | Route53 private zone `aws.internal` |
| ECR | `kafka-portal-api`, `kafka-portal-ui` |
| EBS CSI Driver | EKS addon (required for Kafka broker persistent volumes) |

### 2. Deploy Kafka

```bash
./deploy.sh sandbox
```

> **Note (EKS 1.32):** After the Helm install, the Kafka broker pod may stay Pending
> because Strimzi's reconciliation loop doesn't create the PVC on first deploy.
> If the broker pod is stuck after ~3 min, seed the PVC manually:
>
> ```bash
> kubectl apply -f - <<EOF
> apiVersion: v1
> kind: PersistentVolumeClaim
> metadata:
>   name: data-0-my-kafka-combined-0
>   namespace: kafka
>   labels:
>     strimzi.io/cluster: my-kafka
>     strimzi.io/controller-name: my-kafka-combined
>     strimzi.io/kind: Kafka
>     strimzi.io/name: my-kafka-combined-0
>     strimzi.io/pool-name: combined
> spec:
>   accessModes: [ReadWriteOnce]
>   resources:
>     requests:
>       storage: 10Gi
>   storageClassName: gp2
> EOF
> ```

### 3. Deploy the portal

```bash
# Create Kubernetes secret (get Cognito values from terraform output)
kubectl create namespace kafka-portal

kubectl create secret generic kafka-portal-secrets \
  --from-literal=GITHUB_TOKEN=ghp_... \
  --from-literal=OPENAI_API_KEY=sk-... \
  --from-literal=COGNITO_REGION=eu-north-1 \
  --from-literal=COGNITO_USER_POOL_ID=$(terraform -chdir=terraform/environments/sandbox output -raw cognito_user_pool_id) \
  --from-literal=COGNITO_CLIENT_ID=$(terraform -chdir=terraform/environments/sandbox output -raw cognito_client_id) \
  --from-literal=COGNITO_CLIENT_SECRET=$(terraform -chdir=terraform/environments/sandbox output -raw cognito_client_secret) \
  -n kafka-portal

# Deploy
helm upgrade --install kafka-portal ./helm/kafka-portal \
  --namespace kafka-portal \
  --values ./helm/kafka-portal/values-sandbox.yaml \
  --wait --timeout 5m
```

### 4. Register ArgoCD apps

```bash
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kafka-eks
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/karthikvuppu/ltim-streaming-kafka
    targetRevision: main
    path: helm/kafka-eks
    helm:
      valueFiles: [values-sandbox.yaml]
  destination:
    server: https://kubernetes.default.svc
    namespace: kafka
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kafka-portal
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/karthikvuppu/ltim-streaming-kafka
    targetRevision: main
    path: helm/kafka-portal
    helm:
      valueFiles: [values-sandbox.yaml]
  destination:
    server: https://kubernetes.default.svc
    namespace: kafka-portal
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

---

## Service Endpoints

After deployment, retrieve live URLs with:

```bash
# Kafka UI
kubectl get svc kafka-ui-external -n kafka \
  -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}:8080'

# Self-Service Portal
kubectl get svc kafka-portal-ui -n kafka-portal \
  -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}:8501'

# ArgoCD
kubectl get svc argocd-server -n argocd \
  -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}'

# Kafka external bootstrap
kubectl get svc my-kafka-kafka-external-bootstrap -n kafka \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}:9094'
```

---

## How Topic Requests Work

1. Developer logs in via **Cognito** (team-scoped: payments, analytics, engineering, platform, audit)
2. Fills in: LOB, entity, event type, partitions, retention, consumer teams, description
3. **OPA validation** (inline rules):
   - Naming convention: `<lob>.<entity>.<event_type>` (e.g. `payments.order.created`)
   - LOB ownership: topic LOB must match requesting user's LOB
   - Partition quota per LOB (payments: 20, analytics: 30, platform: 20, etc.)
   - Retention cap: 720h (30 days) for sandbox
   - Event type vocabulary: `created`, `updated`, `deleted`, `failed`, `approved`, `rejected`, `submitted`, `processed`
   - Duplicate check: HTTP 400 if topic already exists in the cluster
4. **OpenAI** generates `KafkaTopic` + `KafkaUser` YAML
5. FastAPI opens a **GitHub PR** to `gitops/sandbox/kafka/`
6. `auto-merge-topics.yml` validates (only KafkaTopic/KafkaUser allowed) and **auto-merges**
7. **ArgoCD** detects the merge via webhook and applies within ~30 seconds
8. **Strimzi** creates the topic and user in Kafka

---

## Connecting to Kafka

### Internal (from within the cluster)

```properties
bootstrap.servers=my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafka-producer" password="<from-secret>";
```

### External (NLB — internet-facing)

```properties
bootstrap.servers=<nlb-hostname>:9094
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafka-producer" password="<from-secret>";
```

### Get credentials

```bash
# Producer
kubectl get secret kafka-producer -n kafka -o jsonpath='{.data.password}' | base64 -d

# Consumer
kubectl get secret kafka-consumer -n kafka -o jsonpath='{.data.password}' | base64 -d

# Admin
kubectl get secret kafka-admin -n kafka -o jsonpath='{.data.password}' | base64 -d
```

---

## AWS Glue Schema Registry

Registry: `ltim-sandbox-kafka-registry` (eu-north-1). Pods authenticate via IRSA — no credentials in code.

```properties
# Producer
value.serializer=com.amazonaws.services.schemaregistry.serializers.GlueSchemaRegistryKafkaSerializer
schemaAutoRegistrationEnabled=true
region=eu-north-1
registryName=ltim-sandbox-kafka-registry
dataFormat=AVRO

# Consumer
value.deserializer=com.amazonaws.services.schemaregistry.deserializers.GlueSchemaRegistryKafkaDeserializer
region=eu-north-1
registryName=ltim-sandbox-kafka-registry
```

Pod must use `serviceAccountName: kafka-schema-registry-sa` (namespace: `kafka`).

Maven dependency:
```xml
<dependency>
  <groupId>software.amazon.glue</groupId>
  <artifactId>schema-registry-serde</artifactId>
  <version>1.1.20</version>
</dependency>
```

---

## CI/CD Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `deploy.yml` | Manual (workflow_dispatch) | Full stack deploy or destroy |
| `build-push.yml` | Push to `portal/**` on main | Build + push Docker images to ECR, update image tag in values-sandbox.yaml |
| `auto-merge-topics.yml` | PR touching `gitops/sandbox/kafka/**` | Validate YAML, squash-merge if valid |

---

## ArgoCD

**Access:**
```bash
# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d

# Port-forward (if LB not available)
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

Username: `admin`

---

## Common Operations

```bash
# Cluster health
kubectl get kafka -n kafka
kubectl get pods -n kafka
kubectl get kafkatopic -n kafka
kubectl get kafkauser -n kafka

# Portal
kubectl get pods -n kafka-portal
kubectl logs -n kafka-portal deployment/kafka-portal-api --tail=50

# ArgoCD app status
kubectl get applications -n argocd

# Broker logs
kubectl logs -n kafka my-kafka-combined-0 -c kafka

# Strimzi operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator --tail=50

# Helm releases
helm list -n kafka
helm list -n kafka-portal
helm list -n argocd
```

---

## Troubleshooting

**Kafka broker pod stuck Pending (PVC not found)**

Seed the PVC manually — see step 2 in the manual deployment section above. This is a known Strimzi reconciliation issue on first deploy with KRaft mode on EKS 1.32.

**Portal returning 500 on topic request**

Check the FastAPI logs:
```bash
kubectl logs -n kafka-portal deployment/kafka-portal-api --tail=50
```
Most common cause: invalid OpenAI API key in `kafka-portal-secrets`. Recreate the secret and restart:
```bash
kubectl rollout restart deployment/kafka-portal-api -n kafka-portal
```

**ArgoCD app OutOfSync**

```bash
kubectl annotate application kafka-eks -n argocd argocd.argoproj.io/refresh=hard
```

**GitHub webhook not triggering ArgoCD**

After cluster recreation, the ArgoCD LB hostname changes. Update the webhook:
```bash
ARGOCD_LB=$(kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
# Update via GitHub repo Settings → Webhooks
```
Or re-run the `deploy.yml` workflow which handles this automatically.

**NLB stuck Pending**

```bash
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka
kubectl get pods -n kube-system | grep aws-load-balancer
```

---

## Cleanup

```bash
# Remove portal only
helm uninstall kafka-portal -n kafka-portal

# Remove Kafka (preserves PVCs/data)
helm uninstall kafka-eks -n kafka

# Remove Kafka + all data
helm uninstall kafka-eks -n kafka
kubectl delete pvc --all -n kafka
kubectl delete namespace kafka

# Destroy all AWS infrastructure
cd terraform/environments/sandbox
terraform destroy -auto-approve
```

Or use the **Deploy Full Stack** GitHub Actions workflow with the **Destroy** checkbox.

---

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [AWS Glue Schema Registry](https://docs.aws.amazon.com/glue/latest/dg/schema-registry.html)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
