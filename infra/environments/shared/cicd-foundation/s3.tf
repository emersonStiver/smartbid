# Pipeline artifacts: short-lived, readable by the workload deploy roles
data "aws_iam_policy_document" "artifacts_bucket" {
  dynamic "statement" {
    for_each = length(var.deploy_targets) > 0 ? [1] : []
    content {
      sid       = "AllowDeployRolesRead"
      actions   = ["s3:GetObject", "s3:GetObjectVersion"]
      resources = ["${local.artifacts_bucket_arn}/*"]
      principals {
        type        = "AWS"
        identifiers = local.deploy_account_roots
      }
      condition {
        test     = "ArnEquals"
        variable = "aws:PrincipalArn"
        values   = values(local.deploy_role_arns)
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.deploy_targets) > 0 ? [1] : []
    content {
      sid       = "AllowDeployRolesLocate"
      actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
      resources = [local.artifacts_bucket_arn]
      principals {
        type        = "AWS"
        identifiers = local.deploy_account_roots
      }
      condition {
        test     = "ArnEquals"
        variable = "aws:PrincipalArn"
        values   = values(local.deploy_role_arns)
      }
    }
  }
}

module "artifacts_bucket" {
  source                             = "../../../modules/s3-bucket"
  bucket_name                        = local.artifacts_bucket_name
  kms_key_arn                        = aws_kms_key.artifacts.arn
  expiration_days                    = var.artifact_retention_days
  noncurrent_version_expiration_days = 7
  policy_json                        = length(var.deploy_targets) > 0 ? data.aws_iam_policy_document.artifacts_bucket.json : null
}

# SBOMs, scan reports and exported CodeBuild test reports: long retention
module "reports_bucket" {
  source                             = "../../../modules/s3-bucket"
  bucket_name                        = local.reports_bucket_name
  kms_key_arn                        = aws_kms_key.artifacts.arn
  expiration_days                    = var.reports_retention_days
  noncurrent_version_expiration_days = 30
}
