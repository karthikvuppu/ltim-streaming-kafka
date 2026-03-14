"""
Kafka Self-Service Portal — Streamlit UI
OAuth2 Authorization Code flow via Cognito hosted UI.
Sends topic requests to the FastAPI backend.
"""

import os
import base64
from urllib.parse import urlencode

import requests
import streamlit as st

# ── Config from env vars (injected by Helm) ──────────────────────────────────
COGNITO_DOMAIN  = os.environ.get("COGNITO_DOMAIN", "")        # e.g. ltim-sandbox-kafka-portal.auth.eu-north-1.amazoncognito.com
CLIENT_ID       = os.environ.get("COGNITO_CLIENT_ID", "")
CLIENT_SECRET   = os.environ.get("COGNITO_CLIENT_SECRET", "")
REDIRECT_URI    = os.environ.get("REDIRECT_URI", "http://localhost:8501")
API_URL         = os.environ.get("API_URL", "http://kafka-portal-api:8000")

ALLOWED_EVENT_TYPES = [
    "created", "updated", "deleted", "failed",
    "approved", "rejected", "submitted", "processed",
]
TEAMS = ["payments", "analytics", "engineering", "platform", "audit"]


# ── Auth helpers ──────────────────────────────────────────────────────────────

def _login_url() -> str:
    params = {
        "response_type": "code",
        "client_id":     CLIENT_ID,
        "redirect_uri":  REDIRECT_URI,
        "scope":         "email openid profile",
    }
    return f"https://{COGNITO_DOMAIN}/oauth2/authorize?{urlencode(params)}"


def _exchange_code(code: str) -> dict:
    creds = base64.b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    resp = requests.post(
        f"https://{COGNITO_DOMAIN}/oauth2/token",
        headers={
            "Content-Type":  "application/x-www-form-urlencoded",
            "Authorization": f"Basic {creds}",
        },
        data={
            "grant_type":   "authorization_code",
            "code":         code,
            "redirect_uri": REDIRECT_URI,
        },
        timeout=10,
    )
    return resp.json()


# ── Page ──────────────────────────────────────────────────────────────────────

def main():
    st.set_page_config(
        page_title="Kafka Self-Service Portal",
        page_icon="📨",
        layout="centered",
    )

    # ── Handle OAuth2 callback ────────────────────────────────────────────────
    params = st.query_params
    if "code" in params and "token" not in st.session_state:
        tokens = _exchange_code(params["code"])
        if "id_token" in tokens:
            st.session_state["token"] = tokens["id_token"]
            st.query_params.clear()
            st.rerun()
        else:
            st.error(f"Login failed: {tokens.get('error_description', tokens)}")
            return

    # ── Not logged in ─────────────────────────────────────────────────────────
    if "token" not in st.session_state:
        st.title("Kafka Self-Service Portal")
        st.markdown("Request new Kafka topics and users through a self-service workflow.")
        st.markdown("---")
        login_url = _login_url()
        st.markdown(
            f'<a href="{login_url}" target="_self">'
            f'<button style="padding:10px 24px;font-size:16px;cursor:pointer;">Login with Cognito</button>'
            f"</a>",
            unsafe_allow_html=True,
        )
        return

    # ── Logged in ─────────────────────────────────────────────────────────────
    col_title, col_logout = st.columns([4, 1])
    with col_title:
        st.title("Kafka Self-Service Portal")
    with col_logout:
        if st.button("Logout"):
            del st.session_state["token"]
            st.rerun()

    st.markdown("---")
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

    # ── Preview topic name ────────────────────────────────────────────────────
    if entity:
        topic_name = f"{team}.{entity.strip().lower().replace(' ', '-')}.{event_type}"
        st.info(f"Topic name will be: `{topic_name}`")

    # ── Handle submission ─────────────────────────────────────────────────────
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

        if resp.status_code == 200:
            result = resp.json()
            st.success("Topic request submitted!")
            st.markdown(f"**PR:** [{result['pr_url']}]({result['pr_url']})")
            st.caption("The PR will be auto-merged after YAML validation. ArgoCD will apply it within ~30 seconds.")

            with st.expander("KafkaTopic YAML"):
                st.code(result["topic_yaml"], language="yaml")
            with st.expander("KafkaUser YAML"):
                st.code(result["user_yaml"], language="yaml")

        elif resp.status_code == 400:
            st.error(f"Validation failed: {resp.json().get('detail')}")
        elif resp.status_code == 401:
            st.warning("Session expired. Please login again.")
            del st.session_state["token"]
            st.rerun()
        else:
            st.error(f"Error {resp.status_code}: {resp.json().get('detail', 'Unknown error')}")


if __name__ == "__main__":
    main()
