# ---------------------------------------------------------------------------------------------
# alias/<project>-artifacts — symmetric key for S3, CloudWatch Logs, SNS and CodeBuild/CodePipeline
# ---------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "artifacts_key" {
  #checkov:skip=CKV_AWS_109:Key policy: "*" refers to this key only; access is delegated to IAM
  #checkov:skip=CKV_AWS_111:Key policy: "*" refers to this key only; access is delegated to IAM
  #checkov:skip=CKV_AWS_356:Key policy: "*" refers to this key only
  statement {
    sid       = "EnableIamPolicies"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${local.region}:${var.account_id}:log-group:*"]
    }
  }

  # Services that publish to the encrypted SNS notifications topic
  statement {
    sid       = "AllowNotificationPublishers"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["*"]
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

  # Workload deploy roles read pipeline artifacts (e.g. imagedefinitions.json)
  dynamic "statement" {
    for_each = length(var.deploy_targets) > 0 ? [1] : []
    content {
      sid       = "AllowDeployRolesDecrypt"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = ["*"]
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

resource "aws_kms_key" "artifacts" {
  description             = "${var.project} CI/CD: artifacts, reports, build logs and notifications"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.artifacts_key.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "artifacts" {
  name          = "alias/${var.project}-artifacts"
  target_key_id = aws_kms_key.artifacts.key_id
}

# ---------------------------------------------------------------------------------------------
# alias/<project>-signing — asymmetric key cosign uses to sign container images
# ---------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "signing_key" {
  #checkov:skip=CKV_AWS_109:Key policy: "*" refers to this key only; access is delegated to IAM
  #checkov:skip=CKV_AWS_111:Key policy: "*" refers to this key only; access is delegated to IAM
  #checkov:skip=CKV_AWS_356:Key policy: "*" refers to this key only
  statement {
    sid       = "EnableIamPolicies"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }

  # Workload accounts can fetch the public key to verify signatures before deploying
  dynamic "statement" {
    for_each = length(var.deploy_targets) > 0 ? [1] : []
    content {
      sid       = "AllowWorkloadAccountsVerify"
      actions   = ["kms:GetPublicKey", "kms:DescribeKey", "kms:Verify"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = local.deploy_account_roots
      }
    }
  }
}

resource "aws_kms_key" "signing" {
  #checkov:skip=CKV_AWS_7:Automatic rotation is not supported for asymmetric keys
  description              = "${var.project} CI/CD: container image signing (cosign)"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 30
  policy                   = data.aws_iam_policy_document.signing_key.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "signing" {
  name          = "alias/${var.project}-signing"
  target_key_id = aws_kms_key.signing.key_id
}
