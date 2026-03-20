data "aws_caller_identity" "current" {}

# ── GitHub OIDC provider ───────────────────────────────────────────────────────
# Set create_oidc_provider = false if one already exists in this AWS account.

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

# ── IAM role assumed by the bootstrap workflow ─────────────────────────────────

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Scoped to merges/pushes on main only
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "bootstrap_github_actions" {
  name               = "jira-integrations-bootstrap-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# ── Permissions needed to deploy terraform/*.tf ───────────────────────────────

data "aws_iam_policy_document" "bootstrap_permissions" {
  # Read/write Terraform state and S3 native lock file
  statement {
    sid    = "TerraformStateReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*",
    ]
  }

  # Lambda function
  statement {
    sid    = "LambdaManage"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:GetFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListVersionsByFunction",
      "lambda:GetFunctionCodeSigningConfig",
    ]
    resources = ["arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:jira-dod-webhook"]
  }

  # API Gateway HTTP API
  statement {
    sid    = "APIGatewayManage"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE",
      "apigateway:TagResource",
    ]
    resources = ["arn:aws:apigateway:*::*"]
  }

  # IAM — Lambda execution role only
  statement {
    sid    = "LambdaRoleManage"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/jira-dod-webhook-role"]
  }
}

resource "aws_iam_role_policy" "bootstrap_github_actions" {
  name   = "bootstrap-permissions"
  role   = aws_iam_role.bootstrap_github_actions.id
  policy = data.aws_iam_policy_document.bootstrap_permissions.json
}
