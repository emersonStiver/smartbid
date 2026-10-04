variable "account_id" {
  type        = string
  description = "The AWS account ID"
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "The account_id must be a 12-digit AWS account ID."
  }
}

variable "stack" {
  description = "The stack name"
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "project" {
  description = "The project name"
  type        = string
}
variable "managed_by" {
  description = "The entity managing the resources"
  type        = string
}