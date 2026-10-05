# Outputs consumed by later layers
output "state_bucket_name" {
  value = module.state_backend.bucket_name
}

output "state_bucket_id" {
  value = module.state_backend.bucket_id
}

output "state_bucket_arn" {
  value = module.state_backend.bucket_arn
}

output "deploy_role_arn" {
  description = "Must match /smartbid/cicd/dev/deploy-role-arn written by shared/cicd-foundation"
  value       = aws_iam_role.deploy.arn
}