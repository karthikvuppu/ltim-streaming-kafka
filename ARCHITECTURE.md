# Kafka on EKS - Architecture

This document describes the architecture, components, configuration, and deployment details for the Kafka on EKS solution.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Components](#components)
- [Infrastructure](#infrastructure)
- [Helm Chart Structure](#helm-chart-structure)
- [Environment Configurations](#environment-configurations)
- [Configuration Reference](#configuration-reference)
- [Security](#security)
- [Monitoring](#monitoring)
- [Networking](#networking)
- [Storage](#storage)
- [Scaling](#scaling)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Amazon EKS Cluster                      │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Namespace: kafka                            │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────┐     │  │
│  │  │      Strimzi Cluster Operator                 │     │  │
│  │  │      (Manages Kafka & Zookeeper)              │     │  │
│  │  └────────────────────────────────────────────────┘     │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────┐     │  │
│  │  │         Kafka StatefulSet                     │     │  │
│  │  │  ┌──────┐  ┌──────┐  ┌──────┐                │     │  │
│  │  │  │Broker│  │Broker│  │Broker│  (1-5 pods)     │     │  │
│  │  │  │  0   │  │  1   │  │  2   │                │     │  │
│  │  │  └──┬───┘  └──┬───┘  └──┬───┘                │     │  │
│  │  │     │         │         │                     │     │  │
│  │  │  ┌──▼─────────▼─────────▼───┐                │     │  │
│  │  │  │    PersistentVolumes      │                │     │  │
│  │  │  │    (EBS gp2/gp3)          │                │     │  │
│  │  │  └───────────────────────────┘                │     │  │
│  │  └────────────────────────────────────────────────┘     │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────┐     │  │
│  │  │      Zookeeper StatefulSet                    │     │  │
│  │  │  ┌──────┐  ┌──────┐  ┌──────┐                │     │  │
│  │  │  │  ZK  │  │  ZK  │  │  ZK  │  (1-5 pods)     │     │  │
│  │  │  │  0   │  │  1   │  │  2   │                │     │  │
│  │  │  └──┬───┘  └──┬───┘  └──┬───┘                │     │  │
│  │  │     │         │         │                     │     │  │
│  │  │  ┌──▼─────────▼─────────▼───┐                │     │  │
│  │  │  │    PersistentVolumes      │                │     │  │
│  │  │  └───────────────────────────┘                │     │  │
│  │  └────────────────────────────────────────────────┘     │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────┐     │  │
│  │  │       Entity Operator                         │     │  │
│  │  │  ┌────────────┐  ┌────────────┐              │     │  │
│  │  │  │   Topic    │  │   User     │              │     │  │
│  │  │  │  Operator  │  │  Operator  │              │     │  │
│  │  │  └────────────┘  └────────────┘              │     │  │
│  │  └────────────────────────────────────────────────┘     │  │
│  │                                                          │  │
│  │  Services:                                              │  │
│  │  • my-kafka-kafka-bootstrap (ClusterIP) :9092          │  │
│  │  • my-kafka-kafka-external-bootstrap (NLB) :9094       │  │
│  │  • my-kafka-zookeeper-client (ClusterIP) :2181         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ AWS Network Load Balancer
                              ▼
                    External Kafka Clients
```

---

## Components

### 1. Strimzi Kafka Operator

**Version:** 0.39.0
**Image:** `quay.io/strimzi/operator:0.39.0`

**Purpose:**
- Manages Kafka and Zookeeper clusters declaratively
- Handles rolling updates and configuration changes
- Manages Kafka topics and users as Kubernetes CRDs
- Monitors cluster health and performs auto-healing

**Responsibilities:**
- Cluster Operator: Deploys and manages Kafka/Zookeeper
- Topic Operator: Manages KafkaTopic resources
- User Operator: Manages KafkaUser resources

### 2. Apache Kafka

**Version:** 3.6.0
**Image:** `quay.io/strimzi/kafka:0.39.0-kafka-3.6.0`

**Listeners:**
- **Plain (9092):** Internal cluster communication
- **External (9094):** AWS NLB for external access
- **TLS (9093):** Encrypted communication (production only)

**Features:**
- Distributed streaming platform
- Horizontal scalability (1-5+ brokers)
- Data replication and fault tolerance
- High throughput message processing

### 3. Apache Zookeeper

**Version:** 3.8.3
**Image:** `quay.io/strimzi/kafka:0.39.0-kafka-3.6.0`

**Purpose:**
- Maintains Kafka cluster metadata
- Leader election for partitions
- Configuration management
- Distributed coordination

**Configuration:**
- Requires odd number of nodes (1, 3, 5)
- Quorum-based consensus
- Persistent storage for reliability

### 4. Entity Operator

**Components:**
- **Topic Operator:** Manages Kafka topics
- **User Operator:** Manages Kafka users and ACLs

**Resources:**
- Memory: 256Mi-512Mi per operator
- CPU: 100m-500m per operator

---

## Infrastructure

### Amazon EKS

**Kubernetes Version:** 1.24+
**Cluster Type:** Managed EKS

**Node Requirements:**
- **Sandbox/Dev:** 2-3 nodes (t3.medium or larger)
- **Production:** 5+ nodes (t3.large or larger)

**Add-ons Required:**
- EBS CSI Driver (for persistent volumes)
- AWS Load Balancer Controller (for NLB)
- CoreDNS
- kube-proxy

### Storage Classes

**gp2 (General Purpose SSD):**
- Default for sandbox/dev
- IOPS: 100-16,000
- Throughput: Up to 250 MB/s
- Cost-effective for development

**gp3 (General Purpose SSD - Newer):**
- Used for production
- IOPS: 3,000-16,000 (baseline)
- Throughput: 125-1,000 MB/s
- Better performance and cost

### Networking

**VPC Configuration:**
- Private subnets for Kafka pods
- Public subnets for NLB (if external access needed)
- Security groups for pod-to-pod communication

**Network Load Balancer:**
- Layer 4 load balancing
- Static IP addresses
- High throughput and low latency
- Cross-zone load balancing enabled

---

## Helm Chart Structure

```
helm/kafka-eks/
├── Chart.yaml                    # Chart metadata
│   ├── name: kafka-eks
│   ├── version: 1.0.0
│   ├── appVersion: 3.6.0
│   └── dependencies:
│       └── strimzi-kafka-operator (0.39.0)
│
├── values.yaml                   # Default values
├── values-sandbox.yaml           # Sandbox configuration
├── values-dev.yaml              # Development configuration
├── values-prod.yaml             # Production configuration
│
└── templates/
    ├── _helpers.tpl             # Template helpers
    ├── kafka.yaml               # Kafka cluster CRD
    ├── kafka-topics.yaml        # KafkaTopic CRDs
    ├── kafka-users.yaml         # KafkaUser CRDs
    ├── metrics-config.yaml      # Prometheus metrics config
    ├── service-monitor.yaml     # Prometheus ServiceMonitor
    └── pod-monitor.yaml         # Prometheus PodMonitor
```

### Chart Dependencies

The chart depends on the Strimzi Kafka Operator chart:

```yaml
dependencies:
  - name: strimzi-kafka-operator
    version: "0.39.0"
    repository: "https://strimzi.io/charts/"
    condition: strimzi.enabled
```

**Installation:**
```bash
helm repo add strimzi https://strimzi.io/charts/
helm repo update
helm dependency build ./helm/kafka-eks
```

---

## Environment Configurations

### Sandbox Environment

**File:** `values-sandbox.yaml`

**Purpose:** Testing, POC, experiments

```yaml
kafka:
  replicas: 1
  storage:
    size: 10Gi
    class: gp2
  resources:
    requests:
      memory: 1Gi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 1000m
  jvmOptions:
    xms: 512m
    xmx: 1024m

zookeeper:
  replicas: 1
  storage:
    size: 5Gi
  resources:
    requests:
      memory: 512Mi
      cpu: 250m

topics:
  enabled: true  # Auto-create test topics
```

**Characteristics:**
- ❌ Not highly available
- ✅ Low resource consumption
- ✅ Fast startup
- ✅ Auto-topic creation enabled
- ❌ No TLS/authentication

### Development Environment

**File:** `values-dev.yaml`

**Purpose:** Active development, integration testing

```yaml
kafka:
  replicas: 1
  storage:
    size: 5Gi
    class: gp2
  resources:
    requests:
      memory: 1Gi
      cpu: 250m
  config:
    log.retention.hours: 24  # 1 day retention
    log.segment.bytes: 536870912  # 512MB

zookeeper:
  replicas: 1
  storage:
    size: 5Gi
```

**Characteristics:**
- ❌ Not highly available
- ✅ Minimal cost
- ✅ Short retention period
- ✅ Suitable for ephemeral data
- ❌ No TLS/authentication

### Production Environment

**File:** `values-prod.yaml`

**Purpose:** Live workloads, high availability

```yaml
kafka:
  replicas: 3  # HA configuration
  storage:
    size: 100Gi
    class: gp3  # Better IOPS

  listeners:
    tls:
      enabled: true
      authentication:
        type: scram-sha-512

  resources:
    requests:
      memory: 4Gi
      cpu: 2000m
    limits:
      memory: 8Gi
      cpu: 4000m

  jvmOptions:
    xms: 2048m
    xmx: 4096m

  config:
    offsets.topic.replication.factor: 3
    transaction.state.log.replication.factor: 3
    transaction.state.log.min.isr: 2
    default.replication.factor: 3
    min.insync.replicas: 2
    log.retention.hours: 168  # 7 days

zookeeper:
  replicas: 5  # HA configuration
  storage:
    size: 20Gi
    class: gp3

monitoring:
  serviceMonitor:
    enabled: true
```

**Characteristics:**
- ✅ Highly available (3+ brokers, 5 Zookeepers)
- ✅ TLS encryption
- ✅ SCRAM-SHA-512 authentication
- ✅ Replication factor 3, MinISR 2
- ✅ Prometheus monitoring
- ✅ Production-grade resources

---

## Configuration Reference

### Kafka Configuration

#### Replica Configuration

```yaml
kafka:
  replicas: 3  # Number of Kafka brokers (1, 3, 5, etc.)
```

**Recommendations:**
- Sandbox/Dev: 1 broker
- Production: 3-5 brokers minimum
- High-throughput: 5-10+ brokers

#### Storage Configuration

```yaml
kafka:
  storage:
    type: jbod
    size: 100Gi
    class: gp3
    deleteClaim: false  # Preserve data on deletion
```

**Storage Sizing Guidelines:**
- Calculate: `(messages/day × message_size × retention_days) × replication_factor`
- Add 20-30% buffer for overhead
- Monitor usage and scale proactively

#### Resource Limits

```yaml
kafka:
  resources:
    requests:
      memory: 4Gi
      cpu: 2000m
    limits:
      memory: 8Gi
      cpu: 4000m
```

**Sizing Guidelines:**
- Memory: 2-4GB per broker (dev), 8-16GB (prod)
- CPU: 1-2 cores (dev), 4-8 cores (prod)
- Adjust based on throughput requirements

#### JVM Options

```yaml
kafka:
  jvmOptions:
    xms: 2048m  # Initial heap
    xmx: 4096m  # Maximum heap
```

**Best Practices:**
- Set Xms = Xmx for stable performance
- Heap should be 50% of container memory
- Remaining memory for page cache

#### Broker Configuration

```yaml
kafka:
  config:
    # Replication
    offsets.topic.replication.factor: 3
    transaction.state.log.replication.factor: 3
    default.replication.factor: 3
    min.insync.replicas: 2

    # Retention
    log.retention.hours: 168  # 7 days
    log.segment.bytes: 1073741824  # 1GB

    # Performance
    num.network.threads: 3
    num.io.threads: 8
    compression.type: lz4

    # Topic creation
    auto.create.topics.enable: false  # Prod: false, Dev: true
```

### Zookeeper Configuration

```yaml
zookeeper:
  replicas: 5  # Must be odd number (1, 3, 5)
  storage:
    type: persistent-claim
    size: 20Gi
    class: gp3
  resources:
    requests:
      memory: 2Gi
      cpu: 500m
  jvmOptions:
    xms: 1024m
    xmx: 2048m
```

**Recommendations:**
- Sandbox: 1 node
- Production: 5 nodes for better resilience
- Odd numbers maintain quorum

---

## Security

### TLS Encryption

**Enable TLS listener:**

```yaml
kafka:
  listeners:
    tls:
      enabled: true
      port: 9093
      type: internal
```

**Certificate Management:**
- Strimzi auto-generates cluster and client certificates
- Certificates stored in Kubernetes secrets
- Auto-rotation supported

### Authentication

#### SCRAM-SHA-512

```yaml
kafka:
  listeners:
    tls:
      enabled: true
      authentication:
        type: scram-sha-512
```

**Create User:**
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
          patternType: literal
        operations:
          - Read
          - Write
          - Describe
EOF
```

**Retrieve Credentials:**
```bash
kubectl get secret my-user -n kafka -o jsonpath='{.data.password}' | base64 -d
```

### Authorization (ACLs)

```yaml
spec:
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: orders
        operations: [Read, Write]
      - resource:
          type: group
          name: my-consumer-group
        operations: [Read]
```

---

## Monitoring

### Prometheus Integration

**Enable ServiceMonitor:**

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    interval: 30s
  podMonitor:
    enabled: true
    interval: 30s
```

### Metrics Endpoints

- **Kafka:** `<pod>:9404/metrics`
- **Zookeeper:** `<pod>:9405/metrics`

### Key Metrics to Monitor

**Kafka Broker Metrics:**
- `kafka_server_replicamanager_underreplicatedpartitions`
- `kafka_server_brokertopicmetrics_messagesinpersec`
- `kafka_server_brokertopicmetrics_bytesinpersec`
- `kafka_network_requestmetrics_totaltimems`
- `kafka_controller_controllerstate_value`

**Zookeeper Metrics:**
- `zookeeper_outstandingrequests`
- `zookeeper_inmemorydatatree_nodecount`
- `zookeeper_quorumsize`

**Resource Metrics:**
- CPU usage per pod
- Memory usage per pod
- Disk I/O and utilization
- Network throughput

### Prometheus Query Examples

```promql
# Under-replicated partitions (should be 0)
kafka_server_replicamanager_underreplicatedpartitions

# Message rate per topic
rate(kafka_server_brokertopicmetrics_messagesinpersec[5m])

# Consumer lag
kafka_consumergroup_lag
```

---

## Networking

### Internal Access

**Bootstrap Server:**
```
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

**From Application Pod:**
```yaml
env:
  - name: KAFKA_BOOTSTRAP_SERVERS
    value: "my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092"
```

### External Access

**AWS Network Load Balancer:**

```yaml
kafka:
  listeners:
    external:
      enabled: true
      type: loadbalancer
      port: 9094
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-internal: "true"
        service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
```

**Get External Endpoint:**
```bash
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap
```

### Port Forwarding (Development)

```bash
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
```

Connect to: `localhost:9092`

---

## Storage

### Persistent Volumes

**Kafka Data:**
- One PVC per broker pod
- Mounted at `/var/lib/kafka/data`
- Survives pod restarts
- Reclaim policy: Retain (configurable)

**Zookeeper Data:**
- One PVC per Zookeeper pod
- Mounted at `/var/lib/zookeeper`
- Critical for cluster metadata

### Storage Expansion

**Increase volume size:**

```yaml
kafka:
  storage:
    size: 200Gi  # Increased from 100Gi
```

```bash
helm upgrade kafka-eks ./helm/kafka-eks \
  -n kafka \
  -f values-prod.yaml
```

**Note:** EBS volumes can be expanded online without downtime.

### Backup Strategy

**Kafka Data:**
- Use MirrorMaker 2 for replication
- Snapshot EBS volumes periodically
- Export critical topics to S3

**Zookeeper Data:**
- Regular EBS snapshots
- Test restore procedures

---

## Scaling

### Horizontal Scaling (Add Brokers)

**Update configuration:**
```yaml
kafka:
  replicas: 5  # Scale from 3 to 5
```

**Apply:**
```bash
helm upgrade kafka-eks ./helm/kafka-eks -n kafka -f values-prod.yaml
```

**Strimzi handles:**
- ✅ Rolling deployment
- ✅ Partition reassignment
- ✅ Load rebalancing

### Vertical Scaling (Resources)

**Increase resources:**
```yaml
kafka:
  resources:
    requests:
      memory: 8Gi  # Increased from 4Gi
      cpu: 4000m   # Increased from 2000m
```

**Requires pod restart:**
```bash
helm upgrade kafka-eks ./helm/kafka-eks -n kafka -f values-prod.yaml
kubectl rollout status statefulset/my-kafka-kafka -n kafka
```

### Storage Scaling

**Increase PVC size:**
```yaml
kafka:
  storage:
    size: 200Gi  # Increased from 100Gi
```

EBS volumes expand automatically. No pod restart required.

---

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n kafka

# Describe pod for events
kubectl describe pod my-kafka-kafka-0 -n kafka

# Check logs
kubectl logs my-kafka-kafka-0 -n kafka -c kafka
```

**Common Causes:**
- Insufficient resources (CPU/memory)
- PVC binding issues
- Image pull errors
- Liveness/readiness probe failures

#### PVCs Not Binding

```bash
# Check PVC status
kubectl get pvc -n kafka

# Check storage classes
kubectl get storageclass

# Describe PVC
kubectl describe pvc data-my-kafka-kafka-0 -n kafka
```

**Solutions:**
- Ensure EBS CSI driver is installed
- Verify storage class exists
- Check AWS permissions for EBS operations

#### LoadBalancer Not Provisioning

```bash
# Check service status
kubectl get svc -n kafka my-kafka-kafka-external-bootstrap

# Describe service
kubectl describe svc my-kafka-kafka-external-bootstrap -n kafka
```

**Solutions:**
- Install AWS Load Balancer Controller
- Check VPC subnet tags
- Verify IAM permissions

#### Under-Replicated Partitions

```bash
# Check cluster status
kubectl get kafka my-kafka -n kafka

# Check broker logs
kubectl logs my-kafka-kafka-0 -n kafka -c kafka | grep -i "under"
```

**Causes:**
- Broker down or restarting
- Network issues
- Disk I/O bottleneck
- Insufficient resources

#### Operator Issues

```bash
# Check operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator

# Check CRD status
kubectl describe kafka my-kafka -n kafka
```

### Debug Commands

```bash
# Kafka cluster status
kubectl get kafka -n kafka

# All pods in namespace
kubectl get pods -n kafka

# Kafka broker logs
kubectl logs -n kafka my-kafka-kafka-0 -c kafka --tail=100

# Zookeeper logs
kubectl logs -n kafka my-kafka-zookeeper-0 --tail=100

# Operator logs
kubectl logs -n kafka deployment/strimzi-cluster-operator --tail=100

# Events in namespace
kubectl get events -n kafka --sort-by='.lastTimestamp'

# Describe Kafka cluster
kubectl describe kafka my-kafka -n kafka

# Port-forward for testing
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
```

---

## Performance Tuning

### Producer Configuration

```properties
# Throughput optimization
compression.type=lz4
batch.size=32768
linger.ms=10
buffer.memory=67108864

# Reliability
acks=all
retries=3
max.in.flight.requests.per.connection=5
```

### Consumer Configuration

```properties
# Performance
fetch.min.bytes=1024
fetch.max.wait.ms=500
max.partition.fetch.bytes=1048576

# Reliability
enable.auto.commit=false
isolation.level=read_committed
```

### Broker Tuning

```yaml
kafka:
  config:
    # Network threads
    num.network.threads: 8
    num.io.threads: 16

    # Socket buffer sizes
    socket.send.buffer.bytes: 102400
    socket.receive.buffer.bytes: 102400
    socket.request.max.bytes: 104857600

    # Compression
    compression.type: lz4

    # Log settings
    log.segment.bytes: 1073741824
    log.retention.check.interval.ms: 300000
```

---

## Resources

- **Strimzi Documentation:** https://strimzi.io/docs/
- **Apache Kafka Documentation:** https://kafka.apache.org/documentation/
- **Helm Documentation:** https://helm.sh/docs/
- **AWS EKS Best Practices:** https://aws.github.io/aws-eks-best-practices/
- **Kubernetes Documentation:** https://kubernetes.io/docs/
