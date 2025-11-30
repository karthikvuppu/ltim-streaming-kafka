# Optional Monitoring with Prometheus

This directory contains optional monitoring setup using open-source tools (Prometheus + Grafana).

## Features

- Prometheus metrics collection from Kafka and Zookeeper
- Grafana dashboards for visualization
- No cost - completely open-source
- Replaces DataDog (enterprise)

## Quick Start

### Option 1: Prometheus Operator (Recommended)

```bash
# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install kube-prometheus-stack (includes Prometheus, Grafana, Alertmanager)
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123

# Apply Kafka metrics service monitors
kubectl apply -f prometheus-servicemonitor.yaml
kubectl apply -f prometheus-pod-monitor.yaml
```

### Option 2: Standalone Prometheus

```bash
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace
```

## Access Grafana

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at: http://localhost:3000
# Username: admin
# Password: admin123 (or what you set)
```

## Import Kafka Dashboards

1. Go to Grafana → Dashboards → Import
2. Use these dashboard IDs:
   - **7589** - Strimzi Kafka
   - **10465** - Kafka Exporter Overview
   - **11962** - Kafka Cluster Overview

## Metrics Available

Strimzi automatically exposes:
- Kafka broker metrics (JMX)
- Zookeeper metrics
- Topic metrics
- Consumer group lag
- Resource usage (CPU, memory, disk)

## Disable Monitoring

To remove monitoring:

```bash
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```

## Cost

- **Free** - All open-source components
- Only costs: EKS resources (CPU/memory for Prometheus/Grafana pods)

## Alternative: Kafka UI

For a lightweight alternative to Grafana, use Kafka UI:

```bash
helm repo add kafka-ui https://provectus.github.io/kafka-ui-charts
helm install kafka-ui kafka-ui/kafka-ui \
  --set envs.config.KAFKA_CLUSTERS_0_NAME=my-kafka \
  --set envs.config.KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=my-kafka-kafka-bootstrap.kafka:9092 \
  --namespace kafka

# Access
kubectl port-forward -n kafka svc/kafka-ui 8080:80
# Open: http://localhost:8080
```
