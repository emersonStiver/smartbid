# Input variables for the state-backend module (no defaults for env-specific values)

variable "bucket_name" {
  type        = string
  description = "This is the name for the bucket that will store the tfstate files"
}

variable "deny_bucket_deletion" {
  type        = bool
  description = "Attaches a bucket policy that denies s3:DeleteBucket for everyone (use in prod)."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for server-side encryption"
  default     = null
}

variable "versioning_enabled" {
  type        = bool
  description = "value"
  default     = true
}

variable "lifecycle_rules_enabled" {
  type        = bool
  description = "Whether to enable lifecycle rules for the S3 bucket"
  default     = true
}

variable "nonconcurrent_version_expiration_days" {
  type        = number
  description = "Number of days before older object versions are permanently deleted."
  default     = 90
}