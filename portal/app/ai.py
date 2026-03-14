"""
OpenAI YAML generation + self-review.
Generates KafkaTopic and KafkaUser manifests, then asks the model to validate them.
"""

import os
import yaml
from openai import OpenAI

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

KAFKA_CLUSTER_NAME = os.environ.get("KAFKA_CLUSTER_NAME", "my-kafka")


def generate_yaml(body, topic_name: str, requested_by: str) -> tuple[str, str]:
    """
    Returns (topic_yaml, user_yaml) as plain strings.
    Raises ValueError if the model's self-review flags invalid YAML.
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
      - resource:
          type: topic
          name: {topic_name}
          patternType: literal
        host: "*"
        operations:
          - Write

Return ONLY the two YAML documents separated by ---
No markdown code blocks. No explanation. No extra text.
"""

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}],
        temperature=0,
    )

    raw = response.choices[0].message.content.strip()
    # Strip markdown code fences if model adds them anyway
    raw = raw.replace("```yaml", "").replace("```", "").strip()

    # --- Self-review ---
    review_prompt = f"""Review these two Kubernetes YAML manifests for Strimzi Kafka.

Check ALL of the following:
1. Valid YAML syntax (parseable)
2. apiVersion is kafka.strimzi.io/v1beta2
3. kind is KafkaTopic or KafkaUser
4. metadata.name is present
5. metadata.labels contains strimzi.io/cluster
6. spec fields match the Strimzi schema

Reply with only one of:
  VALID
  INVALID: <short reason>

---
{raw}
"""

    review = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": review_prompt}],
        temperature=0,
    )

    verdict = review.choices[0].message.content.strip()
    if verdict.upper().startswith("INVALID"):
        raise ValueError(f"AI self-review failed: {verdict}")

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
        raise ValueError("AI did not generate a KafkaTopic manifest")

    return topic_yaml, user_yaml
