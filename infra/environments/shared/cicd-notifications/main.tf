# shared/cicd-notifications — where CI/CD events go: SNS + email, pipeline and PR-check
# notification rules, ECR critical findings, a CloudWatch dashboard and a build failure alarm.
# Requires: cicd-foundation, cicd-builds and cicd-pipeline applied.

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "emer-tfstate-${var.environment}-${var.account_id}"
    key    = "cicd-foundation/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "builds" {
  backend = "s3"
  config = {
    bucket = "emer-tfstate-${var.environment}-${var.account_id}"
    key    = "cicd-builds/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "pipeline" {
  backend = "s3"
  config = {
    bucket = "emer-tfstate-${var.environment}-${var.account_id}"
    key    = "cicd-pipeline/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  f        = data.terraform_remote_state.foundation.outputs
  b        = data.terraform_remote_state.builds.outputs
  pipeline = data.terraform_remote_state.pipeline.outputs

  region = local.f.region

  # Projects that run inside the pipeline (watched by the dashboard and the failure alarm)
  pipeline_projects = {
    build_test       = local.b.project_names.build_test
    security_scan    = local.b.project_names.security_scan
    integration_test = local.b.project_names.integration_test
    package_publish  = local.b.project_names.package_publish
  }
}

# =============================================================================================
# SNS topic, encrypted with alias/<project>-artifacts
# =============================================================================================
resource "aws_sns_topic" "cicd" {
  name              = "${var.project}-cicd-notifications"
  kms_master_key_id = local.f.artifacts_kms_key_arn
}

data "aws_iam_policy_document" "cicd_topic" {
  statement {
    sid = "AccountOwnerManagement"
    actions = [
      "SNS:GetTopicAttributes", "SNS:SetTopicAttributes", "SNS:AddPermission", "SNS:RemovePermission",
      "SNS:DeleteTopic", "SNS:Subscribe", "SNS:ListSubscriptionsByTopic", "SNS:Publish",
    ]
    resources = [aws_sns_topic.cicd.arn]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowServicePublishers"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.cicd.arn]
    principals {
      type        = "Service"
      identifiers = ["codestar-notifications.amazonaws.com", "events.amazonaws.com", "cloudwatch.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "cicd" {
  arn    = aws_sns_topic.cicd.arn
  policy = data.aws_iam_policy_document.cicd_topic.json
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.cicd.arn
  protocol  = "email"
  endpoint  = each.key
}

# =============================================================================================
# Notification rules
# =============================================================================================
resource "aws_codestarnotifications_notification_rule" "pipeline" {
  name        = "${var.project}-pipeline-events"
  resource    = local.pipeline.pipeline_arn
  detail_type = "FULL"
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-manual-approval-needed",
  ]

  target {
    address = aws_sns_topic.cicd.arn
  }

  depends_on = [aws_sns_topic_policy.cicd]
}

resource "aws_codestarnotifications_notification_rule" "pr_check" {
  name           = "${var.project}-pr-check-events"
  resource       = local.b.project_arns.pr_check
  detail_type    = "FULL"
  event_type_ids = ["codebuild-project-build-state-failed"]

  target {
    address = aws_sns_topic.cicd.arn
  }

  depends_on = [aws_sns_topic_policy.cicd]
}

# =============================================================================================
# New CRITICAL findings from ECR scan-on-push on the application images
# =============================================================================================
resource "aws_cloudwatch_event_rule" "ecr_critical_findings" {
  name        = "${var.project}-ecr-critical-findings"
  description = "ECR image scan completed with CRITICAL findings on ${var.project} application images"
  event_pattern = jsonencode({
    source        = ["aws.ecr"]
    "detail-type" = ["ECR Image Scan"]
    detail = {
      "scan-status"     = ["COMPLETE"]
      "repository-name" = values(local.f.app_repository_names)
      "finding-severity-counts" = {
        CRITICAL = [{ numeric = [">", 0] }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "ecr_critical_findings" {
  rule = aws_cloudwatch_event_rule.ecr_critical_findings.name
  arn  = aws_sns_topic.cicd.arn
}

# =============================================================================================
# Dashboard: build duration and failure rate per pipeline project
# =============================================================================================
resource "aws_cloudwatch_dashboard" "cicd" {
  dashboard_name = "${var.project}-cicd-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Build duration (seconds, average)"
          region  = local.region
          view    = "timeSeries"
          stat    = "Average"
          period  = 3600
          metrics = [for p in values(local.pipeline_projects) : ["AWS/CodeBuild", "Duration", "ProjectName", p]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Failed builds (count)"
          region  = local.region
          view    = "timeSeries"
          stat    = "Sum"
          period  = 3600
          metrics = [for p in values(local.pipeline_projects) : ["AWS/CodeBuild", "FailedBuilds", "ProjectName", p]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Succeeded builds (count)"
          region  = local.region
          view    = "timeSeries"
          stat    = "Sum"
          period  = 3600
          metrics = [for p in values(local.pipeline_projects) : ["AWS/CodeBuild", "SucceededBuilds", "ProjectName", p]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Pull request checks"
          region = local.region
          view   = "timeSeries"
          stat   = "Sum"
          period = 3600
          metrics = [
            ["AWS/CodeBuild", "SucceededBuilds", "ProjectName", local.b.project_names.pr_check],
            ["AWS/CodeBuild", "FailedBuilds", "ProjectName", local.b.project_names.pr_check],
          ]
        }
      },
    ]
  })
}

# =============================================================================================
# Alarm: any pipeline build failure in the last 5 minutes
# =============================================================================================
resource "aws_cloudwatch_metric_alarm" "pipeline_failure" {
  alarm_name          = "${var.project}-pipeline-failure-alarm"
  alarm_description   = "A CodeBuild project in ${local.pipeline.pipeline_name} failed"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.cicd.arn]

  metric_query {
    id          = "failures"
    expression  = join(" + ", [for k in keys(local.pipeline_projects) : "FILL(${k}, 0)"])
    label       = "Failed pipeline builds"
    return_data = true
  }

  dynamic "metric_query" {
    for_each = local.pipeline_projects
    content {
      id = metric_query.key
      metric {
        namespace   = "AWS/CodeBuild"
        metric_name = "FailedBuilds"
        period      = 300
        stat        = "Sum"
        dimensions = {
          ProjectName = metric_query.value
        }
      }
    }
  }
}
