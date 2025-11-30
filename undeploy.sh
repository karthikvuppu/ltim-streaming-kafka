#!/bin/bash

# Cleanup script for Kafka on EKS deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="kafka"
RELEASE_NAME="kafka-eks"

echo "=========================================="
echo "Kafka on EKS - Cleanup"
echo "=========================================="
echo ""

echo -e "${YELLOW}⚠️  WARNING: This will delete all Kafka data and configurations!${NC}"
echo ""
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Step 1: Uninstalling Helm release..."
if helm list -n $NAMESPACE | grep -q "^$RELEASE_NAME"; then
    helm uninstall $RELEASE_NAME -n $NAMESPACE
    echo -e "${GREEN}✅ Helm release uninstalled${NC}"
else
    echo -e "${YELLOW}⚠️  Helm release not found${NC}"
fi

echo ""
echo "Step 2: Deleting Kafka cluster (if any)..."
if kubectl get kafka my-kafka -n $NAMESPACE &> /dev/null; then
    kubectl delete kafka my-kafka -n $NAMESPACE --timeout=300s
    echo -e "${GREEN}✅ Kafka cluster deleted${NC}"
else
    echo -e "${YELLOW}⚠️  Kafka cluster not found${NC}"
fi

echo ""
echo "Step 3: Deleting topics..."
kubectl delete kafkatopic --all -n $NAMESPACE --timeout=60s 2>/dev/null || true
echo -e "${GREEN}✅ Topics deleted${NC}"

echo ""
echo "Step 4: Deleting PVCs (Persistent Volume Claims)..."
echo -e "${YELLOW}⚠️  This will permanently delete all Kafka data!${NC}"
read -p "Delete PVCs and data? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete pvc --all -n $NAMESPACE 2>/dev/null || true
    echo -e "${GREEN}✅ PVCs deleted${NC}"
else
    echo -e "${YELLOW}⚠️  PVCs preserved${NC}"
fi

echo ""
read -p "Delete namespace '$NAMESPACE'? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete namespace $NAMESPACE --timeout=300s
    echo -e "${GREEN}✅ Namespace deleted${NC}"
else
    echo -e "${YELLOW}⚠️  Namespace preserved${NC}"
fi

echo ""
echo -e "${GREEN}✅ Cleanup completed!${NC}"
echo ""
echo "To redeploy, run: ./deploy.sh [dev|staging|prod]"
echo ""
