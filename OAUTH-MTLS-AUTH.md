# OAuth and mTLS Authentication Guide

## Overview

This Kafka deployment supports **OAuth 2.0 / OIDC** and **Mutual TLS (mTLS)** authentication methods instead of SCRAM-SHA-512. These methods provide stronger security and better integration with modern identity providers and certificate-based infrastructure.

---

## Authentication Methods

### 1. OAuth 2.0 / OIDC (Token-Based)

**Use Case**: Microservices, applications, user authentication
**Pros**: Centralized identity management, token-based, supports SSO
**Cons**: Requires OAuth provider (Keycloak, Auth0, etc.)

### 2. Mutual TLS (Certificate-Based)

**Use Case**: Service-to-service communication, high security requirements
**Pros**: No external dependencies, strong cryptographic security
**Cons**: Certificate management complexity

### 3. Combined (OAuth + mTLS)

**Use Case**: Defense-in-depth, highest security environments
**Pros**: Requires both valid certificate AND valid token
**Cons**: Highest complexity

---

## Configuration

### Current Default

**File**: `helm/kafka-eks/values-security.yaml`

```yaml
authentication:
  defaultMethod: oauth  # Change to "tls" for mTLS only

  methods:
    oauth:
      enabled: true
    mtls:
      enabled: true
    scram:
      enabled: false  # Deprecated
```

---

## Option 1: OAuth Authentication

### Prerequisites

1. **OAuth Provider** (choose one):
   - Keycloak (recommended for self-hosted)
   - Auth0
   - Okta
   - Azure AD
   - Google Cloud Identity
   - AWS Cognito

2. **Strimzi OAuth Library**:
   - Already included in Strimzi Kafka images
   - No additional installation required

### OAuth Provider Setup

#### Example: Keycloak

**Step 1: Create Realm**
```bash
# In Keycloak Admin Console
Realm: kafka
```

**Step 2: Create Client**
```yaml
Client ID: kafka-broker
Client Protocol: openid-connect
Access Type: confidential
Service Accounts Enabled: true
Authorization Enabled: true
```

**Step 3: Configure Kafka Client**
```yaml
Valid Redirect URIs: *
Web Origins: *
```

**Step 4: Create Users/Service Accounts**
```yaml
Username: kafka-producer-app
Client ID: kafka-producer-app
Groups: [producers]
```

**Step 5: Get Configuration URLs**
```bash
# Keycloak realm configuration
Token Endpoint: https://keycloak.example.com/realms/kafka/protocol/openid-connect/token
JWKS Endpoint: https://keycloak.example.com/realms/kafka/protocol/openid-connect/certs
Issuer: https://keycloak.example.com/realms/kafka
```

### Kafka Configuration

**File**: `helm/kafka-eks/values-security.yaml`

```yaml
authentication:
  defaultMethod: oauth

  methods:
    oauth:
      enabled: true

      # Your OAuth provider configuration
      clientId: "kafka-broker"
      clientSecret: ""  # Set via Kubernetes secret

      # Update these with your OAuth provider URLs
      tokenEndpointUri: "https://keycloak.example.com/realms/kafka/protocol/openid-connect/token"
      jwksEndpointUri: "https://keycloak.example.com/realms/kafka/protocol/openid-connect/certs"
      validIssuerUri: "https://keycloak.example.com/realms/kafka"

      # Token validation
      checkIssuer: true
      checkAudience: true
      audience: "kafka"

      # User mapping
      usernameClaim: "preferred_username"
      fallbackUsernameClaim: "client_id"

      # Authorization groups
      groupsClaim: "groups"
```

### Store OAuth Client Secret

```bash
# Create Kubernetes secret for OAuth client secret
kubectl create secret generic kafka-oauth-client-secret \
  --from-literal=clientSecret='<your-client-secret>' \
  -n kafka

# Or from file
echo -n '<your-client-secret>' > client-secret.txt
kubectl create secret generic kafka-oauth-client-secret \
  --from-file=clientSecret=client-secret.txt \
  -n kafka
```

### Client Application Configuration

**Producer Example (Java)**:
```properties
bootstrap.servers=my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9093
security.protocol=SASL_SSL
sasl.mechanism=OAUTHBEARER
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required \
  oauth.client.id="kafka-producer-app" \
  oauth.client.secret="<client-secret>" \
  oauth.token.endpoint.uri="https://keycloak.example.com/realms/kafka/protocol/openid-connect/token" \
  oauth.scope="kafka";
sasl.login.callback.handler.class=io.strimzi.kafka.oauth.client.JaasClientOauthLoginCallbackHandler

# SSL/TLS
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=changeit
```

**Consumer Example (Python)**:
```python
from kafka import KafkaConsumer
from kafka.oauth import AbstractTokenProvider

class OAuth2TokenProvider(AbstractTokenProvider):
    def token(self):
        # Get token from OAuth provider
        response = requests.post(
            "https://keycloak.example.com/realms/kafka/protocol/openid-connect/token",
            data={
                "grant_type": "client_credentials",
                "client_id": "kafka-consumer-app",
                "client_secret": "<client-secret>",
                "scope": "kafka"
            }
        )
        return response.json()["access_token"]

consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers='my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9093',
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=OAuth2TokenProvider(),
    ssl_cafile='/path/to/ca.crt'
)
```

