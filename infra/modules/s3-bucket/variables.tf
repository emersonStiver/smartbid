# Input variables for the s3-bucket module

variable "bucket_name" {
  type        = string
  description = "Globally unique bucket name"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the customer managed KMS key used for default encryption"
}

variable "expiration_days" {
  type        = number
  description = "Days after which current objects expire. null keeps them forever."
  default     = null
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Days after which previous object versions are permanently deleted"
  default     = 30
}

variable "policy_json" {
  type        = string
  description = "Additional bucket policy statements (JSON) merged with the TLS-only statement"
  default     = null
}
