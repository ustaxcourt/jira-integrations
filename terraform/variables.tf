variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "jira_base_url" {
  description = "Jira Cloud base URL, e.g. https://acme.atlassian.net"
  type        = string
  sensitive   = true
}

variable "jira_user_email" {
  description = "Email address used for Jira API Basic auth"
  type        = string
  sensitive   = true
}

variable "jira_api_token" {
  description = "Jira API token — do not commit this value; supply via TF_VAR_jira_api_token or a tfvars file excluded from source control"
  type        = string
  sensitive   = true
}
