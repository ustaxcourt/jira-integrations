output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "aws_region" {
  value = var.aws_region
}
