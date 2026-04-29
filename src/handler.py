import base64
import hashlib
import hmac
import json
import logging
import os
import urllib.error
import urllib.request
from http import HTTPStatus

from adf import markdown_to_adf

logger = logging.getLogger()
logger.setLevel(logging.INFO)

JIRA_BASE_URL = os.environ["JIRA_BASE_URL"].rstrip("/")
JIRA_USER_EMAIL = os.environ["JIRA_USER_EMAIL"]
JIRA_API_TOKEN = os.environ["JIRA_API_TOKEN"]
WEBHOOK_SECRET = os.environ.get("WEBHOOK_SECRET", "")

# In Lambda the zip root contains both handler.py and definitions/.
# For local dev, set DEFINITIONS_DIR to the absolute path of the definitions folder.
DEFINITIONS_DIR = os.environ.get(
    "DEFINITIONS_DIR",
    os.path.join(os.path.dirname(__file__), "definitions"),
)


def _auth_header() -> str:
    credentials = f"{JIRA_USER_EMAIL}:{JIRA_API_TOKEN}"
    return "Basic " + base64.b64encode(credentials.encode()).decode()


def _verify_signature(event: dict) -> bool:
    """Return True if the request HMAC-SHA256 signature is valid (or no secret is configured)."""
    if not WEBHOOK_SECRET:
        logger.warning("WEBHOOK_SECRET is not set — skipping signature verification")
        return True

    sig_header = (event.get("headers") or {}).get("x-hub-signature", "")
    if not sig_header.startswith("sha256="):
        logger.warning("Missing or malformed x-hub-signature header")
        return False

    raw_body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        body_bytes = base64.b64decode(raw_body)
    else:
        body_bytes = raw_body.encode()

    expected = hmac.new(WEBHOOK_SECRET.encode(), body_bytes, hashlib.sha256).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", sig_header)


def _project_dir(project_key: str) -> str:
    project_dir = os.path.normpath(os.path.join(DEFINITIONS_DIR, project_key))
    # Guard against path traversal via a malicious project key
    if not project_dir.startswith(os.path.normpath(DEFINITIONS_DIR) + os.sep):
        raise ValueError(f"Invalid project key: {project_key}")
    return project_dir


def _load_definition(project_key: str) -> str:
    filepath = os.path.join(_project_dir(project_key), "definition-of-done.md")
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()

def _update_dod_field(issue_key: str, field_id: str, content: str) -> None:
    url = f"{JIRA_BASE_URL}/rest/api/3/issue/{issue_key}"
    payload = json.dumps({"fields": {field_id: markdown_to_adf(content)}}).encode()
    req = urllib.request.Request(
        url,
        data=payload,
        method="PUT",
        headers={
            "Authorization": _auth_header(),
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req) as resp:
        logger.info("Updated %s — HTTP %s", issue_key, resp.status)


def handler(event, context):
    if not _verify_signature(event):
        return {
            "statusCode": HTTPStatus.UNAUTHORIZED,
            "body": json.dumps({"error": "Invalid signature"}),
        }

    try:
        body = json.loads(event.get("body") or "{}")
        logger.info("Received body: %s", event.get("body"))

        issue_key = body["issue"]["key"]
        project_key = body["issue"]["fields"]["project"]["key"]

        logger.info("New issue %s in project %s — populating Definition of Done", issue_key, project_key)

        dod_field_id = "customfield_10141"  # Field ID for the "Definition of Done" custom field in Jira (hardcoded)
        try:
            dod_content = _load_definition(project_key)
        except FileNotFoundError:
            logger.warning(
                "Definition of Done file not found for project %s — skipping %s",
                project_key,
                issue_key,
            )
            return {
                "statusCode": HTTPStatus.OK,
                "body": json.dumps({
                    "message": f"Definition of Done file not found for {issue_key}"
                }),
            }
        _update_dod_field(issue_key, dod_field_id, dod_content)

        return {
            "statusCode": HTTPStatus.OK,
            "body": json.dumps({"message": f"Definition of Done set on {issue_key}"}),
        }

    except ValueError as exc:
        logger.warning("Config/mapping error: %s", exc)
        return {
            "statusCode": HTTPStatus.BAD_REQUEST,
            "body": json.dumps({"error": str(exc)}),
        }

    except urllib.error.HTTPError as exc:
        error_body = exc.read().decode(errors="replace")
        logger.error("Jira API error: %s %s — %s", exc.code, exc.reason, error_body)
        return {
            "statusCode": HTTPStatus.INTERNAL_SERVER_ERROR,
            "body": json.dumps({"error": "Failed to update Jira issue"}),
        }

    except KeyError as exc:
        logger.error("Unexpected webhook payload shape — missing key: %s", exc)
        return {
            "statusCode": HTTPStatus.BAD_REQUEST,
            "body": json.dumps({"error": f"Invalid webhook payload: missing key {exc}"}),
        }
