# Variable declarations for dev/bootstrap
variable "environment" {
  description = "The environment name "
  type        = string
}

variable "account_id" {
  description = "The AWS account ID for the environment"
  type        = string
}

variable "bucket_region" {
  description = "The region of the bucket that will store the state of all the terraform stacks in Dev Account"
  type        = string
}

variable "versioning_enabled" {
  type        = bool
  description = "Whether to activate or not versioning in the state bucket"
}

variable "lifecycle_rules_enabled" {
  type        = bool
  description = "Wether to activate the lifecycle rules in the state bucket"
}

variable "deny_bucket_deletion" {
  type        = bool
  description = "Whether to deny bucket deletion or not"
}

variable "project" {
  type        = string
  description = "Project name used as resource name prefix"
}

variable "shared_account_id" {
  type        = string
  description = "Account that runs the CI/CD pipeline and assumes the deploy role"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.shared_account_id))
    error_message = "shared_account_id must be a 12-digit AWS account ID."
  }
}