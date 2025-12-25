#!/bin/bash

# Modular Kafka on EKS Deployment Script
# Uses modular security configuration with environment-specific feature flags

set -e

echo "=========================================="
echo "Kafka on EKS - Modular Deployment"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0;' # No Color

# Default configuration
NAMESPACE="kafka"
RELEASE_NAME="kafka-eks"
ENVIRONMENT="${1:-dev}"  # Default to dev if not specified
HELM_CHART="./helm/kafka-eks"

# Modular values files
COMMON_VALUES="$HELM_CHART/values-common.yaml"
SECURITY_VALUES="$HELM_CHART/values-security.yaml"

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

# Select environment file based on environment
case $ENVIRONMENT in
  sandbox)
    ENV_VALUES="$HELM_CHART/environments/sandbox.yaml"
    SECURITY_ENABLED=false
    echo -e "${CYAN}📦 Environment: SANDBOX${NC}"
    echo -e "${YELLOW}🔓 Security: DISABLED (Development only)${NC}"
    ;;
  dev|development)
    ENV_VALUES="$HELM_CHART/environments/dev.yaml"
    SECURITY_ENABLED=true
    echo -e "${CYAN}📦 Environment: DEVELOPMENT${NC}"
    echo -e "${GREEN}🔒 Security: PARTIAL (Auth + Authz enabled)${NC}"
    ;;
  prod|production)
    ENV_VALUES="$HELM_CHART/environments/production.yaml"
    SECURITY_ENABLED=true
    echo -e "${RED}📦 Environment: PRODUCTION${NC}"
    echo -e "${GREEN}🔒 Security: FULL (All features enabled)${NC}"
    echo -e "${RED}⚠️  WARNING: Deploying to PRODUCTION${NC}"
    ;;
  *)
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Usage: ./deploy-modular.sh [sandbox|dev|prod]${NC}"
    exit 1
    ;;
esac

# Verify values files exist
echo ""
echo -e "${BLUE}📋 Configuration Files:${NC}"
echo "  ✓ Common:      $COMMON_VALUES"
echo "  ✓ Security:    $SECURITY_VALUES"
echo "  ✓ Environment: $ENV_VALUES"

for file in "$COMMON_VALUES" "$SECURITY_VALUES" "$ENV_VALUES"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ File not found: $file${NC}"
        exit 1
    fi
done

echo -e "${GREEN}  ✅ All configuration files found${NC}"

# Display security features
echo ""
echo -e "${BLUE}🔐 Security Features (Modular):${NC}"
if [ "$SECURITY_ENABLED" = true ]; then
    echo -e "${GREEN}  ✓ Authentication (SCRAM-SHA-512)${NC}"
    echo -e "${GREEN}  ✓ Authorization (ACL-based)${NC}"
    echo -e "${GREEN}  ✓ TLS Encryption (in-transit)${NC}"
    if [ "$ENVIRONMENT" = "prod" ] || [ "$ENVIRONMENT" = "production" ]; then
        echo -e "${GREEN}  ✓ Encryption at Rest (AWS KMS)${NC}"
        echo -e "${GREEN}  ✓ Network Policies (namespace isolation)${NC}"
        echo -e "${GREEN}  ✓ Pod Security Standards (non-root, no privesc)${NC}"
        echo -e "${GREEN}  ✓ Audit Logging (authorization events)${NC}"
        echo -e "${GREEN}  ✓ Inter-broker TLS${NC}"
    else
        echo -e "${YELLOW}  ⊗ Encryption at Rest (disabled for cost)${NC}"
        echo -e "${YELLOW}  ⊗ Network Policies (disabled in dev)${NC}"
        echo -e "${GREEN}  ✓ Pod Security Standards${NC}"
        echo -e "${YELLOW}  ⊗ Audit Logging (disabled in dev)${NC}"
        echo -e "${YELLOW}  ⊗ Inter-broker TLS (disabled in dev)${NC}"
    fi
else
    echo -e "${RED}  ✗ All security features DISABLED (sandbox only)${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Configuration:${NC}"
