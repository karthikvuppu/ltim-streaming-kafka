"""
Kafka Self-Service Portal — FastAPI backend
POST /request-topic  → validate → generate YAML → open GitHub PR
GET  /topics         → list topics for lob with status + connection details
GET  /health         → liveness check
"""

import os
import base64
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional

from auth import verify_token
from opa import validate_request
from ai import generate_yaml
from github_client import create_pr

try:
    from kubernetes import client as k8s_client, config as k8s_config
    try:
        k8s_config.load_incluster_config()
    except Exception:
        k8s_config.load_kube_config()
    _k8s_ready = True
except Exception:
    _k8s_ready = False

KAFKA_NAMESPACE     = os.environ.get("KAFKA_NAMESPACE", "kafka")
KAFKA_CLUSTER_NAME  = os.environ.get("KAFKA_CLUSTER_NAME", "my-kafka")
BOOTSTRAP_INTERNAL  = f"{KAFKA_CLUSTER_NAME}-kafka-bootstrap.{KAFKA_NAMESPACE}.svc:9092"

app = FastAPI(title="Kafka Self-Service Portal", version="1.0.0")


class TopicRequest(BaseModel):
    lob:             str       = Field(..., example="payments")
    entity:          str       = Field(..., example="transaction")
    event_type:      str       = Field(..., example="created")
    partitions:      int       = Field(..., ge=1, le=30)
    retention_hours: int       = Field(..., ge=1, le=720)
    description:     str       = Field(..., min_length=10)
    consumer_lobs:   list[str] = Field(default_factory=list)


class TopicResponse(BaseModel):
    topic_name: str
    pr_url:     str
    topic_yaml: str
    user_yaml:  str


@app.post("/request-topic", response_model=TopicResponse)
async def request_topic(
    body: TopicRequest,
    user: dict = Depends(verify_token),
):
    topic_name = f"{body.lob}.{body.entity}.{body.event_type}"

    # Validate naming + quotas
    validation = validate_request(
        topic_name=topic_name,
        partitions=body.partitions,
        retention_hours=body.retention_hours,
        lob=body.lob,
    )
    if not validation["allow"]:
        raise HTTPException(status_code=400, detail=validation["reason"])

    # Generate YAML via OpenAI
    try:
        topic_yaml, user_yaml = generate_yaml(body, topic_name, user["email"])
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    # Create GitHub PR
    try:
        pr_url = create_pr(topic_name, topic_yaml, user_yaml, user["email"])
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"GitHub PR failed: {exc}")

    return TopicResponse(
        topic_name=topic_name,
        pr_url=pr_url,
        topic_yaml=topic_yaml,
        user_yaml=user_yaml,
    )


@app.get("/topics")
def list_topics(user: dict = Depends(verify_token), lob: Optional[str] = None):
    """
    Return all KafkaTopics for the user's LOB with status + connection details.
    lob query param overrides the token's lob claim.
    """
    if not _k8s_ready:
        raise HTTPException(status_code=503, detail="Kubernetes client not available")

    lob = lob or user.get("lob") or ""

    custom_api = k8s_client.CustomObjectsApi()
    core_api   = k8s_client.CoreV1Api()

    # Fetch all KafkaTopics in the kafka namespace
    try:
        all_topics = custom_api.list_namespaced_custom_object(
            group="kafka.strimzi.io",
            version="v1beta2",
            namespace=KAFKA_NAMESPACE,
            plural="kafkatopics",
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to list topics: {exc}")

    # Fetch external bootstrap server from Kafka status
    bootstrap_external = ""
    try:
        kafka_cr = custom_api.get_namespaced_custom_object(
            group="kafka.strimzi.io",
            version="v1beta2",
            namespace=KAFKA_NAMESPACE,
            plural="kafkas",
            name=KAFKA_CLUSTER_NAME,
        )
        for listener in kafka_cr.get("status", {}).get("listeners", []):
            if listener.get("name") in ("external", "external9094"):
                bootstrap_external = listener.get("bootstrapServers", "")
                break
    except Exception:
        pass

    results = []
    for item in all_topics.get("items", []):
        topic_name = item["metadata"]["name"]
        # Filter: only show topics belonging to this LOB
        if not topic_name.startswith(f"{lob}."):
            continue

        conditions = item.get("status", {}).get("conditions", [])
        ready = any(
            c.get("type") == "Ready" and c.get("status") == "True"
            for c in conditions
        )
        partitions  = item.get("spec", {}).get("partitions", "-")
        retention_ms = item.get("spec", {}).get("config", {}).get("retention.ms", "-")
        retention_h  = f"{int(retention_ms)//3600000}h" if str(retention_ms).isdigit() else "-"
        requested_by = item.get("metadata", {}).get("annotations", {}).get("requested-by", "-")

        # Get SCRAM password from Kubernetes secret
        secret_name = f"{lob}-producer"
        username    = secret_name
        password    = ""
        try:
            secret = core_api.read_namespaced_secret(secret_name, KAFKA_NAMESPACE)
            raw = secret.data or {}
            pw_b64 = raw.get("password", "")
            if pw_b64:
                password = base64.b64decode(pw_b64).decode()
        except Exception:
            password = "(secret not yet ready)"

        results.append({
            "topic_name":         topic_name,
            "ready":              ready,
            "partitions":         partitions,
            "retention":          retention_h,
            "requested_by":       requested_by,
            "bootstrap_internal": BOOTSTRAP_INTERNAL,
            "bootstrap_external": bootstrap_external,
            "username":           username,
            "password":           password,
        })

    return {"topics": results, "lob": lob}


@app.get("/health")
def health():
    return {"status": "ok"}
