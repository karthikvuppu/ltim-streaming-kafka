#!/bin/bash

export SECRET=$(aws secretsmanager get-secret-value --secret-id $CLUSTERLINK_SECRET --region $CLUSTER_REGION --query "SecretString" --output text)
KEY_PASSWORD=$(echo $SECRET | jq -r '.keystorepw')
JAAS_PASSWORD=$(echo $SECRET | jq -r '.jaaspw')
kubectl get secret tls-group -n confluent -o jsonpath='{.data.cacerts\.pem}' | base64 -d > cacert.pem
kubectl get secret tls-group -n confluent -o jsonpath='{.data.fullchain\.pem}' | base64 -d > fullchain.pem
kubectl get secret tls-group -n confluent -o jsonpath='{.data.privkey\.pem}' | base64 -d > privkey.pem
keytool -import -file cacert.pem -keystore truststore.p12 -storetype PKCS12 -storepass $KEY_PASSWORD -noprompt
openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out keystore.p12 -password pass:$KEY_PASSWORD
### If certs get renewed in aws secret manager then in order to update kubernetes secrets below, we need to remove it first from cluster and then run this pipeline ####
kubectl get secret kafka-secrets-clusterlink -n confluent || kubectl create secret generic kafka-secrets-clusterlink --from-file=keystore.p12=keystore.p12 --from-file=truststore.p12=truststore.p12 -n confluent 

cat <<EOF > client.properties
#Config file created through gitlab cicd#
bootstrap.servers=kafka.confluent.svc.cluster.local:9071
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="operator" password=$JAAS_PASSWORD;
sasl.mechanism=PLAIN
security.protocol=SASL_SSL
ssl.truststore.location=/etc/kafka/secrets/truststore.p12
ssl.truststore.password=$KEY_PASSWORD
ssl.keystore.location=/etc/kafka/secrets/keystore.p12
ssl.keystore.password=$KEY_PASSWORD
ssl.key.password=$KEY_PASSWORD
EOF

kubectl get configmap kafka-client-config-clusterlink -n confluent || kubectl create configmap kafka-client-config-clusterlink --from-file=client.properties -n confluent