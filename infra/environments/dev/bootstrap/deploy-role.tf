# Deploy role: the shared account's pipeline assumes it to deploy into this account (ECS deploy action).
# Apply this BEFORE shared/cicd-foundation: the shared KMS key and bucket policies reference it.

data "aws_region" "current" {}

locals {
  region             = data.aws_region.current.region
  pipeline_role_arn  = "arn:aws:iam::${var.shared_account_id}:role/${var.project}-codepipeline-role"
  ecs_cluster_name   = "${var.project}-${var.environment}"
  shared_artifacts   = "arn:aws:s3:::${var.project}-artifacts-${var.shared_account_id}-${local.region}"
  task_role_name_arn = "arn:aws:iam::${var.account_id}:role/${var.project}-${var.environment}-*"
}

# Trust the shared account, but only its pipeline role. Trusting the account root plus an
# aws:PrincipalArn condition works even before that role exists (a direct role ARN would not).
data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.shared_account_id}:root"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [local.pipeline_role_arn]
    }
  }
}

data "aws_iam_policy_document" "deploy" {
  #checkov:skip=CKV_AWS_356:ecs:RegisterTaskDefinition, DescribeTaskDefinition, ListTasks and DescribeTasks do not support resource-level permissions
  #checkov:skip=CKV_AWS_111:ecs:RegisterTaskDefinition does not support resource-level permissions

  # Update the services in this environment's cluster
  statement {
    sid       = "UpdateEcsServices"
    actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
    resources = ["arn:aws:ecs:${local.region}:${var.account_id}:service/${local.ecs_cluster_name}/*"]
  }

  # The ECS deploy action registers a new task definition revision with the new image
  statement {
    sid       = "RegisterTaskDefinitions"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition", "ecs:ListTasks", "ecs:DescribeTasks"]
    resources = ["*"]
  }

  statement {
    sid       = "TagTaskDefinitions"
    actions   = ["ecs:TagResource"]
    resources = ["arn:aws:ecs:${local.region}:${var.account_id}:task-definition/${local.ecs_cluster_name}-*:*"]
  }

  # The new revision keeps the task execution role and task role
  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = [local.task_role_name_arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Read imagedefinitions.json from the shared artifacts bucket (encrypted with the shared KMS key)
  statement {
    sid       = "ReadPipelineArtifacts"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${local.shared_artifacts}/*"]
  }

  statement {
    sid       = "LocatePipelineArtifacts"
    actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
    resources = [local.shared_artifacts]
  }

  # Key policy on the shared artifacts key limits this to that one key
  statement {
    sid       = "DecryptPipelineArtifacts"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["arn:aws:kms:${local.region}:${var.shared_account_id}:key/*"]
  }
}

resource "aws_iam_role" "deploy" {
  name                 = "${var.project}-${var.environment}-deploy-role"
  description          = "Assumed by ${var.project}-codepipeline-role in the shared account to deploy to ${var.environment}"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.project}-${var.environment}-deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
