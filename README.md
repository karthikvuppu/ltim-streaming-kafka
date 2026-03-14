# LTIM Streaming Kafka

Self-service Kafka platform on Amazon EKS. Teams request topics through a web portal; an AI-assisted workflow validates, generates, and auto-merges the required Kafka configuration via GitOps.

---

## Architecture

```
Developer → Kafka Portal (Streamlit UI)
                ↓ Cognito OAuth2
            FastAPI (Bedrock AI)
                ↓ GitHub PR
            gitops/sandbox/kafka/
                ↓ ArgoCD sync
            Strimzi Operator → KafkaTopic / KafkaUser
```

**Infrastructure** (Terraform → EKS):
- VPC, EKS 1.32, node groups, IAM roles, OIDC
- Strimzi Kafka Operator + Apache Kafka 3.6.0
- AWS Cognito (hosted UI + JWT auth)
- Amazon Bedrock (Claude 3.5 Sonnet via IRSA — no API key)
- AWS Glue Schema Registry (Avro/JSON/Protobuf via IRSA)
- ExternalDNS → Route53 private zone (`aws.internal`)
- ArgoCD (GitOps controller)
- ECR (container images for portal)

---

## Repository Structure

```
.
├── terraform/
│   ├── environments/sandbox/     # Terraform entrypoint — EKS, IAM, Cognito, ArgoCD, Bedrock
│   └── modules/                  # vpc, eks, iam, iam-oidc
│
├── helm/
│   ├── kafka-eks/                # Strimzi operator + Kafka cluster + Kafka UI
│   └── kafka-portal/             # FastAPI + Streamlit portal
│
├── portal/
│   ├── app/                      # FastAPI — Bedrock AI, JWT auth, GitHub PR creation
│   └── ui/                       # Streamlit — Cognito OAuth2 login, topic request form
│
├── gitops/sandbox/kafka/
│   ├── topics/                   # KafkaTopic YAMLs (managed by ArgoCD)
│   └── users/                    # KafkaUser YAMLs (managed by ArgoCD)
│
├── argocd/
│   └── kafka-topics-app.yaml     # ArgoCD Application manifest
│
├── .github/workflows/
│   ├── build-push.yml            # Build + push portal images to ECR on portal/** push
│   └── auto-merge-topics.yml     # Validate + auto-merge GitOps PRs
│
├── deploy.sh                     # Deploy Kafka (helm/kafka-eks) to sandbox
├── undeploy.sh                   # Tear down Kafka
└── test-kafka.sh                 # Verify Kafka cluster health
```

---

## Infrastructure — Terraform

All infrastructure lives in `terraform/environments/sandbox/`.

```bash
cd terraform/environments/sandbox

# First time
terraform init -backend-config=vars/backend.hcl

# Deploy everything (~20-25 min)
terraform apply -auto-approve
```

**What it creates:**
| Resource | Details |
|---|---|
| VPC | `10.0.0.0/16`, 3 AZs, public + private subnets |
| EKS | `ltim-sandbox-eks`, Kubernetes 1.32, t3.medium nodes |
| ArgoCD | Helm-deployed, internet-facing NLB |
| Cognito | User Pool, hosted UI, 5 team groups, OAuth2 App Client |
| Bedrock IRSA | `ltim-sandbox-kafka-portal-bedrock-role` → Claude models |
| Glue Registry | `ltim-sandbox-kafka-registry` |
| ExternalDNS | Route53 private zone `aws.internal` |
| ECR | `kafka-portal-api`, `kafka-portal-ui` |

After apply, update kubeconfig:
```bash
aws eks update-kubeconfig --region eu-north-1 --name ltim-sandbox-eks
```

---

## Kafka — Deploy

```bash
./deploy.sh sandbox
```

Or manually:
```bash
helm upgrade --install kafka-eks ./helm/kafka-eks \
  --namespace kafka --create-namespace \
  -f ./helm/kafka-eks/values.yaml \
  -f ./helm/kafka-eks/values-sandbox.yaml \
  --wait --timeout 15m
```

**Kafka endpoints:**

| Access | Address |
|---|---|
| Internal (cluster) | `my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092` |
| External (NLB) | `kafka-sandbox.aws.internal:9094` |
| Port-forward | `kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092` |
| Kafka UI | `http://kafka-ui-sandbox.aws.internal:8080` |

---

## Kafka Portal — Self-Service Topic Requests

### Deploy the portal

```bash
# Create the Kubernetes secret first
kubectl create secret generic kafka-portal-secrets \
  --from-literal=GITHUB_TOKEN=ghp_... \
  --from-literal=COGNITO_REGION=eu-north-1 \
  --from-literal=COGNITO_USER_POOL_ID=eu-north-1_lYnTusC49 \
  --from-literal=COGNITO_CLIENT_ID=232lq00pndiakq3ldfvnqhf2ed \
  --from-literal=COGNITO_CLIENT_SECRET=<secret> \
  -n kafka-portal

# Deploy
helm upgrade --install kafka-portal ./helm/kafka-portal \
  --namespace kafka-portal --create-namespace \
  -f ./helm/kafka-portal/values.yaml \
  -f ./helm/kafka-portal/values-sandbox.yaml
```

