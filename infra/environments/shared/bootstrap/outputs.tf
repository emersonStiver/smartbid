# Outputs consumed by later layers
output "s3_bucket_name" {
  value       = module.state-backend.bucket_name
  description = "The name of the S3 bucket for Terraform state"
}
output "s3_bucket_arn" {
  value       = module.state-backend.bucket_arn
  description = "The ARN of the S3 bucket for Terraform state"
}
output "s3_bucket_id" {
  value       = module.state-backend.bucket_id
  description = "The ID of the S3 bucket for Terraform state"
}