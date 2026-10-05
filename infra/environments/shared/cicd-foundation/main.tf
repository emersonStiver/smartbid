# shared/cicd-foundation — long-lived CI/CD resources the other cicd-* stacks depend on:
# KMS keys, S3 buckets, ECR, CodeConnections, secrets, SSM parameters and IAM roles.
# Resources are split by service: kms.tf, s3.tf, ecr.tf, codeartifact.tf, connection.tf,
# secrets.tf, ssm.tf, iam.tf. Critical resources use prevent_destroy (the plan's "termination protection").

data "aws_region" "current" {}

locals {
  region = data.aws_region.current.region

  artifacts_bucket_name = "${var.project}-artifacts-${var.account_id}-${local.region}"
  reports_bucket_name   = "${var.project}-reports-${var.account_id}-${local.region}"
  artifacts_bucket_arn  = "arn:aws:s3:::${local.artifacts_bucket_name}"
  reports_bucket_arn    = "arn:aws:s3:::${local.reports_bucket_name}"

  registry = "${var.account_id}.dkr.ecr.${local.region}.amazonaws.com"

  # Naming conventions shared with the cicd-builds stack and the workload accounts
  codebuild_project_arns = "arn:aws:codebuild:${local.region}:${var.account_id}:project/${var.project}-*"
  report_group_arns      = "arn:aws:codebuild:${local.region}:${var.account_id}:report-group/${var.project}-*"
  codebuild_log_arns     = "arn:aws:logs:${local.region}:${var.account_id}:log-group:/aws/codebuild/${var.project}-*"

  deploy_role_arns     = { for env, t in var.deploy_targets : env => "arn:aws:iam::${t.account_id}:role/${var.project}-${env}-deploy-role" }
  deploy_account_roots = distinct([for t in var.deploy_targets : "arn:aws:iam::${t.account_id}:root"])

  pull_through_prefixes = concat(["ecr-public"], var.enable_docker_hub_pull_through ? ["docker-hub"] : [])
}
