# Module: codebuild-project — a CodeBuild project plus its KMS-encrypted CloudWatch log group
resource "aws_cloudwatch_log_group" "this" {
  #checkov:skip=CKV_AWS_338:Build logs are kept for var.log_retention_days to control cost; they are not compliance records
  name              = "/aws/codebuild/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

resource "aws_codebuild_project" "this" {
  #checkov:skip=CKV_AWS_316:Privileged mode is opt-in per project (only projects that run Docker) through var.privileged_mode
  name           = var.name
  description    = var.description
  service_role   = var.service_role_arn
  build_timeout  = var.build_timeout_minutes
  encryption_key = var.kms_key_arn

  artifacts {
    type = var.source_type == "CODEPIPELINE" ? "CODEPIPELINE" : "NO_ARTIFACTS"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = var.compute_type
    image                       = var.image
    image_pull_credentials_type = var.image_pull_credentials_type
    privileged_mode             = var.privileged_mode

    dynamic "environment_variable" {
      for_each = var.environment_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
        type  = "PLAINTEXT"
      }
    }
  }

  source {
    type                = var.source_type
    buildspec           = var.buildspec
    location            = var.source_type == "GITHUB" ? var.source_location : null
    git_clone_depth     = var.source_type == "GITHUB" ? var.git_clone_depth : null
    report_build_status = var.source_type == "GITHUB" ? var.report_build_status : null

    # GitHub access goes through the CodeConnections connection (no personal access tokens)
    dynamic "auth" {
      for_each = var.source_type == "GITHUB" ? [1] : []
      content {
        type     = "CODECONNECTIONS"
        resource = var.connection_arn
      }
    }

    # Name of the status check shown on GitHub pull requests
    dynamic "build_status_config" {
      for_each = var.source_type == "GITHUB" && var.build_status_context != null ? [1] : []
      content {
        context = var.build_status_context
      }
    }
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE", "LOCAL_CUSTOM_CACHE"]
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.this.name
      status     = "ENABLED"
    }
    s3_logs {
      status = "DISABLED"
    }
  }
}
