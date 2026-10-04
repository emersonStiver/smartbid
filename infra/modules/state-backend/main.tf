# Module: state-backend — S3 state bucket: versioning, encryption, public access block, prevent_destroy
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != null ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.lifecycle_rules_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id
  rule {
    id     = "Expire_old_versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.nonconcurrent_version_expiration_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}


#Move the main deletion guard to an SCP. A bucket policy deny is fine, 
#but any admin in that account can remove it. 
#Organizations usually enforce this centrally with a Service Control Policy from the management account,
#which member-account admins can't touch:
data "aws_iam_policy_document" "deny_delete_bucket" {
  count = var.deny_bucket_deletion ? 1 : 0
  statement {
    sid       = "DenyDeleteBucket"
    effect    = "Deny"
    actions   = ["s3:DeleteBucket"]
    resources = [aws_s3_bucket.this.arn]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count      = var.deny_bucket_deletion ? 1 : 0
  bucket     = aws_s3_bucket.this.id
  policy     = data.aws_iam_policy_document.deny_delete_bucket[0].json
  depends_on = [aws_s3_bucket_public_access_block.this]
}
