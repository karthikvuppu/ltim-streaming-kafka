#!/bin/bash

# Personal Kafka & Zookeeper Deployment Script for EKS
# This script deploys a simplified, open-source Kafka cluster using Strimzi

set -e

echo "=========================================="
echo "Kafka & Zookeeper Deployment for EKS"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ helm not found. Please install Helm 3.x.${NC}"
    exit 1
fi

# Check kubectl connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Please configure kubectl.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Configuration
NAMESPACE="kafka"
STRIMZI_VERSION="0.39.0"

echo "Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Strimzi Version: $STRIMZI_VERSION"
echo ""

read -p "Continue with deployment? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Step 1: Creating namespace..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠️  Namespace $NAMESPACE already exists${NC}"
else
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✅ Namespace created${NC}"
fi

echo ""
echo "Step 2: Adding Strimzi Helm repository..."
helm repo add strimzi https://strimzi.io/charts/ &> /dev/null || true
helm repo update &> /dev/null
echo -e "${GREEN}✅ Helm repository updated${NC}"

echo ""
echo "Step 3: Installing Strimzi Kafka Operator..."
if helm list -n $NAMESPACE | grep -q strimzi-kafka-operator; then
    echo -e "${YELLOW}⚠️  Strimzi operator already installed${NC}"
    read -p "Upgrade existing installation? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm upgrade strimzi-kafka-operator strimzi/strimzi-kafka-operator \
            --namespace $NAMESPACE \
            --version $STRIMZI_VERSION
        echo -e "${GREEN}✅ Operator upgraded${NC}"
    fi
else
    helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
        --namespace $NAMESPACE \
        --version $STRIMZI_VERSION \
        --wait
    echo -e "${GREEN}✅ Operator installed${NC}"
fi

echo ""
echo "Step 4: Waiting for operator to be ready..."
kubectl wait --for=condition=Ready pod -l name=strimzi-cluster-operator -n $NAMESPACE --timeout=300s
echo -e "${GREEN}✅ Operator is ready${NC}"

echo ""
echo "Step 5: Deploying Kafka cluster with Zookeeper..."
kubectl apply -f kafka-cluster/kafka-cluster.yaml
echo -e "${GREEN}✅ Kafka cluster deployment initiated${NC}"

echo ""
echo "Step 6: Waiting for Kafka cluster to be ready (this may take 5-10 minutes)..."
echo "  - Deploying Zookeeper ensemble (3 nodes)..."
echo "  - Deploying Kafka brokers (3 nodes)..."
echo ""

# Wait for Zookeeper
echo "Waiting for Zookeeper..."
kubectl wait pod -l strimzi.io/name=my-kafka-zookeeper -n $NAMESPACE --for=condition=Ready --timeout=600s

# Wait for Kafka
echo "Waiting for Kafka..."
kubectl wait pod -l strimzi.io/name=my-kafka-kafka -n $NAMESPACE --for=condition=Ready --timeout=600s

# Wait for Kafka cluster to be ready
kubectl wait kafka/my-kafka --for=condition=Ready --timeout=600s -n $NAMESPACE

echo -e "${GREEN}✅ Kafka cluster is ready!${NC}"

echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""

# Get cluster info
echo "Kafka Cluster Status:"
kubectl get kafka -n $NAMESPACE

echo ""
echo "Pods:"
kubectl get pods -n $NAMESPACE

echo ""
echo "Services:"
kubectl get svc -n $NAMESPACE | grep -E "NAME|kafka-bootstrap"

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Access Kafka internally:"
echo "   Bootstrap servers: my-kafka-kafka-bootstrap.$NAMESPACE.svc.cluster.local:9092"
echo ""
echo "2. Access Kafka from your local machine:"
echo "   kubectl port-forward -n $NAMESPACE svc/my-kafka-kafka-bootstrap 9092:9092"
echo ""
echo "3. Get external LoadBalancer address:"
echo "   kubectl get svc -n $NAMESPACE my-kafka-kafka-external-bootstrap"
echo ""
echo "4. Create example topics:"
echo "   kubectl apply -f kafka-cluster/kafka-topic-example.yaml"
echo ""
echo "5. View Kafka logs:"
echo "   kubectl logs -n $NAMESPACE my-kafka-kafka-0 -c kafka"
echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
