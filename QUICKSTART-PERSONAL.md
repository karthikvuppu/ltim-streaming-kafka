# Quick Start: Personal Kafka Deployment on EKS

This guide helps you deploy Apache Kafka and Zookeeper on your personal EKS cluster **without any enterprise licenses or proprietary components**.

## ⚠️ Important Notice

This repository originally contained **Confluent Enterprise** configurations for Scania's production environment. That code requires:
- Confluent Enterprise license (~$10k-50k/year)
- DataDog subscription
- OAuth/mTLS/LDAP authentication
- AWS-specific integrations

**For personal use, we've created a simplified, 100% open-source deployment.**

## 🚀 Get Started in 5 Minutes

### Prerequisites
- Running EKS cluster
- kubectl configured
- Helm 3.x installed

### Deploy Kafka

```bash
cd personal-deployment
./deploy.sh
```

That's it! The script will:
1. Install Strimzi Kafka Operator (open-source)
2. Deploy 3 Zookeeper nodes
3. Deploy 3 Kafka brokers
4. Configure metrics for monitoring

### Verify Deployment

```bash
./test-kafka.sh
```

### Access Kafka

```bash
# From within the cluster:
my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092

# From your local machine:
kubectl port-forward -n kafka svc/my-kafka-kafka-bootstrap 9092:9092
# Then connect to: localhost:9092
```

## 📚 Documentation

All documentation is in the `personal-deployment/` directory:

- **[README.md](personal-deployment/README.md)** - Complete deployment guide
- **[REMOVED_ENTERPRISE_FEATURES.md](personal-deployment/REMOVED_ENTERPRISE_FEATURES.md)** - What was removed and why
- **[monitoring-optional/README.md](personal-deployment/monitoring-optional/README.md)** - Add Prometheus/Grafana monitoring

## 🗂️ What's What

```
ltim-streaming-kafka/
├── personal-deployment/          ✅ USE THIS - Open-source deployment
│   ├── README.md                 📖 Full documentation
│   ├── deploy.sh                 🚀 Deployment script
│   ├── undeploy.sh              🗑️  Cleanup script
│   ├── test-kafka.sh            ✅ Verification script
│   ├── kafka-cluster/           ⚙️  Kafka configurations
│   └── monitoring-optional/     📊 Optional Prometheus setup
│
├── charts/                       ❌ IGNORE - Confluent Enterprise
├── operator/                     ❌ IGNORE - Enterprise operator
├── confluent-services/          ❌ IGNORE - Enterprise configs
├── tooling/                     ❌ IGNORE - DataDog, etc.
└── .gitlab-ci.yml              ❌ IGNORE - Scania CI/CD
```

## 🎯 What You Get

| Component | Version | License |
|-----------|---------|---------|
| Apache Kafka | 3.6.0 | Apache 2.0 |
| Zookeeper | 3.8.3 | Apache 2.0 |
| Strimzi Operator | 0.39.0 | Apache 2.0 |
| Prometheus (optional) | Latest | Apache 2.0 |

**Total cost: $0** (just EKS infrastructure)

## 🔧 Common Tasks

### Create a Topic

```bash
kubectl apply -f personal-deployment/kafka-cluster/kafka-topic-example.yaml
```

### Scale Kafka Brokers

Edit `personal-deployment/kafka-cluster/kafka-cluster.yaml`:
```yaml
spec:
  kafka:
    replicas: 5  # Change from 3 to 5
```

Then apply:
```bash
kubectl apply -f personal-deployment/kafka-cluster/kafka-cluster.yaml
```

### Add Monitoring

```bash
cd personal-deployment/monitoring-optional
# Follow README.md instructions
```

### Cleanup

```bash
cd personal-deployment
./undeploy.sh
```

## 🔒 Security Note

**This deployment is for personal/development use:**
- ❌ No authentication
- ❌ No encryption
- ❌ No authorization

For production, add:
- TLS encryption
- SCRAM-SHA-512 authentication
- Kafka ACLs
- Network policies

See [Strimzi Security Docs](https://strimzi.io/docs/operators/latest/security.html)

## 🆘 Need Help?

1. Check the logs:
   ```bash
   kubectl logs -n kafka my-kafka-kafka-0 -c kafka
   ```

2. Check cluster status:
   ```bash
   kubectl get kafka -n kafka
   kubectl describe kafka my-kafka -n kafka
   ```

3. Check operator logs:
   ```bash
   kubectl logs -n kafka deployment/strimzi-cluster-operator
   ```

## 📖 Learn More

- [Strimzi Documentation](https://strimzi.io/docs/)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 🎉 What's Removed

✅ Confluent Enterprise (replaced with Apache Kafka)
✅ DataDog monitoring (replaced with optional Prometheus)
✅ OAuth authentication (none - can add later)
✅ mTLS authentication (none - can add later)
✅ LDAP integration (none - can add later)
✅ All proprietary licenses (100% open-source)

See **[REMOVED_ENTERPRISE_FEATURES.md](personal-deployment/REMOVED_ENTERPRISE_FEATURES.md)** for complete details.

---

**Ready to deploy?**

```bash
cd personal-deployment
./deploy.sh
```
