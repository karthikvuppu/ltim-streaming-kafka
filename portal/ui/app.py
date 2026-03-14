"""
Kafka Self-Service Portal — Streamlit UI
Native Cognito login form (USER_PASSWORD_AUTH via boto3).
No OAuth2 redirect required — works over plain HTTP.
"""

import os
import hmac
import hashlib
import base64

import boto3
import requests
import streamlit as st
from botocore.exceptions import ClientError

# ── Config from env vars ──────────────────────────────────────────────────────
COGNITO_REGION    = os.environ.get("COGNITO_REGION", "eu-north-1")
CLIENT_ID         = os.environ.get("COGNITO_CLIENT_ID", "")
CLIENT_SECRET     = os.environ.get("COGNITO_CLIENT_SECRET", "")
API_URL           = os.environ.get("API_URL", "http://kafka-portal-api:8000")

ALLOWED_EVENT_TYPES = [
    "created", "updated", "deleted", "failed",
    "approved", "rejected", "submitted", "processed",
]
TEAMS = ["payments", "analytics", "engineering", "platform", "audit"]

_cognito = boto3.client("cognito-idp", region_name=COGNITO_REGION)


# ── Auth helpers ──────────────────────────────────────────────────────────────

def _secret_hash(username: str) -> str:
    msg = username + CLIENT_ID
    digest = hmac.new(CLIENT_SECRET.encode(), msg.encode(), digestmod=hashlib.sha256).digest()
    return base64.b64encode(digest).decode()


def _login(email: str, password: str) -> dict:
    return _cognito.initiate_auth(
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={
            "USERNAME":    email,
            "PASSWORD":    password,
            "SECRET_HASH": _secret_hash(email),
        },
        ClientId=CLIENT_ID,
    )


def _set_new_password(email: str, new_password: str, session: str) -> dict:
    return _cognito.respond_to_auth_challenge(
        ChallengeName="NEW_PASSWORD_REQUIRED",
        ClientId=CLIENT_ID,
        ChallengeResponses={
            "USERNAME":     email,
            "NEW_PASSWORD": new_password,
            "SECRET_HASH":  _secret_hash(email),
        },
        Session=session,
    )


# ── Login page ────────────────────────────────────────────────────────────────

def _login_page():
    st.title("Kafka Self-Service Portal")
    st.markdown("Request new Kafka topics through a self-service workflow.")
    st.markdown("---")

    # Handle NEW_PASSWORD_REQUIRED challenge
    if "auth_session" in st.session_state:
        st.subheader("Set a new password")
        st.info("Your temporary password must be changed before you can continue.")
        with st.form("new_password_form"):
            new_pw  = st.text_input("New password", type="password")
            new_pw2 = st.text_input("Confirm new password", type="password")
            submitted = st.form_submit_button("Set Password")
        if submitted:
            if new_pw != new_pw2:
                st.error("Passwords do not match.")
                return
            try:
                resp = _set_new_password(
                    st.session_state["auth_email"],
                    new_pw,
                    st.session_state["auth_session"],
                )
                st.session_state["token"] = resp["AuthenticationResult"]["IdToken"]
                del st.session_state["auth_session"]
                del st.session_state["auth_email"]
                st.rerun()
            except ClientError as e:
                st.error(f"Failed: {e.response['Error']['Message']}")
        return

    # Normal login form
    st.subheader("Login")
    with st.form("login_form"):
        email    = st.text_input("Email")
        password = st.text_input("Password", type="password")
        submitted = st.form_submit_button("Login", use_container_width=True)

    if submitted:
        if not email or not password:
            st.error("Email and password are required.")
            return
        try:
            resp = _login(email, password)
            if resp.get("ChallengeName") == "NEW_PASSWORD_REQUIRED":
                st.session_state["auth_session"] = resp["Session"]
                st.session_state["auth_email"]   = email
                st.rerun()
            else:
                st.session_state["token"] = resp["AuthenticationResult"]["IdToken"]
                st.rerun()
        except ClientError as e:
            st.error(f"Login failed: {e.response['Error']['Message']}")


# ── My Topics page ────────────────────────────────────────────────────────────

