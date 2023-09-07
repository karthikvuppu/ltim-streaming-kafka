# Connectivity Cluster Tools

**Cluster-tools** is a helm chart that manages resources related to a bunch of Kubernetes tools that we have in our clusters.

More specifically it can create the following resources:

* **External-secrets** cluster-secret-store and service account.
* **Filebeat** certificate & credentials secrets.
* **Datadog agent** deployment.
* **Ldap-proxy** deployment.

## Parameters

| Parameter | Description | Default |
| ----------|-------------|---------- |
| `environment` | Cluster environment. eg. `sandbox` | -
| `clusterType` | Cluster type. eg. `external` | -
| `externalSecret.enabled` | Decides if external secrets resources are created | `False`
| `ldapProxy.enabled` | Decides if ldap-proxy resources are created | `False`
| `filebeat.enabled` | Decides if filebeat resources are created | `False`
| `datadogAgent.enabled` | Decides if dataDogAgent resources are created | `False`'

## Traefik Ingress Controller

The Ingress Controller is not included in the `cluster-tools` chart, but is a part of this deployment. Go to [cluster-tools.yml](../../cicd/templates/cluster-tools.yml) for the whole list of deployments.

The Ingress Controller uses 2 resources in this repo, which are included in `confluent-services` chart:

* IngressRoute: Routes HTTP and TCP connections.
* ServerTransport: Server transport configuration for the communication between Traefik and the servers.

Read more in the `confluent-services` charts [README.md](../../charts/confluent-services/README.md).

The official documentation of Traefik Ingress can be found [here](https://doc.traefik.io/traefik/providers/kubernetes-ingress/).
