# LTIM Streaming Kafka

Apache Kafka deployment on Amazon EKS using the Strimzi Kafka Operator and Helm. Supports Sandbox, Dev, and Production environments with ACL-based authorization, SCRAM-SHA-512 authentication, ExternalDNS, and AWS Glue Schema Registry integration.

## Features

- Apache Kafka 3.6.0 + ZooKeeper (Strimzi Operator 0.39.0)
- SCRAM-SHA-512 authentication on all listeners
- ACL-based authorization (Kafka SimpleAclAuthorizer)
- AWS Glue Schema Registry — Avro, JSON Schema, Protobuf (IRSA, no credentials in code)
- ExternalDNS — automatic Route53 DNS record management
- Internet-facing NLB for external Kafka and Kafka UI access
- Kafka UI (provectuslabs/kafka-ui) web dashboard
- Pre-configured users: `kafka-producer`, `kafka-consumer`, `kafka-admin`

---

## Repository Structure

```
.
├── deploy.sh                            # One-command deployment script
├── external-dns-values.yaml             # ExternalDNS Helm configuration
└── helm/kafka-eks/
    ├── Chart.yaml                       # Chart + Strimzi v0.39.0 dependency
    ├── values.yaml                      # Global defaults (all environments)
    ├── values-sandbox.yaml              # Sandbox overrides (active)
    ├── values-dev.yaml                  # Dev overrides
    ├── values-prod.yaml                 # Production overrides
    └── templates/
        ├── kafka.yaml                   # Kafka + ZooKeeper CRDs (Strimzi)
        ├── kafka-ui.yaml                # Kafka UI deployment + services
        ├── topics.yaml                  # KafkaTopic resources
        ├── users.yaml                   # KafkaUser resources (SCRAM + ACLs)
        ├── glue-schema-registry.yaml    # ServiceAccount for Glue IRSA
        ├── storageclass.yaml            # EBS gp3 encrypted storage class
        ├── networkpolicy.yaml           # Network policies
        └── servicemonitor.yaml          # Prometheus ServiceMonitor
```

---

## Prerequisites

- EKS cluster provisioned via `eks-kafka` Terraform repo
- `kubectl` configured: `aws eks update-kubeconfig --name ltim-sandbox-eks --region eu-north-1`
- Helm 3.x installed
- AWS CLI configured
- Glue IRSA role ARN from Terraform output (for sandbox/prod)

---

## Deploy

```bash
# Sandbox
./deploy.sh sandbox

# Dev
./deploy.sh dev

# Production
./deploy.sh prod
```

The script automatically:
1. Creates the `kafka` namespace
2. Adds Strimzi + ExternalDNS Helm repositories
3. Deploys ExternalDNS (from `../eks-kafka/external-dns-values.yaml`)
4. Deploys Kafka cluster via Helm
5. Waits for cluster readiness
6. Prints endpoints + schema registry config

### Before sandbox deploy — set the Glue IRSA role ARN

After `terraform apply` in the `eks-kafka` repo:

```bash
cd ../eks-kafka/environments/sandbox
terraform output kafka_schema_registry_role_arn
```

Paste the ARN into [helm/kafka-eks/values-sandbox.yaml](helm/kafka-eks/values-sandbox.yaml):

```yaml
glueSchemaRegistry:
  serviceAccount:
    roleArn: "arn:aws:iam::292481751409:role/ltim-sandbox-kafka-schema-registry-role"
```

---

## Environment Comparison

| Feature | Sandbox | Dev | Production |
|---|---|---|---|
| Kafka Brokers | 1 | 1 | 3 |
| ZooKeeper Nodes | 1 | 1 | 5 |
| Storage | 10Gi gp2 | 5Gi gp2 | 100Gi gp3 encrypted |
| Memory (broker) | 2Gi | 2Gi | 4Gi |
| TLS | No | No | Yes |
| Authentication | SCRAM-SHA-512 | No | SCRAM-SHA-512 |
| ACL Authorization | Yes | No | Yes |
| Replication Factor | 1 | 1 | 3 |
| Kafka UI | Yes (NLB) | Yes | Yes |
| Glue Schema Registry | Yes | No | Yes |
| Network Policies | No | No | Yes |
| Encrypted Storage | No | No | Yes |
| Log Retention | 2 days | 1 day | 7 days |

---

## Connecting to Kafka

### From inside the cluster (pod-to-pod)

```properties
bootstrap.servers=my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafka-producer" password="<from-secret>";
```

### From outside the cluster (internet-facing NLB)

```properties
bootstrap.servers=kafka-sandbox.aws.internal:9094
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafka-producer" password="<from-secret>";
```

### Local development (port-forward)

```bash
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
# Connect to localhost:9092 with SCRAM credentials
```

### Get user credentials

Strimzi generates passwords automatically and stores them as Kubernetes Secrets:

```bash
kubectl get secret kafka-producer -n kafka -o jsonpath='{.data.password}' | base64 -d
kubectl get secret kafka-consumer -n kafka -o jsonpath='{.data.password}' | base64 -d
kubectl get secret kafka-admin    -n kafka -o jsonpath='{.data.password}' | base64 -d
```

---

## Pre-configured Users and ACLs

