# Personal Kafka & Zookeeper Deployment

Open-source Apache Kafka and Zookeeper deployment for personal EKS clusters.

## Quick Start

```bash
cd personal-deployment
./deploy.sh
```

## What's This?

This repository provides a simplified, **100% open-source** deployment of Apache Kafka and Zookeeper on Amazon EKS using the Strimzi Kafka Operator.

**Perfect for:**
- Personal projects
- Development environments
- Learning Kafka
- Testing and experimentation

## Features

✅ Apache Kafka 3.6.0
✅ Zookeeper ensemble (3 nodes)
✅ Strimzi Kafka Operator (open-source)
✅ No licenses required
✅ No enterprise subscriptions
✅ **Total cost: $0** (just EKS infrastructure)

## What Was Removed

This repo originally contained enterprise code. All proprietary components have been removed:

- ❌ Confluent Enterprise platform
- ❌ DataDog monitoring
- ❌ OAuth/mTLS/LDAP authentication
- ❌ Commercial licenses

See **[QUICKSTART-PERSONAL.md](QUICKSTART-PERSONAL.md)** for details.

## Prerequisites

- Running EKS cluster
- kubectl configured
- Helm 3.x installed

## Documentation

📖 **[QUICKSTART-PERSONAL.md](QUICKSTART-PERSONAL.md)** - Start here!
📖 **[personal-deployment/README.md](personal-deployment/README.md)** - Full deployment guide
📖 **[personal-deployment/EXAMPLES.md](personal-deployment/EXAMPLES.md)** - Configuration examples
📖 **[personal-deployment/REMOVED_ENTERPRISE_FEATURES.md](personal-deployment/REMOVED_ENTERPRISE_FEATURES.md)** - What was removed

## Repository Structure

```
.
├── README.md                           # This file
├── QUICKSTART-PERSONAL.md              # Quick start guide
└── personal-deployment/                # All deployment files
    ├── README.md                       # Full documentation
    ├── EXAMPLES.md                     # Configuration examples
    ├── REMOVED_ENTERPRISE_FEATURES.md  # Migration guide
    ├── deploy.sh                       # Automated deployment
    ├── undeploy.sh                     # Cleanup script
    ├── test-kafka.sh                   # Verification script
    ├── kafka-cluster/                  # Kafka configurations
    │   ├── kafka-cluster.yaml          # Main cluster config
    │   └── kafka-topic-example.yaml    # Example topics
    └── monitoring-optional/            # Optional Prometheus setup
        ├── README.md
        ├── prometheus-servicemonitor.yaml
        └── prometheus-pod-monitor.yaml
```

## Deploy

### 1. Deploy Kafka Cluster

```bash
cd personal-deployment
./deploy.sh
```

### 2. Verify Deployment

```bash
./test-kafka.sh
```

### 3. Access Kafka

**From within cluster:**
```
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
```

**From your local machine:**
```bash
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
# Connect to: localhost:9092
```

### 4. Create Topics

```bash
kubectl apply -f kafka-cluster/kafka-topic-example.yaml
```

### 5. (Optional) Add Monitoring

```bash
cd monitoring-optional
# Follow README.md to install Prometheus + Grafana
```

## Clean Up

```bash
cd personal-deployment
./undeploy.sh
```

## Security Note

⚠️ **This deployment is for personal/development use:**
- No authentication
- No encryption
- No authorization

For production use, add security features. See `personal-deployment/EXAMPLES.md` for configuration examples with TLS and authentication.

## Technology Stack

| Component | Version | License |
|-----------|---------|---------|
| Apache Kafka | 3.6.0 | Apache 2.0 |
| Zookeeper | 3.8.3 | Apache 2.0 |
| Strimzi Operator | 0.39.0 | Apache 2.0 |

## Learn More

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## License

This deployment uses 100% open-source components under Apache 2.0 license.

---

**Ready to start?**

```bash
cd personal-deployment && ./deploy.sh
```
