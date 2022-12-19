# Iris Streaming Confluent services 
<b>Confluent services</b> is a helm chart that manages resources related to Confluent Kafka resources in our Kubernetes clusters.

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
Parameters list will be finalized when helm chart is no longer a work in progress.