| User | Topic Permissions | Group Permissions |
|---|---|---|
| `kafka-producer` | Write, Describe, Create on `*` | — |
| `kafka-consumer` | Read, Describe on `*` | Read, Describe on `*` |
| `kafka-admin` | All on `*` | All on `*` + Cluster All |

### Add a custom user with scoped ACLs

Add to `users.users` in your values file:

```yaml
users:
  enabled: true
  users:
    - name: my-app-user
      authentication:
        type: scram-sha-512
      authorization:
        type: simple
        acls:
          - resource:
              type: topic
              name: my-topic
              patternType: literal
            operations:
              - Read
              - Write
              - Describe
          - resource:
              type: group
              name: my-consumer-group
              patternType: literal
            operations:
              - Read
```

---

## AWS Glue Schema Registry

Fully managed schema registry — no extra server to deploy or maintain. Application pods use the AWS Glue SerDe library and authenticate via IRSA (no AWS credentials in code or environment variables).

### Maven Dependency

```xml
<dependency>
    <groupId>software.amazon.glue</groupId>
    <artifactId>schema-registry-serde</artifactId>
    <version>1.1.20</version>
</dependency>
```

### Producer config (append to Kafka producer properties)

```properties
value.serializer=com.amazonaws.services.schemaregistry.serializers.GlueSchemaRegistryKafkaSerializer
schemaAutoRegistrationEnabled=true
region=eu-north-1
registryName=ltim-sandbox-kafka-registry
dataFormat=AVRO
```

### Consumer config (append to Kafka consumer properties)

```properties
value.deserializer=com.amazonaws.services.schemaregistry.deserializers.GlueSchemaRegistryKafkaDeserializer
region=eu-north-1
registryName=ltim-sandbox-kafka-registry
```

### Required: pod must use the IRSA service account

```yaml
spec:
  serviceAccountName: kafka-schema-registry-sa   # namespace: kafka
```

---

## Kafka UI

| Access | URL |
|---|---|
| Internal (VPC DNS) | `http://kafka-ui-sandbox.aws.internal:8080` |
| Local port-forward | `kubectl port-forward -n kafka svc/kafka-ui 8080:8080` → `http://localhost:8080` |

---

## Managing Topics

### Via Helm values (recommended)

```yaml
topics:
  enabled: true
  topics:
    - name: my-topic
      partitions: 3
      replicas: 1
      config:
        retention.ms: 604800000
        cleanup.policy: delete
```

### Via kubectl

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
  replicas: 1
  config:
    retention.ms: 604800000
EOF
```

> `auto.create.topics.enable` is `false` in sandbox. All topics must be created explicitly (required when ACLs are enabled).

---

## Common Operations

```bash
# Cluster health
kubectl get kafka -n kafka
kubectl get pods -n kafka
kubectl get kafkatopic -n kafka
kubectl get kafkauser -n kafka

# Broker logs
kubectl logs -n kafka my-kafka-kafka-0 -c kafka

# ZooKeeper logs
kubectl logs -n kafka my-kafka-zookeeper-0

# Strimzi operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator

# ExternalDNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# Helm status
helm list -n kafka
helm status kafka-eks -n kafka

# Upgrade after config change
helm upgrade kafka-eks ./helm/kafka-eks -n kafka -f ./helm/kafka-eks/values-sandbox.yaml
```

---

## Cleanup

### Remove Kafka only (keep data)

```bash
helm uninstall kafka-eks -n kafka
```

### Remove Kafka and all data

```bash
helm uninstall kafka-eks -n kafka
kubectl delete pvc --all -n kafka   # Deletes EBS volumes
kubectl delete namespace kafka
```

### Remove ExternalDNS

```bash
helm uninstall external-dns -n external-dns
kubectl delete namespace external-dns
```

---

## Troubleshooting

**Pods not starting:**
```bash
kubectl describe pod my-kafka-kafka-0 -n kafka
kubectl logs my-kafka-kafka-0 -n kafka -c kafka
```

**PVCs not binding:**
```bash
kubectl get pvc -n kafka
kubectl get storageclass
# Ensure EBS CSI driver is installed and gp2 storage class exists
```

**NLB stuck in Pending:**
```bash
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka
kubectl get pods -n kube-system | grep aws-load-balancer
```

**DNS not resolving:**
```bash
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns
# Verify annotation exists on service
kubectl get svc -n kafka -o yaml | grep external-dns
```

**Authentication failure (SCRAM):**
```bash
# Re-fetch the generated password
kubectl get secret kafka-producer -n kafka -o jsonpath='{.data.password}' | base64 -d
```

**Glue Schema Registry access denied:**
```bash
# Verify IRSA annotation on the service account
kubectl get sa kafka-schema-registry-sa -n kafka -o yaml | grep role-arn
# Verify pod is using the right service account
kubectl get pod <pod-name> -n kafka -o yaml | grep serviceAccountName
```

---

## Related Repository

**`eks-kafka`** — Terraform infrastructure (EKS, VPC, IAM, Route53, Glue) that this Helm chart runs on.

---

## Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [AWS Glue Schema Registry](https://docs.aws.amazon.com/glue/latest/dg/schema-registry.html)
- [AWS Glue Schema Registry SerDe (GitHub)](https://github.com/awslabs/aws-glue-schema-registry)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
