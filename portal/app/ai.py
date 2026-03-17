"""
OpenAI API YAML generation + self-review.
Set OPENAI_API_KEY env var (stored in kafka-portal-secrets).
"""

import os
import yaml
from openai import OpenAI

GENERATE_MODEL = os.environ.get("OPENAI_MODEL", "gpt-3.5-turbo")
REVIEW_MODEL   = os.environ.get("OPENAI_REVIEW_MODEL", "gpt-3.5-turbo")

KAFKA_CLUSTER_NAME = os.environ.get("KAFKA_CLUSTER_NAME", "my-kafka")

_client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])


def _invoke(model_id: str, prompt: str) -> str:
    response = _client.chat.completions.create(
        model=model_id,
        temperature=0,
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.choices[0].message.content.strip()


def generate_yaml(body, topic_name: str, requested_by: str) -> tuple[str, str]:
    """
    Returns (topic_yaml, user_yaml).
    Raises ValueError if self-review flags invalid YAML.
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

--- MANIFEST 2: KafkaUser (producer for LOB {body.lob}) ---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: {body.lob}-producer
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
    raw = raw.replace("```yaml", "").replace("```", "").strip()

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
        raise ValueError(f"Self-review failed: {verdict}")

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
        raise ValueError("Model did not generate a KafkaTopic manifest")

    return topic_yaml, user_yaml