---

## Option 2: Mutual TLS (mTLS) Authentication

### Prerequisites

1. **Certificate Authority (CA)**:
   - Strimzi auto-creates cluster CA
   - Or use your own CA (corporate PKI)

2. **Client Certificates**:
   - Generated per client/application
   - Signed by trusted CA

### Certificate Generation

#### Using Strimzi Cluster CA

**Step 1: Extract Cluster CA**
```bash
# Get cluster CA certificate
kubectl get secret my-kafka-cluster-ca-cert -n kafka \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

# Get cluster CA key (if needed for signing)
kubectl get secret my-kafka-cluster-ca -n kafka \
  -o jsonpath='{.data.ca\.key}' | base64 -d > ca.key
```

**Step 2: Generate Client Certificate**
```bash
# Create private key
openssl genrsa -out client.key 2048

# Create certificate signing request (CSR)
openssl req -new -key client.key -out client.csr \
  -subj "/CN=kafka-producer-app/OU=applications/O=mycompany/C=US"

# Sign with cluster CA
openssl x509 -req -in client.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -days 365 -sha256

# Create PKCS12 keystore (for Java clients)
openssl pkcs12 -export \
  -in client.crt -inkey client.key -out client.p12 \
  -name kafka-client -CAfile ca.crt -caname root \
  -password pass:changeit
```

**Step 3: Create Truststore**
```bash
# Create Java truststore with CA certificate
keytool -import -trustcacerts -alias root \
  -file ca.crt -keystore truststore.jks \
  -storepass changeit -noprompt
```

### Kafka Configuration

**File**: `helm/kafka-eks/values-security.yaml`

```yaml
authentication:
  defaultMethod: tls  # Use mTLS

  methods:
    mtls:
      enabled: true
      certificateValidation:
        enabled: true
        requireClientCert: true
```

### Client Application Configuration

**Producer Example (Java)**:
```properties
bootstrap.servers=my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9093
security.protocol=SSL

# Client certificate (for authentication)
ssl.keystore.location=/path/to/client.p12
ssl.keystore.password=changeit
ssl.keystore.type=PKCS12
ssl.key.password=changeit

# Server certificate trust (for encryption)
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=changeit

# Certificate validation
ssl.endpoint.identification.algorithm=HTTPS
```

**Consumer Example (Python)**:
```python
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers='my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9093',
    security_protocol='SSL',
    ssl_cafile='/path/to/ca.crt',
    ssl_certfile='/path/to/client.crt',
    ssl_keyfile='/path/to/client.key',
    ssl_check_hostname=True
)
```

---

## Option 3: Combined Authentication (OAuth + mTLS)

### Use Case

Defense-in-depth security where both a valid certificate AND a valid OAuth token are required.

### Configuration

**File**: `helm/kafka-eks/values-security.yaml`

```yaml
authentication:
  defaultMethod: oauth

  combined:
    enabled: true  # Require BOTH certificate AND token

  methods:
    oauth:
      enabled: true
      # ... OAuth configuration ...

    mtls:
      enabled: true
      # ... mTLS configuration ...
```

### Client Configuration

Clients must provide:
1. **Valid X.509 client certificate** (mTLS)
2. **Valid OAuth 2.0 access token** (OAuth)

```properties
# Combined: SSL + SASL_SSL with OAuth
security.protocol=SASL_SSL
sasl.mechanism=OAUTHBEARER

# OAuth configuration
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required ...

# mTLS configuration
ssl.keystore.location=/path/to/client.p12
ssl.keystore.password=changeit
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=changeit
```

---

## Authorization with OAuth/mTLS

### OAuth Group-Based Authorization

**OAuth Provider Configuration** (Keycloak example):
```yaml
# Create groups in Keycloak
Groups:
  - kafka-producers
  - kafka-consumers
  - kafka-admins

# Assign users to groups
User: kafka-producer-app
Groups: [kafka-producers]
```

**Kafka ACL Configuration**:
```yaml
authorization:
  roles:
    producer:
      permissions:
        - resource:
            type: topic
            name: "*"
          operations: [Write, Describe]

      # Map to OAuth group
      oauthGroup: "kafka-producers"
```

**Token Claims**:
```json
{
  "sub": "kafka-producer-app",
  "preferred_username": "kafka-producer-app",
  "groups": ["kafka-producers"],
  "aud": "kafka"
}
```

### mTLS Certificate-Based Authorization

**Certificate Subject Mapping**:
```yaml
# Certificate DN
CN=kafka-producer-app,OU=applications,O=mycompany,C=US

# Maps to Kafka principal
User:CN=kafka-producer-app
```

