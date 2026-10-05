# shared/cicd-builds — CodeBuild projects, report groups, webhooks and the weekly tools-image rebuild.
# Requires: cicd-foundation applied AND the GitHub connection AVAILABLE (webhooks are created through it).

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "emer-tfstate-${var.environment}-${var.account_id}"
    key    = "cicd-foundation/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  f = data.terraform_remote_state.foundation.outputs

  repo_url    = "https://github.com/${var.github_repository}.git"
  tools_image = "${local.f.tools_repository_url}:latest"

  # Base images are pulled through the shared account's ECR pull-through cache
  base_registry = "${local.f.registry}/ecr-public/docker/library"

  common_env = {
    REGISTRY      = local.f.registry
    BASE_REGISTRY = local.base_registry
  }
}

# ---------------------------------------------------------------------------------------------
# Webhook-triggered projects (source: GitHub through the CodeConnections connection)
# ---------------------------------------------------------------------------------------------

# Builds the CI tools image on the AWS curated image (the tools image can't build itself the first time)
module "ci_image_build" {
  source                      = "../../../modules/codebuild-project"
  name                        = "${var.project}-ci-image-build"
  description                 = "Builds and pushes the ${var.project}-ci/tools image"
  service_role_arn            = local.f.codebuild_role_arns["ci-image"]
  kms_key_arn                 = local.f.artifacts_kms_key_arn
  image                       = "aws/codebuild/standard:7.0"
  image_pull_credentials_type = "CODEBUILD"
  compute_type                = "BUILD_GENERAL1_MEDIUM"
  privileged_mode             = true
  buildspec                   = "ci/images/buildspec.yml"
  source_type                 = "GITHUB"
  source_location             = local.repo_url
  connection_arn              = local.f.connection_arn
  log_retention_days          = var.log_retention_days
  environment_variables = merge(local.common_env, {
    TOOLS_REPOSITORY_URI = local.f.tools_repository_url
  })
}

module "pr_check" {
  source               = "../../../modules/codebuild-project"
  name                 = "${var.project}-pr-check"
  description          = "Validates pull requests before merge and reports the result to GitHub"
  service_role_arn     = local.f.codebuild_role_arns["pr-check"]
  kms_key_arn          = local.f.artifacts_kms_key_arn
  image                = local.tools_image
  buildspec            = "buildspecs/pr-check.yml"
  source_type          = "GITHUB"
  source_location      = local.repo_url
  connection_arn       = local.f.connection_arn
  git_clone_depth      = 0 # full history: the buildspec diffs the PR against the base branch
  report_build_status  = true
  build_status_context = "${var.project}/pr-check" # the required status check name on GitHub
  log_retention_days   = var.log_retention_days
}

# ---------------------------------------------------------------------------------------------
# Pipeline-driven projects (source: CODEPIPELINE artifacts)
# ---------------------------------------------------------------------------------------------
module "build_test" {
  source             = "../../../modules/codebuild-project"
  name               = "${var.project}-build-test"
  description        = "Validate stage: compile, unit tests and coverage"
  service_role_arn   = local.f.codebuild_role_arns["build-test"]
  kms_key_arn        = local.f.artifacts_kms_key_arn
  image              = local.tools_image
  compute_type       = "BUILD_GENERAL1_MEDIUM"
  buildspec          = "buildspecs/build-test.yml"
  source_type        = "CODEPIPELINE"
  log_retention_days = var.log_retention_days
}

module "security_scan" {
  source             = "../../../modules/codebuild-project"
  name               = "${var.project}-security-scan"
  description        = "Validate stage: secrets, SAST, dependency and IaC scans"
  service_role_arn   = local.f.codebuild_role_arns["security-scan"]
  kms_key_arn        = local.f.artifacts_kms_key_arn
  image              = local.tools_image
  compute_type       = "BUILD_GENERAL1_MEDIUM"
  buildspec          = "buildspecs/security-scan.yml"
  source_type        = "CODEPIPELINE"
  log_retention_days = var.log_retention_days
  environment_variables = {
    REPORTS_BUCKET = local.f.reports_bucket_name
  }
}

module "integration_test" {
  source                = "../../../modules/codebuild-project"
  name                  = "${var.project}-integration-test"
  description           = "IntegrationTest stage: docker compose up the service and its dependencies, run tests"
  service_role_arn      = local.f.codebuild_role_arns["integration-test"]
  kms_key_arn           = local.f.artifacts_kms_key_arn
  image                 = local.tools_image
  compute_type          = "BUILD_GENERAL1_MEDIUM"
  privileged_mode       = true
  buildspec             = "buildspecs/integration-test.yml"
  source_type           = "CODEPIPELINE"
  log_retention_days    = var.log_retention_days
  environment_variables = local.common_env
}

