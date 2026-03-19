#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$REPO_ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env file not found at $ENV_FILE"
  echo "Copy .env.example to .env and fill in your values."
  exit 1
fi

# Load .env — skip blank lines and comments
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  export "$line"
done < "$ENV_FILE"

: "${JIRA_BASE_URL:?JIRA_BASE_URL is not set in .env}"
: "${JIRA_USER_EMAIL:?JIRA_USER_EMAIL is not set in .env}"
: "${JIRA_API_TOKEN:?JIRA_API_TOKEN is not set in .env}"

"$REPO_ROOT/build.sh"

cd "$REPO_ROOT/terraform"

TF_VAR_jira_api_token="$JIRA_API_TOKEN" TF_VAR_jira_user_email="$JIRA_USER_EMAIL" terraform apply \
  -var="jira_base_url=$JIRA_BASE_URL"
