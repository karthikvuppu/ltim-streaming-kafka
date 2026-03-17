"""
Cognito JWT verification.
Validates the id_token sent by Streamlit as a Bearer header.
"""

import os
import requests
from functools import lru_cache
from fastapi import Header, HTTPException
from jose import jwt, JWTError, ExpiredSignatureError

COGNITO_REGION   = os.environ["COGNITO_REGION"]
USER_POOL_ID     = os.environ["COGNITO_USER_POOL_ID"]
CLIENT_ID        = os.environ.get("COGNITO_CLIENT_ID", "")

JWKS_URL = (
    f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com"
    f"/{USER_POOL_ID}/.well-known/jwks.json"
)


@lru_cache(maxsize=1)
def _get_jwks() -> dict:
    """Fetch Cognito public keys once and cache them."""
    resp = requests.get(JWKS_URL, timeout=5)
    resp.raise_for_status()
    return resp.json()


def verify_token(authorization: str = Header(...)) -> dict:
    """
    FastAPI dependency — call with Depends(verify_token).
    Returns: {"email": str, "sub": str, "groups": list[str], "lob": str}
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, detail="Authorization header must be 'Bearer <token>'")

    token = authorization[len("Bearer "):]

    try:
        jwks = _get_jwks()
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],
            audience=CLIENT_ID or None,
            options={"verify_aud": bool(CLIENT_ID)},
        )
    except ExpiredSignatureError:
        raise HTTPException(401, detail="Token has expired")
    except JWTError as exc:
        raise HTTPException(401, detail=f"Invalid token: {exc}")

    return {
        "email":  payload.get("email", ""),
        "sub":    payload.get("sub", ""),
        "groups": payload.get("cognito:groups", []),
        "lob":    payload.get("custom:team", ""),
    }
