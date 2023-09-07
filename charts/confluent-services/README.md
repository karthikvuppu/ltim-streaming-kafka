# Connectivity Confluent services

**confluent-services** is a helm chart that manages resources related to Confluent Kafka resources in our Kubernetes clusters.

More specifically it supports the following service deployments and related resources:

1. Kafka
2. Zookeeper
3. Connect
4. Ksql
5. Restproxy
6. Controlcenter
7. Schema Registry

Other the managing the specific CRs for the services mentioned above, it also creates related resources like secrets, storage-classes etc.

## Parameters

| Parameter | Description | Default |
| ----------|-------------|---------- |
| `environment` | Cluster environment. eg. `sandbox` | -
| `clusterType` | Cluster type. eg. `external` | -
| `kerberos.activatedInKafka`    | Decides if Kerberos should be used. | `False`
| `controlCenter.ingress.enabled` | Decides if an ingress route will be created. | `False`
| `schemaRegistry.loadbalancer` | Decides if a LB should be created. | -
| `restProxy.loadbalancer` | Decides if a LB should be created. | -
| `restProxy.ingress` | Decides if an ingress route will be created. | -
| `ksql.enabled` | Decides if ksqlDB should be created. | -
| `connect.loadbalancer.internal` | Decides if a LB should be created. | -
| `kafka.listeners.internal.enabled` | Decides if internal listeners will be created. | -
| `kafka.listeners.external.enabled` | Decides if internal listeners will be created. | -
| `kafka.listeners.external.loadbalancer.internal` | Decides if a LB should be created. | -
| `kafka.listeners.custom.{name}.loadbalancer.enabled` | Decides if LB should be created for this listener. | -
| `kafka.listeners.custom.{name}.loadbalancer.internal` | Decides if LB should be created for this listener. | -

## Ingress Controller Resources

The Ingress Resources are technically not Confluent resources but are in direct dependency with the Confluent resources/values files from this chart. You can find the resources listed below [here](../confluent-services/templates/ingress/).

* IngressRoute: Routes HTTP and TCP connections.
* ServerTransport: Server transport configuration for the communication between Traefik and the servers.
