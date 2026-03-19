variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the S3 bucket that stores Terraform state"
  type        = string
  default    = "ustc-jira-integrations-terraform-state"
}
