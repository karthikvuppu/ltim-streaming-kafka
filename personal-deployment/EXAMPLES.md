# Configuration Examples

This document provides various configuration examples for different use cases.

## Table of Contents

1. [Minimal Development Setup](#minimal-development-setup)
2. [Production-Like Setup](#production-like-setup)
3. [High Throughput Setup](#high-throughput-setup)
4. [Low Resource Setup](#low-resource-setup)
5. [Adding TLS Security](#adding-tls-security)
6. [Adding Authentication](#adding-authentication)

---

## Minimal Development Setup

Perfect for local development or testing. Uses minimal resources.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: dev-kafka
  namespace: kafka
spec:
  kafka:
    version: 3.6.0
    replicas: 1  # Single broker
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
    storage:
      type: ephemeral  # No persistence - data lost on restart
    resources:
      requests:
        memory: 512Mi
        cpu: 250m
      limits:
        memory: 1Gi
        cpu: 500m
  zookeeper:
    replicas: 1  # Single Zookeeper
    storage:
      type: ephemeral
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 250m
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

**Pros:** Minimal resources, fast startup
**Cons:** No data persistence, no high availability

---

## Production-Like Setup

Recommended for personal projects that need reliability.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: prod-kafka
  namespace: kafka
spec:
  kafka:
    version: 3.6.0
    replicas: 3
    listeners:
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: scram-sha-512
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
      # Better retention
      log.retention.hours: 720  # 30 days
      log.retention.bytes: 1073741824  # 1GB per partition
      # Compression
      compression.type: lz4
      # Security
      ssl.cipher.suites: "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
      ssl.enabled.protocols: "TLSv1.2,TLSv1.3"
    storage:
      type: jbod
      volumes:
        - id: 0
          type: persistent-claim
          size: 100Gi
          deleteClaim: false
    resources:
      requests:
        memory: 4Gi
        cpu: 1000m
      limits:
        memory: 8Gi
        cpu: 2000m
    jvmOptions:
      -Xms: 2048m
      -Xmx: 4096m
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 10Gi
      deleteClaim: false
    resources:
      requests:
        memory: 2Gi
        cpu: 500m
      limits:
        memory: 4Gi
        cpu: 1000m
```

**Pros:** High availability, data persistence, secure
**Cons:** Higher resource usage

---

## High Throughput Setup

Optimized for high message throughput.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: high-throughput-kafka
  namespace: kafka
spec:
  kafka:
    version: 3.6.0
    replicas: 5
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      # Replication
      offsets.topic.replication.factor: 3
      default.replication.factor: 3
      min.insync.replicas: 2
      # Performance tuning
      num.network.threads: 8
      num.io.threads: 16
      num.replica.fetchers: 4
      # Buffer sizes
      socket.send.buffer.bytes: 1048576  # 1MB
      socket.receive.buffer.bytes: 1048576  # 1MB
      socket.request.max.bytes: 104857600  # 100MB
      # Compression
      compression.type: lz4
      # Log settings
      log.segment.bytes: 2147483647  # 2GB
      log.retention.hours: 168  # 7 days
      # Batch settings
      batch.size: 32768
      linger.ms: 10
      # Memory
      replica.fetch.max.bytes: 10485760  # 10MB
    storage:
      type: jbod
      volumes:
        - id: 0
          type: persistent-claim
          size: 500Gi
          class: gp3  # AWS EBS gp3 for better IOPS
          deleteClaim: false
    resources:
      requests:
        memory: 8Gi
        cpu: 2000m
      limits:
        memory: 16Gi
        cpu: 4000m
    jvmOptions:
      -Xms: 4096m
      -Xmx: 8192m
      -XX:+UseG1GC: ""
      -XX:MaxGCPauseMillis: "20"
      -XX:InitiatingHeapOccupancyPercent: "35"
  zookeeper:
    replicas: 5
    storage:
      type: persistent-claim
      size: 20Gi
      deleteClaim: false
    resources:
      requests:
        memory: 2Gi
        cpu: 500m
      limits:
        memory: 4Gi
        cpu: 1000m
```

**Pros:** High throughput, optimized performance
**Cons:** High resource usage, higher costs

---

## Low Resource Setup

For EKS clusters with limited resources.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: low-resource-kafka
  namespace: kafka
spec:
  kafka:
    version: 3.6.0
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      default.replication.factor: 1
      min.insync.replicas: 1
      # Reduce resource usage
      num.network.threads: 2
      num.io.threads: 4
      log.retention.hours: 24  # 1 day
      log.segment.bytes: 536870912  # 512MB
    storage:
      type: persistent-claim
      size: 5Gi
      deleteClaim: false
    resources:
      requests:
        memory: 512Mi
        cpu: 200m
      limits:
        memory: 1Gi
        cpu: 500m
    jvmOptions:
      -Xms: 256m
      -Xmx: 512m
  zookeeper:
    replicas: 1
    storage:
      type: persistent-claim
      size: 2Gi
      deleteClaim: false
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 250m
  entityOperator:
    topicOperator:
      resources:
        requests:
          memory: 128Mi
          cpu: 50m
        limits:
          memory: 256Mi
          cpu: 200m
    userOperator:
      resources:
        requests:
          memory: 128Mi
          cpu: 50m
        limits:
          memory: 256Mi
          cpu: 200m
```

**Pros:** Minimal resource usage, low cost
**Cons:** No high availability, limited throughput

---

## Adding TLS Security

Enable TLS encryption for secure communication.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: secure-kafka
  namespace: kafka
spec:
  kafka:
    version: 3.6.0
    replicas: 3
    listeners:
      - name: tls
        port: 9093
        type: internal
        tls: true  # Enable TLS
        configuration:
          # Use custom certificate (optional)
          brokerCertChainAndKey:
            secretName: my-kafka-tls-cert
            certificate: tls.crt
            key: tls.key
    config:
      offsets.topic.replication.factor: 3
      default.replication.factor: 3
      min.insync.replicas: 2
    storage:
      type: persistent-claim
      size: 10Gi
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 5Gi
```

To generate self-signed certificates:

```bash
# Create a secret with TLS certificate
kubectl create secret generic my-kafka-tls-cert \
  --from-file=tls.crt=path/to/certificate.crt \
  --from-file=tls.key=path/to/private.key \
  -n kafka
```

Or let Strimzi generate them automatically (recommended for personal use):

```yaml
listeners:
  - name: tls
    port: 9093
    type: internal
    tls: true  # Strimzi will auto-generate certs
```

---

## Adding Authentication

Enable SCRAM-SHA-512 authentication.

### 1. Update Kafka Config

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: auth-kafka
  namespace: kafka
spec:
  kafka:
    version: 3.6.0
    replicas: 3
    listeners:
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: scram-sha-512  # Enable authentication
    config:
      offsets.topic.replication.factor: 3
      default.replication.factor: 3
      min.insync.replicas: 2
    storage:
      type: persistent-claim
      size: 10Gi
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 5Gi
```

### 2. Create Users

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-producer
  namespace: kafka
  labels:
    strimzi.io/cluster: auth-kafka
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      # Producer permissions
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations:
          - Write
          - Create
          - Describe

---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-consumer
  namespace: kafka
  labels:
    strimzi.io/cluster: auth-kafka
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      # Consumer permissions
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations:
          - Read
          - Describe
      - resource:
          type: group
          name: my-consumer-group
          patternType: literal
        operations:
          - Read
```

### 3. Get Credentials

```bash
# Get password for my-producer
kubectl get secret my-producer -n kafka -o jsonpath='{.data.password}' | base64 -d

# Get password for my-consumer
kubectl get secret my-consumer -n kafka -o jsonpath='{.data.password}' | base64 -d
```

### 4. Connect with Authentication

```bash
# Java client example
bootstrap.servers=auth-kafka-kafka-bootstrap:9093
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="my-producer" \
  password="<password-from-secret>";
ssl.truststore.location=/tmp/kafka.truststore.jks
ssl.truststore.password=changeit
```

---

## Topic Configuration Examples

### High Retention Topic

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: long-retention-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: my-kafka
spec:
  partitions: 12
  replicas: 3
  config:
    retention.ms: 2592000000  # 30 days
    retention.bytes: 10737418240  # 10GB per partition
    segment.ms: 3600000  # 1 hour
    cleanup.policy: delete
    compression.type: lz4
```

### Compacted Topic (for state)

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: state-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: my-kafka
spec:
  partitions: 6
  replicas: 3
  config:
    cleanup.policy: compact
    segment.ms: 3600000
    min.cleanable.dirty.ratio: 0.1
    delete.retention.ms: 86400000  # 1 day
```

### High Throughput Topic

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: high-throughput-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: my-kafka
spec:
  partitions: 20
  replicas: 3
  config:
    compression.type: lz4
    min.insync.replicas: 2
    retention.ms: 604800000  # 7 days
    segment.bytes: 2147483647  # 2GB
```

---

## Apply Configurations

```bash
# Save any example above to a file
kubectl apply -f my-kafka-config.yaml

# Verify
kubectl get kafka -n kafka
kubectl describe kafka <kafka-name> -n kafka
```

---

## Switching Configurations

To change from one configuration to another:

```bash
# Edit the existing Kafka resource
kubectl edit kafka my-kafka -n kafka

# Or apply a new configuration file
kubectl apply -f new-config.yaml

# Strimzi will perform a rolling update
kubectl get pods -n kafka -w
```

**Note:** Some changes require pod restarts. Strimzi handles rolling updates automatically.
