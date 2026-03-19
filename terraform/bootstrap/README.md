# Terraform Bootstrap

This workspace is a **one-time setup** that provisions the remote state backend used by the main Terraform workspace. It creates:

- An **S3 bucket** to store Terraform state (versioned, KMS-encrypted, public access blocked)

State locking uses S3's native locking (`use_lockfile = true`), introduced in Terraform 1.10. No DynamoDB table is required.

> **Run this once per AWS account/region.** After the backend exists, all ongoing infrastructure changes are managed from `terraform/`.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10
- AWS credentials configured (e.g. `aws configure`, SSO, or environment variables)

## Usage

```bash
cd terraform/bootstrap

terraform init

terraform apply -var="state_bucket_name=ustc-jira-integrations-terraform-state"
```

## Notes

- The S3 bucket has `prevent_destroy = true`. To tear it down you must first remove that lifecycle rule.
- The bootstrap's own state is stored **locally** (`terraform.tfstate` in this directory). This is the expected pattern — bootstrapping a remote backend is a chicken-and-egg problem. Keep this state file safe or commit it if your team requires it.
