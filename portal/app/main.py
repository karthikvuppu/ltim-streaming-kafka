"""
Kafka Self-Service Portal — FastAPI backend
POST /request-topic  → validate → generate YAML → open GitHub PR
GET  /health         → liveness check
"""

from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel, Field

from auth import verify_token
from opa import validate_request
from ai import generate_yaml
from github_client import create_pr

app = FastAPI(title="Kafka Self-Service Portal", version="1.0.0")


class TopicRequest(BaseModel):
    team:            str       = Field(..., example="payments")
    entity:          str       = Field(..., example="transaction")
    event_type:      str       = Field(..., example="created")
    partitions:      int       = Field(..., ge=1, le=30)
    retention_hours: int       = Field(..., ge=1, le=720)
    description:     str       = Field(..., min_length=10)
    consumer_teams:  list[str] = Field(default_factory=list)


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
    topic_name = f"{body.team}.{body.entity}.{body.event_type}"

    # Validate naming + quotas
    validation = validate_request(
        topic_name=topic_name,
        partitions=body.partitions,
        retention_hours=body.retention_hours,
        team=body.team,
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


@app.get("/health")
def health():
    return {"status": "ok"}
