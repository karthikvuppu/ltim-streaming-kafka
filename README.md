# Iris Streaming service deployment
This repository contains services and tools for Iris Streaming Kubernetes clusters.

General structure is split up into 4 parts:

* [Internal Helm charts](/charts)
* [CFK operator values](/operator)
* [Confluent services values](/confluent-services/)
* [Tooling values](/tooling)
    * [Tooling w/o value](.gitlab-ci.yml)

Each part is described further below.
# Repository Content
## Internal Helm Charts

To better manage Iris specific K8s resources two helm charts have been created, confluent-services & cluster-tools. 

* <b>cluster-tools</b> chart manages tool specific resources, eg. external-secrets secret store & service account.

* <b>confluent-services</b> chart manages CFK custom resources, such as Kafka, Zookeeper, Connect instances etc. 

More information is available in each charts documentation.

## Confluent services values
Contains cluster specific helm chart values for the [confluent-services](charts/confluent-services) chart. These are to be seen as the true source of how our Confluent services are declared in each cluster. 

Official documentation from Confluent is available here: https://docs.confluent.io/operator/current/overview.html

## Operator values
Contains cluster specific helm chart values for Confluent for Kubernetes chart. The chart itself is located in Confluents helm repository https://packages.confluent.io/helm. 


## Tooling values
Contains cluster specific helm chart values for the [cluster-tooling](charts/cluster-tools/) chart. 

### Tools without values
External charts which requires no additional values file.

Charts:
* [bitnami/external-dns](https://github.com/bitnami/charts/tree/main/bitnami/external-dns)
* [stakater/reloader](https://github.com/stakater/Reloader)


# CICD