echo "  Namespace:     $NAMESPACE"
echo "  Release Name:  $RELEASE_NAME"
echo "  Environment:   $ENVIRONMENT"
echo "  Security:      $([ "$SECURITY_ENABLED" = true ] && echo 'ENABLED' || echo 'DISABLED')"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
read -p "Continue with deployment? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Creating namespace..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${YELLOW}⚠️  Namespace $NAMESPACE already exists${NC}"
else
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✅ Namespace created${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Adding Strimzi Helm repository..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
helm repo add strimzi https://strimzi.io/charts/ &> /dev/null || true
helm repo update &> /dev/null
echo -e "${GREEN}✅ Helm repository updated${NC}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Deploying Kafka using Modular Config..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Merging values files:${NC}"
echo "  1. Common configuration (base)"
echo "  2. Security module (if enabled)"
echo "  3. Environment overrides"
echo ""

# Build Helm values arguments
HELM_VALUES_ARGS="-f $COMMON_VALUES -f $SECURITY_VALUES -f $ENV_VALUES"

# Set environment label
HELM_SET_ARGS="--set environment=$ENVIRONMENT"

# Check if release already exists
if helm list -n $NAMESPACE | grep -q "^$RELEASE_NAME"; then
    echo -e "${YELLOW}⚠️  Release $RELEASE_NAME already exists${NC}"
    read -p "Upgrade existing installation? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm upgrade $RELEASE_NAME $HELM_CHART \
            --namespace $NAMESPACE \
            $HELM_VALUES_ARGS \
            $HELM_SET_ARGS \
            --wait \
            --timeout 15m
        echo -e "${GREEN}✅ Helm release upgraded${NC}"
    else
        echo "Skipping Helm installation."
        exit 0
    fi
else
    helm install $RELEASE_NAME $HELM_CHART \
        --namespace $NAMESPACE \
        $HELM_VALUES_ARGS \
        $HELM_SET_ARGS \
        --wait \
        --timeout 15m
    echo -e "${GREEN}✅ Helm release installed${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Waiting for Kafka cluster to be ready..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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

# Show network policies if enabled
if [ "$SECURITY_ENABLED" = true ] && [ "$ENVIRONMENT" = "prod" ] || [ "$ENVIRONMENT" = "production" ]; then
    echo ""
    echo -e "${BLUE}Network Policies:${NC}"
    kubectl get networkpolicies -n $NAMESPACE 2>/dev/null || echo "  None found"

    echo ""
    echo -e "${BLUE}Storage Classes:${NC}"
    kubectl get storageclass | grep -E "NAME|kafka" || echo "  Using default"
fi

echo ""
echo -e "${BLUE}Helm Release:${NC}"
helm list -n $NAMESPACE

echo ""
echo "=========================================="
echo "Security Information"
echo "=========================================="

if [ "$SECURITY_ENABLED" = true ]; then
    echo ""
    echo -e "${GREEN}🔐 Security is ENABLED${NC}"
    echo ""
    echo "📝 Retrieve user credentials:"
    echo -e "   ${CYAN}kubectl get secret app-producer -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d${NC}"
    echo -e "   ${CYAN}kubectl get secret app-consumer -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d${NC}"
    echo ""
    echo "📝 Get cluster CA certificate:"
    echo -e "   ${CYAN}kubectl get secret my-kafka-cluster-ca-cert -n $NAMESPACE -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt${NC}"
    echo ""
    echo "📝 Connection example (TLS + SCRAM):"
    echo "   bootstrap.servers=my-kafka-kafka-bootstrap.$NAMESPACE.svc.cluster.local:9093"
    echo "   security.protocol=SASL_SSL"
    echo "   sasl.mechanism=SCRAM-SHA-512"
    echo "   sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \\"
    echo "     username=\"app-producer\" \\"
    echo "     password=\"<password-from-secret>\";"
else
    echo ""
    echo -e "${RED}⚠️  Security is DISABLED (sandbox environment)${NC}"
    echo -e "${YELLOW}   Do NOT use this configuration in production!${NC}"
    echo ""
    echo "📝 Connection (Plaintext - No Auth):"
    echo "   bootstrap.servers=my-kafka-kafka-bootstrap.$NAMESPACE.svc.cluster.local:9092"
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Check deployment:"
echo -e "   ${CYAN}kubectl get kafka -n $NAMESPACE${NC}"
echo ""
echo "2. View logs:"
echo -e "   ${CYAN}kubectl logs -n $NAMESPACE my-kafka-kafka-0 -c kafka${NC}"
echo ""
echo "3. Access Kafka (port-forward):"
echo -e "   ${CYAN}kubectl port-forward -n $NAMESPACE svc/my-kafka-kafka-bootstrap 9092:9092${NC}"
echo ""
echo "4. Upgrade deployment:"
echo -e "   ${CYAN}./deploy-modular.sh $ENVIRONMENT${NC}"
echo ""
echo "5. View security documentation:"
echo -e "   ${CYAN}cat SECURITY.md${NC}"
echo ""
echo -e "${GREEN}✅ Modular deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Usage: ./deploy-modular.sh [sandbox|dev|prod]${NC}"
echo ""
