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

variable "github_repository" {
  description = "GitHub repository as <owner>/<repo>"
  type        = string
}

variable "main_branch" {
  description = "Branch pull requests merge into"
  type        = string
  default     = "main"
}

variable "app_service" {
  description = "Service the package-publish project builds (must exist in cicd-foundation app_repositories)"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch retention for build logs"
  type        = number
  default     = 30
}