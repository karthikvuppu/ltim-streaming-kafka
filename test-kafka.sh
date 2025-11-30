#!/bin/bash

# Test script for Kafka deployment

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="kafka"

echo "=========================================="
echo "Kafka Cluster Test"
echo "=========================================="
echo ""

echo "Test 1: Checking cluster status..."
if kubectl get kafka my-kafka -n $NAMESPACE &> /dev/null; then
    STATUS=$(kubectl get kafka my-kafka -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$STATUS" == "True" ]; then
        echo -e "${GREEN}✅ Kafka cluster is Ready${NC}"
    else
        echo -e "${RED}❌ Kafka cluster is not Ready${NC}"
        kubectl get kafka my-kafka -n $NAMESPACE
        exit 1
    fi
else
    echo -e "${RED}❌ Kafka cluster not found${NC}"
    exit 1
fi

echo ""
echo "Test 2: Checking Zookeeper pods..."
ZK_READY=$(kubectl get pods -n $NAMESPACE -l strimzi.io/name=my-kafka-zookeeper -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
ZK_EXPECTED=3
if [ "$ZK_READY" -eq "$ZK_EXPECTED" ]; then
    echo -e "${GREEN}✅ All $ZK_EXPECTED Zookeeper pods are ready${NC}"
else
    echo -e "${RED}❌ Only $ZK_READY/$ZK_EXPECTED Zookeeper pods are ready${NC}"
fi

echo ""
echo "Test 3: Checking Kafka broker pods..."
KAFKA_READY=$(kubectl get pods -n $NAMESPACE -l strimzi.io/name=my-kafka-kafka -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
KAFKA_EXPECTED=3
if [ "$KAFKA_READY" -eq "$KAFKA_EXPECTED" ]; then
    echo -e "${GREEN}✅ All $KAFKA_EXPECTED Kafka broker pods are ready${NC}"
else
    echo -e "${RED}❌ Only $KAFKA_READY/$KAFKA_EXPECTED Kafka broker pods are ready${NC}"
fi

echo ""
echo "Test 4: Checking services..."
if kubectl get svc my-kafka-kafka-bootstrap -n $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✅ Bootstrap service exists${NC}"
    echo "   Internal: my-kafka-kafka-bootstrap.$NAMESPACE.svc.cluster.local:9092"
else
    echo -e "${RED}❌ Bootstrap service not found${NC}"
fi

if kubectl get svc my-kafka-kafka-external-bootstrap -n $NAMESPACE &> /dev/null; then
    LB_ADDRESS=$(kubectl get svc my-kafka-kafka-external-bootstrap -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -n "$LB_ADDRESS" ]; then
        echo -e "${GREEN}✅ External LoadBalancer provisioned${NC}"
        echo "   External: $LB_ADDRESS:9094"
    else
        echo -e "${YELLOW}⚠️  External LoadBalancer provisioning (may take a few minutes)${NC}"
    fi
fi

echo ""
echo "Test 5: Checking operator..."
if kubectl get pods -n $NAMESPACE -l name=strimzi-cluster-operator &> /dev/null; then
    OP_STATUS=$(kubectl get pods -n $NAMESPACE -l name=strimzi-cluster-operator -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
    if [ "$OP_STATUS" == "True" ]; then
        echo -e "${GREEN}✅ Strimzi operator is running${NC}"
    else
        echo -e "${RED}❌ Strimzi operator is not ready${NC}"
    fi
else
    echo -e "${RED}❌ Strimzi operator not found${NC}"
fi

echo ""
echo "=========================================="
echo "Resource Usage"
echo "=========================================="
echo ""
kubectl top pods -n $NAMESPACE 2>/dev/null || echo -e "${YELLOW}⚠️  Metrics server not available${NC}"

echo ""
echo "=========================================="
echo "Quick Start Commands"
echo "=========================================="
echo ""
echo "Create a test topic:"
echo "  kubectl apply -f kafka-cluster/kafka-topic-example.yaml"
echo ""
echo "List topics:"
echo "  kubectl get kafkatopic -n $NAMESPACE"
echo ""
echo "Port-forward to access locally:"
echo "  kubectl port-forward -n $NAMESPACE svc/my-kafka-kafka-bootstrap 9092:9092"
echo ""
echo "Test produce/consume (requires kafkacat or kcat):"
echo "  # In one terminal:"
echo "  kubectl run kafka-producer -ti --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server my-kafka-kafka-bootstrap:9092 --topic test-topic"
echo ""
echo "  # In another terminal:"
echo "  kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.39.0-kafka-3.6.0 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server my-kafka-kafka-bootstrap:9092 --topic test-topic --from-beginning"
echo ""
