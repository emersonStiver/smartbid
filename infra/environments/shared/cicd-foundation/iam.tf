# =============================================================================================
# Permissions boundary: the maximum any CI/CD role can ever do, even if its own policy grows.
# Allows only the services CI/CD uses and denies anything that could escalate or destroy.
# =============================================================================================
data "aws_iam_policy_document" "boundary" {
  #checkov:skip=CKV_AWS_109:Permissions boundary: wildcards set the ceiling; each role policy grants the narrow actions
  #checkov:skip=CKV_AWS_111:Permissions boundary: wildcards set the ceiling; each role policy grants the narrow actions
  #checkov:skip=CKV_AWS_356:Permissions boundary: wildcards set the ceiling; each role policy grants the narrow actions
  #checkov:skip=CKV_AWS_108:Permissions boundary: data access is narrowed by each role policy
  #checkov:skip=CKV_AWS_107:Permissions boundary: credential exposure actions are narrowed by each role policy
  #checkov:skip=CKV_AWS_110:Permissions boundary: privilege escalation actions are explicitly denied below
  statement {
    sid    = "AllowCicdServices"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream", "logs:PutLogEvents",
      "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:GetBucketLocation", "s3:GetBucketVersioning", "s3:ListBucket", "s3:GetBucketAcl",
      "kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*", "kms:DescribeKey", "kms:Sign", "kms:GetPublicKey",
      "ecr:*",
      "codebuild:StartBuild", "codebuild:BatchGetBuilds", "codebuild:StopBuild",
      "codebuild:CreateReportGroup", "codebuild:CreateReport", "codebuild:UpdateReport", "codebuild:BatchPutTestCases", "codebuild:BatchPutCodeCoverages",
      "codeconnections:UseConnection", "codeconnections:GetConnection", "codeconnections:GetConnectionToken",
      "codestar-connections:UseConnection", "codestar-connections:GetConnection", "codestar-connections:GetConnectionToken",
      "codeartifact:GetAuthorizationToken", "codeartifact:GetRepositoryEndpoint", "codeartifact:ReadFromRepository",
      "secretsmanager:GetSecretValue",
      "ssm:GetParameter", "ssm:GetParameters",
      "sts:AssumeRole", "sts:GetCallerIdentity", "sts:GetServiceBearerToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyEscalationAndDestruction"
    effect = "Deny"
    actions = [
      "iam:*", "organizations:*", "account:*",
      "s3:DeleteBucket", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy",
      "ecr:DeleteRepository", "ecr:SetRepositoryPolicy", "ecr:DeleteRepositoryPolicy", "ecr:PutLifecyclePolicy",
      "kms:ScheduleKeyDeletion", "kms:DisableKey", "kms:PutKeyPolicy",
      "codeconnections:DeleteConnection", "codestar-connections:DeleteConnection",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "boundary" {
  name        = "${var.project}-cicd-boundary"
  description = "Permissions boundary for all ${var.project} CI/CD roles"
  policy      = data.aws_iam_policy_document.boundary.json
}

# =============================================================================================
# Trust policies
# =============================================================================================
data "aws_iam_policy_document" "codebuild_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

data "aws_iam_policy_document" "codepipeline_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

# =============================================================================================
# Permission building blocks (combined per role below). Sids must be unique across blocks.
# =============================================================================================
data "aws_iam_policy_document" "build_logs" {
  statement {
    sid       = "WriteBuildLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${local.codebuild_log_arns}:*"]
  }
}

data "aws_iam_policy_document" "artifacts_key_use" {
  statement {
    sid       = "UseArtifactsKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*", "kms:DescribeKey"]
    resources = [aws_kms_key.artifacts.arn]
  }
}

data "aws_iam_policy_document" "ecr_login" {
  #checkov:skip=CKV_AWS_356:ecr:GetAuthorizationToken does not support resource-level permissions
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "pull_tools_image" {
  statement {
    sid       = "PullToolsImage"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = [aws_ecr_repository.ci_tools.arn]
  }
}

data "aws_iam_policy_document" "push_tools_image" {
  statement {
    sid = "PushToolsImage"
    actions = [
      "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.ci_tools.arn]
  }
}

data "aws_iam_policy_document" "pull_through_cache" {
  statement {
    sid = "PullBaseImagesThroughCache"
    actions = [
      "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability",
      "ecr:BatchImportUpstreamImage", "ecr:CreateRepository",
    ]
    resources = [for p in local.pull_through_prefixes : "arn:aws:ecr:${local.region}:${var.account_id}:repository/${p}/*"]
  }
}

data "aws_iam_policy_document" "push_app_images" {
  statement {
    sid = "PushAppImages"
    actions = [
      "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability", "ecr:DescribeImages",
      "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
    ]
    resources = [for r in aws_ecr_repository.app : r.arn]
  }
}

data "aws_iam_policy_document" "build_cache_write" {
  statement {
    sid = "WriteBuildCache"
    actions = [
      "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
    ]
    resources = [aws_ecr_repository.build_cache.arn]
  }
}

# Input/output artifacts of pipeline-driven CodeBuild actions
data "aws_iam_policy_document" "pipeline_artifacts_rw" {
  statement {
    sid       = "PipelineArtifactsObjects"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
    resources = ["${local.artifacts_bucket_arn}/*"]
  }
  statement {
    sid       = "PipelineArtifactsBucket"
    actions   = ["s3:GetBucketLocation", "s3:GetBucketAcl", "s3:GetBucketVersioning", "s3:ListBucket"]
    resources = [local.artifacts_bucket_arn]
  }
}

data "aws_iam_policy_document" "test_reports" {
  statement {
    sid = "WriteTestReports"
    # CodeBuild calls CreateReportGroup on every report upload, even when the group already exists
    actions   = ["codebuild:CreateReportGroup", "codebuild:CreateReport", "codebuild:UpdateReport", "codebuild:BatchPutTestCases", "codebuild:BatchPutCodeCoverages"]
    resources = [local.report_group_arns]
  }
}

data "aws_iam_policy_document" "reports_bucket_write" {
  statement {
    sid       = "WriteReportsBucket"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${local.reports_bucket_arn}/*"]
  }
  statement {
    sid       = "LocateReportsBucket"
    actions   = ["s3:GetBucketLocation", "s3:GetBucketAcl"]
    resources = [local.reports_bucket_arn]
  }
}

data "aws_iam_policy_document" "use_github_connection" {
  statement {
    sid = "UseGitHubConnection"
    actions = [
      "codeconnections:UseConnection", "codeconnections:GetConnection", "codeconnections:GetConnectionToken",
      "codestar-connections:UseConnection", "codestar-connections:GetConnection", "codestar-connections:GetConnectionToken",
    ]
    resources = [aws_codeconnections_connection.github.arn]
  }
}

data "aws_iam_policy_document" "image_signing" {
  statement {
    sid       = "SignImages"
    actions   = ["kms:Sign", "kms:GetPublicKey", "kms:DescribeKey"]
    resources = [aws_kms_key.signing.arn]
  }
}

data "aws_iam_policy_document" "scanner_tokens" {
  statement {
    sid       = "ReadScannerTokens"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${local.region}:${var.account_id}:secret:${var.project}/ci/scanner-tokens-*"]
  }
}

data "aws_iam_policy_document" "codeartifact_read" {
  statement {
    sid       = "CodeArtifactToken"
    actions   = ["codeartifact:GetAuthorizationToken"]
    resources = ["arn:aws:codeartifact:${local.region}:${var.account_id}:domain/${var.project}"]
  }
  statement {
    sid       = "CodeArtifactRead"
    actions   = ["codeartifact:GetRepositoryEndpoint", "codeartifact:ReadFromRepository"]
    resources = ["arn:aws:codeartifact:${local.region}:${var.account_id}:repository/${var.project}/*"]
  }
  statement {
    sid       = "CodeArtifactBearerToken"
    actions   = ["sts:GetServiceBearerToken"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "sts:AWSServiceName"
      values   = ["codeartifact.amazonaws.com"]
    }
  }
}

# =============================================================================================
# CodeBuild roles: <project>-codebuild-<name>-role
# =============================================================================================
locals {

  codeartifact_blocks = var.enable_codeartifact ? [data.aws_iam_policy_document.codeartifact_read.json] : []

  codebuild_role_policies = {
    # Builds and pushes the CI tools image (webhook on ci/images/** + weekly schedule)
    "ci-image" = [
      data.aws_iam_policy_document.build_logs.json, data.aws_iam_policy_document.artifacts_key_use.json, data.aws_iam_policy_document.ecr_login.json,
      data.aws_iam_policy_document.pull_through_cache.json, data.aws_iam_policy_document.push_tools_image.json, data.aws_iam_policy_document.use_github_connection.json,
    ]
    # Pull request checks: read-only on AWS, only reports and the tools image
    "pr-check" = [
      data.aws_iam_policy_document.build_logs.json, data.aws_iam_policy_document.artifacts_key_use.json, data.aws_iam_policy_document.ecr_login.json,
      data.aws_iam_policy_document.pull_tools_image.json, data.aws_iam_policy_document.test_reports.json, data.aws_iam_policy_document.use_github_connection.json,
    ]
    "build-test" = concat([
      data.aws_iam_policy_document.build_logs.json, data.aws_iam_policy_document.artifacts_key_use.json, data.aws_iam_policy_document.ecr_login.json,
      data.aws_iam_policy_document.pull_tools_image.json, data.aws_iam_policy_document.pipeline_artifacts_rw.json, data.aws_iam_policy_document.test_reports.json,
      data.aws_iam_policy_document.reports_bucket_write.json,
    ], local.codeartifact_blocks)
    "security-scan" = [
      data.aws_iam_policy_document.build_logs.json, data.aws_iam_policy_document.artifacts_key_use.json, data.aws_iam_policy_document.ecr_login.json,
      data.aws_iam_policy_document.pull_tools_image.json, data.aws_iam_policy_document.pipeline_artifacts_rw.json, data.aws_iam_policy_document.test_reports.json,
      data.aws_iam_policy_document.reports_bucket_write.json, data.aws_iam_policy_document.scanner_tokens.json,
    ]
    "integration-test" = concat([
      data.aws_iam_policy_document.build_logs.json, data.aws_iam_policy_document.artifacts_key_use.json, data.aws_iam_policy_document.ecr_login.json,
      data.aws_iam_policy_document.pull_tools_image.json, data.aws_iam_policy_document.pull_through_cache.json, data.aws_iam_policy_document.pipeline_artifacts_rw.json,
      data.aws_iam_policy_document.test_reports.json, data.aws_iam_policy_document.reports_bucket_write.json,
    ], local.codeartifact_blocks)
    # Builds, scans, pushes, writes the SBOM and signs the application image
    "package-publish" = concat([
      data.aws_iam_policy_document.build_logs.json, data.aws_iam_policy_document.artifacts_key_use.json, data.aws_iam_policy_document.ecr_login.json,
      data.aws_iam_policy_document.pull_tools_image.json, data.aws_iam_policy_document.pull_through_cache.json, data.aws_iam_policy_document.push_app_images.json,
      data.aws_iam_policy_document.build_cache_write.json, data.aws_iam_policy_document.pipeline_artifacts_rw.json, data.aws_iam_policy_document.test_reports.json,
      data.aws_iam_policy_document.reports_bucket_write.json, data.aws_iam_policy_document.image_signing.json,
    ], local.codeartifact_blocks)
  }
}

data "aws_iam_policy_document" "codebuild" {
  for_each                = local.codebuild_role_policies
  source_policy_documents = each.value
}

resource "aws_iam_role" "codebuild" {
  for_each             = local.codebuild_role_policies
  name                 = "${var.project}-codebuild-${each.key}-role"
  assume_role_policy   = data.aws_iam_policy_document.codebuild_trust.json
  permissions_boundary = aws_iam_policy.boundary.arn
}

resource "aws_iam_role_policy" "codebuild" {
  for_each = local.codebuild_role_policies
  name     = "${var.project}-codebuild-${each.key}"
  role     = aws_iam_role.codebuild[each.key].id
  policy   = data.aws_iam_policy_document.codebuild[each.key].json
}

# =============================================================================================
# CodePipeline role: runs the CodeBuild projects and assumes the workload deploy roles.
# The name is part of the contract with the workload accounts' deploy role trust policies.
# =============================================================================================
data "aws_iam_policy_document" "codepipeline" {
  source_policy_documents = [
    data.aws_iam_policy_document.artifacts_key_use.json,
    data.aws_iam_policy_document.pipeline_artifacts_rw.json,
    data.aws_iam_policy_document.use_github_connection.json,
  ]

  statement {
    sid       = "RunCodeBuildProjects"
    actions   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds", "codebuild:StopBuild"]
    resources = [local.codebuild_project_arns]
  }

  dynamic "statement" {
    for_each = length(var.deploy_targets) > 0 ? [1] : []
    content {
      sid       = "AssumeWorkloadDeployRoles"
      actions   = ["sts:AssumeRole"]
      resources = values(local.deploy_role_arns)
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name                 = "${var.project}-codepipeline-role"
  assume_role_policy   = data.aws_iam_policy_document.codepipeline_trust.json
  permissions_boundary = aws_iam_policy.boundary.arn
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${var.project}-codepipeline"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}