**ACL Configuration**:
```yaml
authorization:
  superUsers:
    - User:CN=kafka-admin,OU=admins,O=mycompany,C=US

  roles:
    producer:
      permissions:
        - resource:
            type: topic
            name: "*"
          operations: [Write]

      # Map to certificate DN pattern
      certificateDN: "CN=kafka-producer-*,OU=applications,O=mycompany,C=US"
```

---

## Environment-Specific Configuration

### Development Environment

**File**: `helm/kafka-eks/environments/dev.yaml`

```yaml
# OAuth with relaxed validation (for dev)
security:
  enabled: true
  features:
    authentication: true

authentication:
  methods:
    oauth:
      # Development OAuth server
      tokenEndpointUri: "https://keycloak-dev.example.com/realms/kafka-dev/protocol/openid-connect/token"
      jwksEndpointUri: "https://keycloak-dev.example.com/realms/kafka-dev/protocol/openid-connect/certs"
      validIssuerUri: "https://keycloak-dev.example.com/realms/kafka-dev"

      # Relaxed for dev
      hostnameVerification: false
```

### Production Environment

**File**: `helm/kafka-eks/environments/production.yaml`

```yaml
# OAuth with strict validation
security:
  enabled: true
  features:
    authentication: true

authentication:
  methods:
    oauth:
      # Production OAuth server
      tokenEndpointUri: "https://keycloak.example.com/realms/kafka/protocol/openid-connect/token"
      jwksEndpointUri: "https://keycloak.example.com/realms/kafka/protocol/openid-connect/certs"
      validIssuerUri: "https://keycloak.example.com/realms/kafka"

      # Strict validation
      checkIssuer: true
      checkAudience: true
      hostnameVerification: true

      # Custom claim validation
      customClaimCheck: "@.groups && @.groups contains 'kafka-users'"
```

---

## Deployment

### Deploy with OAuth

```bash
# Update OAuth configuration in values-security.yaml
vim helm/kafka-eks/values-security.yaml

# Set OAuth client secret
kubectl create secret generic kafka-oauth-client-secret \
  --from-literal=clientSecret='<secret>' \
  -n kafka

# Deploy
./deploy-modular.sh production
```

### Deploy with mTLS

```bash
# Update authentication method
# values-security.yaml: defaultMethod: tls

# Deploy
./deploy-modular.sh production
```

---

## Troubleshooting

### OAuth Issues

**Problem**: Authentication failures

**Solution**:
```bash
# Check OAuth configuration
kubectl get configmap my-kafka-oauth-config -n kafka -o yaml

# Check broker logs
kubectl logs my-kafka-kafka-0 -n kafka | grep -i oauth

# Test token validation
curl -X POST https://keycloak.example.com/realms/kafka/protocol/openid-connect/token \
  -d "grant_type=client_credentials" \
  -d "client_id=kafka-producer-app" \
  -d "client_secret=<secret>"
```

### mTLS Issues

**Problem**: Certificate validation failures

**Solution**:
```bash
# Verify client certificate
openssl x509 -in client.crt -text -noout

# Check certificate chain
openssl verify -CAfile ca.crt client.crt

# Test TLS connection
openssl s_client -connect my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9093 \
  -cert client.crt -key client.key -CAfile ca.crt
```

---

## Comparison: OAuth vs mTLS

| Feature | OAuth | mTLS | Combined |
|---------|-------|------|----------|
| **Complexity** | Medium | Low | High |
| **External Dependency** | Yes (OAuth provider) | No | Yes |
| **Token Expiration** | Yes (configurable) | No (long-lived certs) | Both |
| **Revocation** | Immediate (token) | Slow (CRL/OCSP) | Immediate |
| **User Management** | Centralized | Distributed | Centralized |
| **Best For** | Microservices, APIs | Service-to-service | High security |
| **Performance** | Moderate (token validation) | High | Moderate |

---

## Migration from SCRAM

### Step 1: Enable OAuth/mTLS Alongside SCRAM

```yaml
authentication:
  methods:
    scram:
      enabled: true  # Keep temporarily
    oauth:
      enabled: true  # Enable new method
```

### Step 2: Update Applications Gradually

Update clients one by one to use OAuth or mTLS.

### Step 3: Disable SCRAM

```yaml
authentication:
  methods:
    scram:
      enabled: false  # Disable old method
```

---

## Security Best Practices

1. **Use OAuth for microservices** - Better token management
2. **Use mTLS for service-to-service** - No external dependencies
3. **Enable hostname verification** - Prevent MITM attacks
4. **Rotate certificates regularly** - 90 days for client certs
5. **Use short-lived tokens** - 5-15 minutes for OAuth
6. **Enable audit logging** - Track all authentication attempts
7. **Use combined auth for admin** - Defense in depth

---

## References

- [Strimzi OAuth Documentation](https://strimzi.io/docs/operators/latest/configuring.html#assembly-oauth-authentication_str)
- [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749)
- [Kafka mTLS Configuration](https://kafka.apache.org/documentation/#security_ssl)

---

**Version**: 1.0.0
**Last Updated**: 2025-12-16
**Authentication**: OAuth 2.0 / OIDC + Mutual TLS
