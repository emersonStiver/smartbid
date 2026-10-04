# Variable declarations for shared/bootstrap
variable "region" {
  description = "The AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
}

variable "allowed_account_ids" {
  description = "List of allowed AWS account IDs"
  type        = list(string)
  validation {
    condition     = can(regex("^[0-9]{12}$", join("", var.allowed_account_ids)))
    error_message = "Each allowed_account_id must be a 12-digit AWS account ID."
  }
}

variable "versioning_enabled" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}
variable "lifecycle_rules_enabled" {
  description = "Enable lifecycle rules for the S3 bucket"
  type        = bool
  default     = true
}
variable "managed_by" {
  description = "The entity managing the resources"
  type        = string
  default     = "terraform"
}
variable "stack" {
  description = "The stack name"
  type        = string
}