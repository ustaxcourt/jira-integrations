output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "aws_region" {
  value = var.aws_region
}

output "bootstrap_github_actions_role_arn" {
  description = "Set this as the BOOTSTRAP_ROLE_ARN variable in your GitHub repository settings"
  value       = aws_iam_role.bootstrap_github_actions.arn
}
