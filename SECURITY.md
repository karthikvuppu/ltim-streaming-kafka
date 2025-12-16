# Kafka Security Configuration Guide

This document outlines the security enhancements implemented for the Kafka on EKS deployment and provides guidance on maintaining a secure Kafka cluster.

## Security Improvements Implemented

### 1. Transport Layer Security (TLS)

#### 1.1 Plaintext Listener Disabled in Production
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:8-9`

- Disabled unencrypted plaintext listener (port 9092) in production
- Only TLS-encrypted connections are allowed
- Prevents man-in-the-middle attacks and data interception

#### 1.2 External Listener with TLS
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:12-14`, `templates/kafka.yaml:24-27`

- Enabled TLS encryption on external LoadBalancer (port 9094)
- Added SCRAM-SHA-512 authentication requirement
- Prevents unauthorized external access

#### 1.3 Inter-Broker TLS
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:87-89`

- Configured `security.inter.broker.protocol: SSL`
- Enabled mutual TLS authentication (`ssl.client.auth: required`)
- Enabled hostname verification (`ssl.endpoint.identification.algorithm: HTTPS`)
- Encrypts replication traffic between brokers

#### 1.4 Zookeeper TLS
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:103-105`, `templates/kafka.yaml:106-127`

- Enabled TLS for Kafka-Zookeeper connections
- Prevents unauthorized access to cluster metadata

### 2. Authentication & Authorization

#### 2.1 SCRAM-SHA-512 Authentication
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:34-35`

- Enabled SCRAM-SHA-512 for TLS and external listeners
- Provides strong password-based authentication
- Credentials stored in Kubernetes secrets

#### 2.2 ACL-Based Authorization
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:69-74`, `templates/kafka.yaml:43-50`

- Configured Simple ACL authorizer
- Defined super users for operators
- Implements least-privilege access control

#### 2.3 KafkaUser Management
**Status**: ✅ Implemented
**Location**: `templates/kafka-user-example.yaml`, `values-prod.yaml:86-120`

- Created example producer and consumer users with specific ACLs
- Users can be managed via Kubernetes CRDs
- Fine-grained permissions per topic and consumer group

### 3. Network Security

#### 3.1 Kubernetes NetworkPolicies
**Status**: ✅ Implemented
**Location**: `templates/networkpolicy.yaml`

**Kafka NetworkPolicy**:
- Restricts ingress to allowed namespaces only
- Allows monitoring from Prometheus namespace
- Permits inter-broker communication
- Blocks unauthorized pod-to-pod traffic

**Zookeeper NetworkPolicy**:
- Only allows access from Kafka brokers and Entity Operators
- Restricts inter-Zookeeper communication to cluster members
- Prevents direct external access

**Entity Operator NetworkPolicy**:
- Allows access to Kafka and Zookeeper
- Permits Kubernetes API access for CRD management
- Enables monitoring endpoints

#### 3.2 Auto-Create Topics Disabled
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:68`

- Disabled `auto.create.topics.enable` in production
- Prevents resource exhaustion attacks
- Enforces topic governance

### 4. Data Protection

#### 4.1 Encryption at Rest
**Status**: ✅ Implemented
**Location**: `templates/storageclass.yaml`, `values-prod.yaml:4-15`

- Created encrypted StorageClass using AWS KMS
- Configured gp3 volumes with encryption enabled
- Applied to both Kafka and Zookeeper persistent volumes
- Supports customer-managed KMS keys (optional)

**Configuration**:
```yaml
storageClass:
  enabled: true
  name: kafka-gp3-encrypted
  type: gp3
  encrypted: true
  # Optional: kmsKeyId for customer-managed keys
```

### 5. Audit & Compliance

#### 5.1 Audit Logging
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:53-67`, `templates/kafka.yaml:78-82`

- Enabled Kafka authorizer audit logging
- Logs all authorization decisions
- Configured rolling file appender (100MB per file, 10 backups)
- Critical for compliance and forensics

**Log Location**: `/var/lib/kafka/kafka-authorizer.log`

### 6. Container Security

#### 6.1 Pod Security Standards
**Status**: ✅ Implemented
**Location**: `values-prod.yaml:20-27,108-114`, `templates/kafka.yaml:12-31,109-126`

**Kafka Pods**:
- Run as non-root user (UID 1000)
- Seccomp profile: RuntimeDefault
- No privilege escalation
- All capabilities dropped
- ReadOnly root filesystem where possible

**Zookeeper Pods**:
- Same security context as Kafka
- Prevents container escape attacks
- Follows least-privilege principle

## Security Checklist for Production Deployment

### Pre-Deployment

- [ ] Review and customize NetworkPolicy allowed namespaces
- [ ] Generate strong passwords for KafkaUsers
- [ ] Configure customer-managed KMS key (optional)
- [ ] Review and adjust ACLs per application requirements
- [ ] Enable AWS EBS CSI driver with KMS support
- [ ] Ensure monitoring namespace exists

