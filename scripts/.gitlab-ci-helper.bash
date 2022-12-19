#!/usr/bin/bash

ROLE_ARN=$1
EKS_CLUSTER=$2

chmod 700 /builds/streaming-iris/iris-streaming-confluent-platform/iris-streaming-service-deployment/iris-streaming-external-service
apk update
apk add zip jq python3 python3-dev py3-pip gcc linux-headers libffi-dev openssl-dev make musl-dev curl
pip install --upgrade pip awscli
mkdir ~/.aws
touch ~/.aws/config
echo "[default]" > ~/.aws/config
echo "$REGION" >> ~/.aws/config
echo "$ROLE_ARN" >> ~/.aws/config
echo "credential_source=Ec2InstanceMetadata" >> ~/.aws/config
export EC2_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document  | jq  --raw-output '.region')
export AWS_ACCOUNT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq  --raw-output '.accountId')
export AWS_PROFILE=default
aws sts get-caller-identity
aws eks --region "$CLUSTER_REGION" update-kubeconfig --name "$EKS_CLUSTER"
