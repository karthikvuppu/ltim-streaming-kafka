"""
Amazon Bedrock YAML generation + self-review.
Uses Claude via Bedrock — no API key needed, credentials come from IRSA.
"""

import os
import json
import boto3
import yaml

BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "eu-west-1")
GENERATE_MODEL = os.environ.get("BEDROCK_MODEL", "eu.anthropic.claude-3-5-sonnet-20240620-v1:0")
REVIEW_MODEL   = os.environ.get("BEDROCK_REVIEW_MODEL", "eu.anthropic.claude-3-haiku-20240307-v1:0")

KAFKA_CLUSTER_NAME = os.environ.get("KAFKA_CLUSTER_NAME", "my-kafka")

# boto3 picks up credentials automatically via IRSA (projected service account token)
_bedrock = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)


def _invoke(model_id: str, prompt: str) -> str:
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 2048,
        "temperature": 0,
        "messages": [{"role": "user", "content": prompt}],
    })
    response = _bedrock.invoke_model(modelId=model_id, body=body)
    result = json.loads(response["body"].read())
    return result["content"][0]["text"].strip()


def generate_yaml(body, topic_name: str, requested_by: str) -> tuple[str, str]:
    """
    Returns (topic_yaml, user_yaml).
    Raises ValueError if Bedrock self-review flags invalid YAML.
    """
    retention_ms = body.retention_hours * 3600 * 1000

    prompt = f"""Generate two Kubernetes YAML manifests for a Strimzi Kafka deployment on EKS.

--- MANIFEST 1: KafkaTopic ---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: {topic_name}
  namespace: kafka
  labels:
    strimzi.io/cluster: {KAFKA_CLUSTER_NAME}
  annotations:
    requested-by: "{requested_by}"
    description: "{body.description}"
spec:
  partitions: {body.partitions}
  replicas: 1
  config:
    retention.ms: {retention_ms}
    cleanup.policy: delete
    min.insync.replicas: "1"

--- MANIFEST 2: KafkaUser (producer for team {body.team}) ---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: {body.team}-producer
  namespace: kafka
  labels:
    strimzi.io/cluster: {KAFKA_CLUSTER_NAME}
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: {topic_name}
          patternType: literal
        operations:
          - Write
          - Describe

Return ONLY the two YAML documents separated by ---
No markdown code blocks. No explanation. No extra text."""

    raw = _invoke(GENERATE_MODEL, prompt)
    # Strip markdown fences if model adds them anyway
    raw = raw.replace("```yaml", "").replace("```", "").strip()

    # Self-review with smaller/faster Haiku model
    review_prompt = f"""Review these two Kubernetes YAML manifests for Strimzi Kafka.

Check ALL of the following:
1. Valid YAML syntax (parseable)
2. apiVersion is kafka.strimzi.io/v1beta2
3. kind is KafkaTopic or KafkaUser
4. metadata.name is present
5. metadata.labels contains strimzi.io/cluster

Reply with only one of:
  VALID
  INVALID: <short reason>

---
{raw}"""

    verdict = _invoke(REVIEW_MODEL, review_prompt)
    if verdict.upper().startswith("INVALID"):
        raise ValueError(f"Bedrock self-review failed: {verdict}")

    # Parse and re-serialize for consistent formatting
    docs = list(yaml.safe_load_all(raw))

    topic_yaml = ""
    user_yaml  = ""

    for doc in docs:
        if doc is None:
            continue
        serialized = yaml.dump(doc, default_flow_style=False, sort_keys=False)
        if doc.get("kind") == "KafkaTopic":
            topic_yaml = serialized
        elif doc.get("kind") == "KafkaUser":
            user_yaml = serialized

    if not topic_yaml:
        raise ValueError("Bedrock did not generate a KafkaTopic manifest")

    return topic_yaml, user_yaml
