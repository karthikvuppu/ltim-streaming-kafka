#!/bin/bash

# Kafka on EKS Deployment Script
# Deploys Apache Kafka using Helm chart and Strimzi operator
#
# NOTE: This script is for local testing only.
# For production deployments, use GitHub Actions workflows.

set -e

echo "=========================================="
echo "Kafka on EKS - Helm Deployment"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
NAMESPACE="kafka"
RELEASE_NAME="kafka-eks"
ENVIRONMENT="${1:-dev}"  # Default to dev if not specified
HELM_CHART="./helm/kafka-eks"

echo -e "${YELLOW}⚠️  NOTE: This script is for local/manual deployment.${NC}"
echo -e "${YELLOW}⚠️  For production, use GitHub Actions workflows.${NC}"
echo ""

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

# Display configuration
echo -e "${BLUE}Configuration:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  Namespace: $NAMESPACE"
echo "  Release Name: $RELEASE_NAME"
echo "  Helm Chart: $HELM_CHART"
echo ""

# Select values file based on environment
case $ENVIRONMENT in
  sandbox)
    VALUES_FILE="$HELM_CHART/values-sandbox.yaml"
    echo -e "${YELLOW}📋 Using sandbox configuration${NC}"
    ;;
  dev|development)
    VALUES_FILE="$HELM_CHART/values-dev.yaml"
    echo -e "${YELLOW}📋 Using development configuration${NC}"
    ;;
  prod|production)
    VALUES_FILE="$HELM_CHART/values-prod.yaml"
    echo -e "${RED}⚠️  WARNING: Deploying to PRODUCTION${NC}"
    echo -e "${YELLOW}📋 Using production configuration${NC}"
    ;;
  *)
    VALUES_FILE="$HELM_CHART/values.yaml"
    echo -e "${YELLOW}📋 Using default configuration${NC}"
    ;;
esac

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
echo "Step 3: Deploying Kafka using Helm..."

# Check if release already exists
if helm list -n $NAMESPACE | grep -q "^$RELEASE_NAME"; then
    echo -e "${YELLOW}⚠️  Release $RELEASE_NAME already exists${NC}"
    read -p "Upgrade existing installation? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm upgrade $RELEASE_NAME $HELM_CHART \
            --namespace $NAMESPACE \
            --values $VALUES_FILE \
            --wait \
            --timeout 15m
        echo -e "${GREEN}✅ Helm release upgraded${NC}"
    else
        echo "Skipping Helm installation."
    fi
else
    helm install $RELEASE_NAME $HELM_CHART \
        --namespace $NAMESPACE \
        --values $VALUES_FILE \
        --wait \
        --timeout 15m
    echo -e "${GREEN}✅ Helm release installed${NC}"
fi

echo ""
echo "Step 4: Waiting for Kafka cluster to be ready..."
echo "  This may take 5-10 minutes..."
echo ""

# Wait for Kafka cluster to be ready
if kubectl wait kafka/my-kafka --for=condition=Ready --timeout=600s -n $NAMESPACE 2>/dev/null; then
    echo -e "${GREEN}✅ Kafka cluster is ready!${NC}"
else
    echo -e "${YELLOW}⚠️  Kafka cluster still starting up. Check status with: kubectl get kafka -n $NAMESPACE${NC}"
fi

echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""

# Get cluster info
echo -e "${BLUE}Kafka Cluster Status:${NC}"
kubectl get kafka -n $NAMESPACE

echo ""
echo -e "${BLUE}Pods:${NC}"
kubectl get pods -n $NAMESPACE

echo ""
echo -e "${BLUE}Services:${NC}"
kubectl get svc -n $NAMESPACE | grep -E "NAME|kafka-bootstrap"

echo ""
echo -e "${BLUE}Helm Release:${NC}"
helm list -n $NAMESPACE

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Access Kafka internally:"
echo "   ${BLUE}my-kafka-kafka-bootstrap.$NAMESPACE.svc.cluster.local:9092${NC}"
echo ""
echo "2. Access Kafka from your local machine:"
echo "   ${BLUE}kubectl port-forward -n $NAMESPACE svc/my-kafka-kafka-bootstrap 9092:9092${NC}"
echo ""
echo "3. Get external LoadBalancer address:"
echo "   ${BLUE}kubectl get svc -n $NAMESPACE my-kafka-kafka-external-bootstrap${NC}"
echo ""
echo "4. View Kafka logs:"
echo "   ${BLUE}kubectl logs -n $NAMESPACE my-kafka-kafka-0 -c kafka${NC}"
echo ""
echo "5. Check Helm release:"
echo "   ${BLUE}helm status $RELEASE_NAME -n $NAMESPACE${NC}"
echo ""
echo "6. Upgrade configuration:"
echo "   ${BLUE}helm upgrade $RELEASE_NAME $HELM_CHART -n $NAMESPACE -f $VALUES_FILE${NC}"
echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}💡 For production deployments, use GitHub Actions:${NC}"
echo "   - Push to 'sandbox' branch → Deploy to sandbox"
echo "   - Push to 'develop' branch → Deploy to dev"
echo "   - Push to 'main/master' → Deploy to prod (after dev)"
echo ""
echo "Usage: ./deploy.sh [sandbox|dev|prod]"
echo ""
