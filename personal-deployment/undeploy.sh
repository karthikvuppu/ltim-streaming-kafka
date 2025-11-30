#!/bin/bash

# Cleanup script for Kafka & Zookeeper deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="kafka"

echo "=========================================="
echo "Kafka & Zookeeper Cleanup"
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
echo "Step 1: Deleting Kafka cluster..."
if kubectl get kafka my-kafka -n $NAMESPACE &> /dev/null; then
    kubectl delete kafka my-kafka -n $NAMESPACE --timeout=300s
    echo -e "${GREEN}✅ Kafka cluster deleted${NC}"
else
    echo -e "${YELLOW}⚠️  Kafka cluster not found${NC}"
fi

echo ""
echo "Step 2: Deleting topics..."
kubectl delete kafkatopic --all -n $NAMESPACE --timeout=60s || true
echo -e "${GREEN}✅ Topics deleted${NC}"

echo ""
echo "Step 3: Uninstalling Strimzi operator..."
if helm list -n $NAMESPACE | grep -q strimzi-kafka-operator; then
    helm uninstall strimzi-kafka-operator -n $NAMESPACE
    echo -e "${GREEN}✅ Operator uninstalled${NC}"
else
    echo -e "${YELLOW}⚠️  Operator not found${NC}"
fi

echo ""
echo "Step 4: Deleting PVCs (Persistent Volume Claims)..."
kubectl delete pvc --all -n $NAMESPACE || true
echo -e "${GREEN}✅ PVCs deleted${NC}"

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