module "package_publish" {
  source                = "../../../modules/codebuild-project"
  name                  = "${var.project}-package-publish"
  description           = "Package stage: docker build, scan, push, SBOM, sign"
  service_role_arn      = local.f.codebuild_role_arns["package-publish"]
  kms_key_arn           = local.f.artifacts_kms_key_arn
  image                 = local.tools_image
  compute_type          = "BUILD_GENERAL1_MEDIUM"
  privileged_mode       = true
  build_timeout_minutes = 45
  buildspec             = "buildspecs/package-publish.yml"
  source_type           = "CODEPIPELINE"
  log_retention_days    = var.log_retention_days
  environment_variables = merge(local.common_env, {
    APP_NAME                   = var.app_service
    CONTAINER_NAME             = var.app_service
    APP_REPOSITORY_URI         = local.f.app_repository_urls[var.app_service]
    APP_REPOSITORY_NAME        = local.f.app_repository_names[var.app_service]
    BUILD_CACHE_REPOSITORY_URI = local.f.build_cache_repository_url
    REPORTS_BUCKET             = local.f.reports_bucket_name
    SIGNING_KEY_ARN            = local.f.signing_key_arn
    SOURCE_URL                 = "https://github.com/${var.github_repository}"
  })
}

# ---------------------------------------------------------------------------------------------
# Report groups. Names follow CodeBuild's convention <project-name>-<report-key-in-buildspec>,
# so buildspecs reference them by short key (e.g. "unit-tests") without hard-coded ARNs.
# ---------------------------------------------------------------------------------------------
locals {
  report_groups = {
    "${var.project}-build-test-unit-tests"              = "TEST"
    "${var.project}-build-test-coverage"                = "CODE_COVERAGE"
    "${var.project}-integration-test-integration-tests" = "TEST"
    "${var.project}-security-scan-security-findings"    = "TEST"
    "${var.project}-package-publish-image-findings"     = "TEST"
  }
}

resource "aws_codebuild_report_group" "this" {
  for_each       = local.report_groups
  name           = each.key
  type           = each.value
  delete_reports = true

  export_config {
    type = "S3"
    s3_destination {
      bucket         = local.f.reports_bucket_name
      encryption_key = local.f.artifacts_kms_key_arn
      packaging      = "NONE"
      path           = "codebuild-reports"
    }
  }
}

# ---------------------------------------------------------------------------------------------
# Webhooks (GitHub -> CodeBuild through the connection)
# ---------------------------------------------------------------------------------------------
resource "aws_codebuild_webhook" "pr_check" {
  project_name = module.pr_check.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED,PULL_REQUEST_UPDATED,PULL_REQUEST_REOPENED"
    }
    filter {
      type    = "BASE_REF"
      pattern = "^refs/heads/${var.main_branch}$"
    }
  }

  # PR code is untrusted: PRs from forks only build after a maintainer approves them with a comment
  pull_request_build_policy {
    requires_comment_approval = "FORK_PULL_REQUESTS"
    approver_roles            = ["GITHUB_MAINTAIN", "GITHUB_ADMIN"]
  }
}

resource "aws_codebuild_webhook" "ci_image" {
  project_name = module.ci_image_build.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/${var.main_branch}$"
    }
    filter {
      type    = "FILE_PATH"
      pattern = "^ci/images/"
    }
  }

  # This project never builds pull requests (the filter only accepts pushes to main). Without this, the
  # default PR approval policy posts a failing "Build not triggered: Pull request approval required" check on every PR.
  pull_request_build_policy {
    requires_comment_approval = "DISABLED"
  }
}

# ---------------------------------------------------------------------------------------------
# Weekly tools-image rebuild (picks up OS and tool security patches)
# ---------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "events_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

data "aws_iam_policy_document" "events_start_build" {
  statement {
    actions   = ["codebuild:StartBuild"]
    resources = [module.ci_image_build.arn]
  }
}

resource "aws_iam_role" "events" {
  name                 = "${var.project}-ci-image-schedule-role"
  assume_role_policy   = data.aws_iam_policy_document.events_trust.json
  permissions_boundary = local.f.permissions_boundary_arn
}

resource "aws_iam_role_policy" "events" {
  name   = "${var.project}-ci-image-schedule"
  role   = aws_iam_role.events.id
  policy = data.aws_iam_policy_document.events_start_build.json
}

resource "aws_cloudwatch_event_rule" "ci_image_weekly" {
  name                = "${var.project}-ci-image-weekly-rebuild"
  description         = "Rebuild the CI tools image every Monday 06:00 UTC"
  schedule_expression = "cron(0 6 ? * MON *)"
}

resource "aws_cloudwatch_event_target" "ci_image_weekly" {
  rule     = aws_cloudwatch_event_rule.ci_image_weekly.name
  arn      = module.ci_image_build.arn
  role_arn = aws_iam_role.events.arn
}

# Security group for integration tests: not needed (builds run outside a VPC). Add one here only if
# integration tests must reach private resources (RDS, ElastiCache) inside a VPC.
