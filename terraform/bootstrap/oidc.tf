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

# ── Permissions needed to apply the bootstrap ─────────────────────────────────

data "aws_iam_policy_document" "bootstrap_permissions" {
  # Manage the Terraform state bucket
  statement {
    sid    = "StateBucketManage"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging",
    ]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]
  }

  # Manage the GitHub OIDC provider
  statement {
    sid    = "OIDCProviderManage"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider",
    ]
    resources = [local.oidc_provider_arn]
  }

  # Manage this role (and any other bootstrap IAM roles)
  statement {
    sid    = "BootstrapRoleManage"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListAttachedRolePolicies",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/jira-integrations-bootstrap-*"]
  }
}

resource "aws_iam_role_policy" "bootstrap_github_actions" {
  name   = "bootstrap-permissions"
  role   = aws_iam_role.bootstrap_github_actions.id
  policy = data.aws_iam_policy_document.bootstrap_permissions.json
}
