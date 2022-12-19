# Iris Streaming cluster tools
<b>Cluster-tools</b> is a helm chart that manages resources related to a bunch of Kubernetes tools that we have in our clusters. 

More specifically it can create the following resources:
* <b>External-secrets</b> cluster-secret-store and service account.
* <b> Filebeat</b> certificate & credentials secrets
* <b> Datadog agent</b> deployment
* <b> Ldap-proxy </b> deployment

## Parameters

| Parameter | Description | Default |
| ----------|-------------|---------- |
| `environment` | Cluster environment. eg. `sandbox` | -
| `clusterType` | Cluster type. eg. `external` | -
| `externalSecret.enabled` | Decides if external secrets resources are created | `False` 
| `ldapProxy.enabled` | Decides if ldap-proxy resources are created | `False`
| `filebeat.enabled` | Decides if filebeat resources are created | `False`
| `datadogAgent.enabled` | Decides if dataDogAgent resources are created | `False`'
