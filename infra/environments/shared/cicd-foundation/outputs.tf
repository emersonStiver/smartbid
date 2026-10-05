# Read by cicd-builds, cicd-pipeline and cicd-notifications through terraform_remote_state

output "region" {
  value = local.region
}

output "registry" {
  description = "ECR registry host of the shared account"
  value       = local.registry
}

output "connection_arn" {
  value = aws_codeconnections_connection.github.arn
}

output "connection_status" {
  description = "Must be AVAILABLE before applying cicd-builds and cicd-pipeline"
  value       = aws_codeconnections_connection.github.connection_status
}

output "artifacts_kms_key_arn" {
  value = aws_kms_key.artifacts.arn
}

output "signing_key_arn" {
  value = aws_kms_key.signing.arn
}

output "signing_key_alias" {
  value = aws_kms_alias.signing.name
}

output "artifacts_bucket_name" {
  value = module.artifacts_bucket.bucket_name
}

output "reports_bucket_name" {
  value = module.reports_bucket.bucket_name
}

output "app_repository_urls" {
  value = { for k, r in aws_ecr_repository.app : k => r.repository_url }
}

output "app_repository_names" {
  value = { for k, r in aws_ecr_repository.app : k => r.name }
}

output "tools_repository_url" {
  value = aws_ecr_repository.ci_tools.repository_url
}

output "build_cache_repository_url" {
  value = aws_ecr_repository.build_cache.repository_url
}

output "codebuild_role_arns" {
  value = { for k, r in aws_iam_role.codebuild : k => r.arn }
}

output "codepipeline_role_arn" {
  value = aws_iam_role.codepipeline.arn
}

output "permissions_boundary_arn" {
  value = aws_iam_policy.boundary.arn
}

output "deploy_role_arns" {
  value = local.deploy_role_arns
}
