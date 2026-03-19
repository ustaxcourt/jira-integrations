# Terraform — Jira DoD Webhook

This workspace deploys the Jira Definition of Done webhook into AWS. It is backed by remote state in S3 (provisioned by `terraform/bootstrap/`).

## Architecture

```
Jira (issue_created webhook)
        │  POST /webhook
        ▼
API Gateway HTTP API
        │
        ▼
AWS Lambda (Python 3.12)
        │  PUT /rest/api/3/issue/{key}
        ▼
Jira Cloud REST API
```

**Resources managed:**

| Resource                                          | Description                                                     |
| ------------------------------------------------- | --------------------------------------------------------------- |
| `aws_lambda_function`                             | Webhook handler — reads DoD markdown and updates the Jira field |
| `aws_apigatewayv2_api/integration/route/stage`    | HTTP API exposing `POST /webhook` to Jira                       |
| `aws_iam_role` + `aws_iam_role_policy_attachment` | Least-privilege execution role for the Lambda                   |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10
- AWS credentials configured
- Remote state backend provisioned — see [`bootstrap/README.md`](bootstrap/README.md)
- `dist/lambda.zip` built — run `./build.sh` from the repo root

## First-time Setup

1. **Build the bootstrap** (once per account — skip if already done):

   ```bash
   cd terraform/bootstrap
   terraform init
   terraform apply
   ```

2. **Create `backend.hcl`** from the provided example, filling in the bootstrap outputs:

   ```bash
   cp terraform/backend.hcl.example terraform/backend.hcl
   # edit terraform/backend.hcl
   ```

3. **Build the Lambda package:**

   ```bash
   ./build.sh
   ```

4. **Initialise with the remote backend:**

   ```bash
   cd terraform
   terraform init -backend-config=backend.hcl
   ```

## Deploy

```bash
cd terraform

TF_VAR_jira_api_token=<your-token> terraform apply \
  -var="jira_base_url=https://acme.atlassian.net" \
  -var="jira_user_email=bot@acme.com"
```

Configure this URL in Jira under **Settings → System → Webhooks → Create webhook**, selecting the **Issue → created** event.

## Variables

| Name              | Default                 | Description                                                              |
| ----------------- | ----------------------- | ------------------------------------------------------------------------ |
| `aws_region`      | `us-east-1`             | AWS region                                                               |
| `jira_base_url`   | _(required)_            | Jira Cloud base URL, e.g. `https://acme.atlassian.net`                   |
| `jira_user_email` | _(required)_            | Email for Jira API Basic auth                                            |
| `jira_api_token`  | _(required, sensitive)_ | Jira API token — supply via `TF_VAR_jira_api_token` or a `*.tfvars` file |

> `*.tfvars` files and `backend.hcl` are excluded from source control via `.gitignore`. Never commit credentials.

## Subsequent Deployments

```bash
./build.sh          # rebuild the zip whenever source changes
cd terraform
terraform apply     # backend config is cached after the first init
```
