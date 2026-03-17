"""
Inline validation rules — equivalent to OPA policies, no server needed.
All rules return {"allow": bool, "reason": str}
"""

import re

# Allowed event type vocabulary
ALLOWED_EVENT_TYPES = {
    "created", "updated", "deleted", "failed",
    "approved", "rejected", "submitted", "processed",
}

# Max partitions per LOB (sandbox defaults)
PARTITION_QUOTA: dict[str, int] = {
    "default":     10,
    "payments":    20,
    "analytics":   30,
    "engineering": 15,
    "platform":    20,
    "audit":       10,
}

MAX_RETENTION_HOURS = 720  # 30 days hard cap for sandbox


def validate_request(topic_name: str, partitions: int, retention_hours: int, lob: str) -> dict:
    parts = topic_name.split(".")

    # Rule 1: must be <lob>.<entity>.<event_type>
    if len(parts) != 3:
        return {"allow": False, "reason": "Topic name must follow <lob>.<entity>.<event_type>"}

    req_lob, entity, event_type = parts

    # Rule 2: lob in topic must match requesting LOB
    if req_lob != lob:
        return {"allow": False, "reason": f"Topic LOB '{req_lob}' must match your LOB '{lob}'"}

    # Rule 3: lowercase + safe characters only
    if not re.fullmatch(r"[a-z0-9.\-]+", topic_name):
        return {"allow": False, "reason": "Only lowercase letters, numbers, dots and hyphens allowed"}

    # Rule 4: entity and event_type cannot be empty
    if not entity or not event_type:
        return {"allow": False, "reason": "Entity and event_type cannot be empty"}

    # Rule 5: event_type from allowed vocabulary
    if event_type not in ALLOWED_EVENT_TYPES:
        return {
            "allow": False,
            "reason": f"Event type '{event_type}' not allowed. Use one of: {sorted(ALLOWED_EVENT_TYPES)}",
        }

    # Rule 6: partition quota per LOB
    max_partitions = PARTITION_QUOTA.get(lob, PARTITION_QUOTA["default"])
    if partitions > max_partitions:
        return {"allow": False, "reason": f"LOB '{lob}' max partitions is {max_partitions}, requested {partitions}"}

    # Rule 7: retention cap
    if retention_hours > MAX_RETENTION_HOURS:
        return {"allow": False, "reason": f"Max retention is {MAX_RETENTION_HOURS}h (30 days) for sandbox"}

    return {"allow": True, "reason": ""}