### Post-Deployment

- [ ] Verify TLS certificates are generated and valid
- [ ] Test client connections with TLS and SCRAM-SHA-512
- [ ] Verify NetworkPolicies are enforced
- [ ] Check audit logs are being written
- [ ] Confirm encryption at rest is active
- [ ] Review Pod security context is applied
- [ ] Test that auto-create topics is disabled
- [ ] Validate inter-broker TLS communication

### Ongoing Maintenance

- [ ] Rotate KafkaUser credentials regularly (90 days recommended)
- [ ] Monitor audit logs for unauthorized access attempts
- [ ] Review and update ACLs as applications change
- [ ] Keep Strimzi operator updated for security patches
- [ ] Monitor certificate expiration (Strimzi auto-rotates)
- [ ] Regular security audits of NetworkPolicies
- [ ] Review and rotate KMS keys annually

## Retrieving User Credentials

To retrieve a KafkaUser's password:

```bash
kubectl get secret app-producer -n kafka -o jsonpath='{.data.password}' | base64 -d
```

## Connecting Securely

### Producer Example (with TLS & SCRAM)

```properties
bootstrap.servers=my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9093
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="app-producer" \
  password="<password-from-secret>";
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=<truststore-password>
```

### Consumer Example (with TLS & SCRAM)

```properties
bootstrap.servers=my-kafka-kafka-bootstrap.kafka.svc.cluster.local:9093
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="app-consumer" \
  password="<password-from-secret>";
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=<truststore-password>
group.id=my-consumer-group
```

## Certificate Management

Strimzi automatically manages certificates:

### Cluster CA Certificate

```bash
# Extract cluster CA certificate
kubectl get secret my-kafka-cluster-ca-cert -n kafka \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

# Create truststore for clients
keytool -import -trustcacerts -alias root \
  -file ca.crt -keystore truststore.jks -storepass changeit
```

### Certificate Rotation

Strimzi automatically rotates certificates before expiration:
- Cluster CA: Valid for 365 days, renewed at 30 days before expiration
- Client CA: Valid for 365 days, renewed at 30 days before expiration
- Broker certificates: Valid for 90 days, renewed at 30 days before expiration

## Network Policy Customization

To allow access from additional namespaces, update `values-prod.yaml`:

```yaml
networkPolicy:
  enabled: true
  allowedNamespaces:
    - default
    - app-namespace
    - my-new-namespace  # Add here
  monitoringNamespace: monitoring
  allowExternalEgress: false
```

## Monitoring Security Metrics

Key metrics to monitor:
- Failed authentication attempts
- Authorization failures (from audit logs)
- TLS connection errors
- Certificate expiration dates
- Network policy drops (if supported by CNI)

## Compliance Standards

This configuration helps meet requirements for:
- **GDPR**: Encryption at rest and in transit, audit logging
- **HIPAA**: Access control, audit trails, encryption
- **PCI DSS**: Network segmentation, encryption, access control
- **SOC 2**: Security controls, logging, monitoring

## Security Incident Response

In case of security incident:

1. **Isolate**: Update NetworkPolicy to block suspected namespace
2. **Revoke**: Delete compromised KafkaUser
3. **Audit**: Review audit logs for unauthorized access
4. **Rotate**: Generate new credentials for affected users
5. **Investigate**: Analyze pod logs and network traffic
6. **Remediate**: Apply patches and update configurations

## Additional Recommendations

### Not Yet Implemented

These security measures can be added for enhanced security:

1. **External Secret Management**:
   - Use AWS Secrets Manager or HashiCorp Vault
   - Integrate via External Secrets Operator

2. **mTLS for Clients**:
   - Require client certificates instead of SCRAM
   - Configure `authentication.type: tls`

3. **OAuth/OIDC Integration**:
   - Integrate with corporate identity provider
   - Configure `authentication.type: oauth`

4. **Advanced Audit Logging**:
   - Ship logs to centralized SIEM (Splunk, ELK)
   - Configure real-time alerting

5. **AWS PrivateLink**:
   - Use PrivateLink instead of NLB for external access
   - Eliminates internet exposure

6. **Pod Disruption Budgets**:
   - Prevent simultaneous pod termination
   - Enhance availability during updates

7. **Resource Quotas**:
   - Limit namespace resource consumption
   - Prevent resource exhaustion

## References

- [Strimzi Security Documentation](https://strimzi.io/docs/operators/latest/overview.html#security-configuration_str)
- [Apache Kafka Security](https://kafka.apache.org/documentation/#security)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

## Support

For security issues or questions:
1. Review Strimzi documentation
2. Check Kafka security best practices
3. Consult your security team
4. File issues in the repository

---

**Last Updated**: 2025-12-16
**Version**: 1.0.0
**Status**: Production Ready