def _my_topics_page():
    st.subheader("My Topics")

    team_filter = st.selectbox("Filter by Team", TEAMS, key="topics_team_filter")

    with st.spinner("Fetching topics…"):
        try:
            resp = requests.get(
                f"{API_URL}/topics",
                params={"team": team_filter},
                headers={"Authorization": f"Bearer {st.session_state['token']}"},
                timeout=15,
            )
        except requests.exceptions.ConnectionError:
            st.error("Cannot reach the API.")
            return

    try:
        body = resp.json()
    except Exception:
        st.error(f"Unexpected response: {resp.text}")
        return

    if resp.status_code == 401:
        st.warning("Session expired. Please login again.")
        del st.session_state["token"]
        st.rerun()
        return
    if resp.status_code != 200:
        st.error(f"Error {resp.status_code}: {body.get('detail', resp.text)}")
        return

    topics = body.get("topics", [])
    team   = body.get("team", "")

    if not topics:
        st.info(f"No topics found for team **{team}** yet. Request one in the 'Request Topic' tab.")
        return

    for t in topics:
        status_icon = "✅" if t["ready"] else "⏳"
        status_text = "READY" if t["ready"] else "Pending (ArgoCD sync needed)"
        with st.expander(f"{status_icon} {t['topic_name']}  —  {status_text}"):
            col1, col2 = st.columns(2)
            with col1:
                st.markdown("**Topic Details**")
                st.write(f"- **Partitions:** {t['partitions']}")
                st.write(f"- **Retention:** {t['retention']}")
                st.write(f"- **Requested by:** {t['requested_by']}")
            with col2:
                st.markdown("**Connection Details**")
                st.write(f"- **Username:** `{t['username']}`")
                if t["password"]:
                    st.write(f"- **Password:** `{t['password']}`")
                else:
                    st.write("- **Password:** *(not ready yet)*")

            st.markdown("**Bootstrap Servers**")
            st.code(f"Internal (within cluster): {t['bootstrap_internal']}\nExternal (from internet):  {t['bootstrap_external']}", language="bash")


# ── Main portal page ──────────────────────────────────────────────────────────

def _portal_page():
    col_title, col_logout = st.columns([4, 1])
    with col_title:
        st.title("Kafka Self-Service Portal")
    with col_logout:
        if st.button("Logout"):
            del st.session_state["token"]
            st.rerun()

    st.markdown("---")
    tab1, tab2 = st.tabs(["Request Topic", "My Topics"])

    with tab2:
        _my_topics_page()

    with tab1:
        st.subheader("Request a New Kafka Topic")

        with st.form("topic_request", clear_on_submit=False):
            col1, col2 = st.columns(2)

            with col1:
                team = st.selectbox("Your Team", TEAMS)
                entity = st.text_input(
                    "Entity",
                    placeholder="transaction, order, user, payment …",
                    help="The business entity this topic is about",
                )
                event_type = st.selectbox("Event Type", ALLOWED_EVENT_TYPES)

            with col2:
                partitions = st.number_input("Partitions", min_value=1, max_value=30, value=3)
                retention_hours = st.number_input(
                    "Retention (hours)", min_value=1, max_value=720, value=48,
                    help="How long messages are kept. Max 720h (30 days) in sandbox.",
                )
                consumer_teams = st.multiselect(
                    "Consumer Teams",
                    TEAMS,
                    help="Which teams will consume from this topic",
                )

            description = st.text_area(
                "Description",
                placeholder="Describe what events this topic will carry and who will use them.",
            )

            submitted = st.form_submit_button("Submit Topic Request", use_container_width=True)

        if entity:
            topic_name = f"{team}.{entity.strip().lower().replace(' ', '-')}.{event_type}"
            st.info(f"Topic name will be: `{topic_name}`")

        if submitted:
            if not entity or not description:
                st.error("Entity and Description are required.")
                st.stop()

            payload = {
                "team":            team,
                "entity":          entity.strip().lower().replace(" ", "-"),
                "event_type":      event_type,
                "partitions":      int(partitions),
                "retention_hours": int(retention_hours),
                "description":     description,
                "consumer_teams":  consumer_teams,
            }

            with st.spinner("Generating YAML and creating GitHub PR …"):
                try:
                    resp = requests.post(
                        f"{API_URL}/request-topic",
                        json=payload,
                        headers={"Authorization": f"Bearer {st.session_state['token']}"},
                        timeout=60,
                    )
                except requests.exceptions.ConnectionError:
                    st.error("Cannot reach the API. Is the kafka-portal-api service running?")
                    st.stop()

            try:
                body = resp.json()
            except Exception:
                body = {"detail": resp.text or "No response body"}

            if resp.status_code == 200:
                st.success("Topic request submitted!")
                st.markdown(f"**PR:** [{body['pr_url']}]({body['pr_url']})")
                st.caption("The PR will be auto-merged after YAML validation. ArgoCD will apply it within ~30 seconds.")
                with st.expander("KafkaTopic YAML"):
                    st.code(body["topic_yaml"], language="yaml")
                with st.expander("KafkaUser YAML"):
                    st.code(body["user_yaml"], language="yaml")
            elif resp.status_code == 400:
                st.error(f"Validation failed: {body.get('detail')}")
            elif resp.status_code == 401:
                st.warning("Session expired. Please login again.")
                del st.session_state["token"]
                st.rerun()
            else:
                st.error(f"Error {resp.status_code}: {body.get('detail', resp.text)}")


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    st.set_page_config(
        page_title="Kafka Self-Service Portal",
        page_icon="📨",
        layout="centered",
    )
    if "token" not in st.session_state:
        _login_page()
    else:
        _portal_page()


if __name__ == "__main__":
    main()