**Portal URL:** `https://kafka-portal-sandbox.aws.internal`

### How topic requests work

1. Developer logs in via **Cognito** (team-scoped groups)
2. Fills in: topic name, partitions, retention, consumer teams, description
3. **FastAPI** validates via inline OPA rules (naming: `<team>.<entity>.<event_type>`, partition quota, retention limit)
4. **Amazon Bedrock** (Claude 3.5 Sonnet, eu-west-1) generates `KafkaTopic` + `KafkaUser` YAML
5. Claude 3 Haiku self-reviews the YAML
6. FastAPI opens a **GitHub PR** to `gitops/sandbox/kafka/`
7. GitHub Actions validates (only KafkaTopic/KafkaUser allowed) and **auto-merges**
8. **ArgoCD** detects the merge and applies the YAML to the cluster
9. **Strimzi** creates the topic and user in Kafka

### Topic naming convention

```
<team>.<entity>.<event_type>
```

Examples: `payments.order.created`, `analytics.session.updated`

Allowed event types: `created`, `updated`, `deleted`, `processed`, `failed`, `requested`, `completed`

---

## ArgoCD

ArgoCD is deployed by Terraform and watches `gitops/sandbox/kafka/` for KafkaTopic/KafkaUser changes.

**Register the GitOps application** (one-time after Terraform apply):
```bash
kubectl apply -f argocd/kafka-topics-app.yaml
```

**Access ArgoCD UI:**
```bash
# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d

# Port-forward
kubectl port-forward -n argocd svc/argocd-server 8080:80
# Open http://localhost:8080
```

---

## CI/CD — GitHub Actions

### Image build (`build-push.yml`)

Triggers on push to `portal/**`. Builds `kafka-portal-api` and `kafka-portal-ui`, tags with git SHA + `latest`, pushes to ECR, commits updated image tag back to `values-sandbox.yaml`.

**Required GitHub secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Auto-merge topics (`auto-merge-topics.yml`)

Validates PRs that only touch `gitops/sandbox/kafka/**`. Checks that all YAMLs are `KafkaTopic` or `KafkaUser` kind, then squash-merges automatically.

---

## Connecting to Kafka

### From inside the cluster

```properties
bootstrap.servers=my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafka-producer" password="<from-secret>";
```

### From outside (NLB)

```properties
bootstrap.servers=kafka-sandbox.aws.internal:9094
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafka-producer" password="<from-secret>";
```

### Get credentials

```bash
kubectl get secret kafka-producer -n kafka -o jsonpath='{.data.password}' | base64 -d
kubectl get secret kafka-consumer -n kafka -o jsonpath='{.data.password}' | base64 -d
kubectl get secret kafka-admin    -n kafka -o jsonpath='{.data.password}' | base64 -d
```

---

## AWS Glue Schema Registry

Registry name: `ltim-sandbox-kafka-registry` (eu-north-1)

Pods authenticate via IRSA — no credentials needed in code.

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

---

## Common Operations

```bash
# Cluster health
kubectl get kafka -n kafka
kubectl get pods -n kafka
kubectl get kafkatopic -n kafka
kubectl get kafkauser -n kafka

# Portal pods
kubectl get pods -n kafka-portal

# Broker logs
kubectl logs -n kafka my-kafka-kafka-0 -c kafka

# Strimzi operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator

# ExternalDNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# ArgoCD app status
kubectl get application -n argocd

# Helm status
helm list -n kafka
helm list -n kafka-portal
helm list -n argocd
```

---

## Cleanup

```bash
# Remove portal
helm uninstall kafka-portal -n kafka-portal

# Remove Kafka (keep data)
helm uninstall kafka-eks -n kafka

# Remove Kafka + all data
helm uninstall kafka-eks -n kafka
kubectl delete pvc --all -n kafka
kubectl delete namespace kafka

# Destroy all infrastructure
cd terraform/environments/sandbox
terraform destroy -auto-approve
```

---

## Troubleshooting

**Pods not starting:**
```bash
kubectl describe pod my-kafka-kafka-0 -n kafka
kubectl logs my-kafka-kafka-0 -n kafka -c kafka
```

**Portal can't call Bedrock:**
```bash
# Verify IRSA annotation
kubectl get sa kafka-portal-api-sa -n kafka-portal -o yaml | grep role-arn
# Enable model access: AWS Console → Bedrock → Model access → eu-west-1
```

**ArgoCD app out of sync:**
```bash
kubectl annotate application kafka-topics-sandbox -n argocd \
  argocd.argoproj.io/refresh=hard
```

**GitHub PR not auto-merging:**
```bash
# Check workflow logs in GitHub Actions
# Verify GITHUB_TOKEN has repo write permissions
```

**NLB stuck in Pending:**
```bash
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka
kubectl get pods -n kube-system | grep aws-load-balancer
```

---

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [AWS Glue Schema Registry](https://docs.aws.amazon.com/glue/latest/dg/schema-registry.html)
- [Amazon Bedrock](https://docs.aws.amazon.com/bedrock/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
