# Input variables for the codebuild-project module

variable "name" {
  type        = string
  description = "Project name; also used for the log group /aws/codebuild/<name>"
}

variable "description" {
  type        = string
  description = "What the project does"
}

variable "service_role_arn" {
  type        = string
  description = "IAM role the build runs as"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key for build artifacts and the log group"
}

variable "image" {
  type        = string
  description = "Build image: a CodeBuild curated image or an ECR image URI"
}

variable "image_pull_credentials_type" {
  type        = string
  description = "CODEBUILD for curated images, SERVICE_ROLE for private ECR images"
  default     = "SERVICE_ROLE"

  validation {
    condition     = contains(["CODEBUILD", "SERVICE_ROLE"], var.image_pull_credentials_type)
    error_message = "image_pull_credentials_type must be CODEBUILD or SERVICE_ROLE."
  }
}

variable "compute_type" {
  type        = string
  description = "Build machine size"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "privileged_mode" {
  type        = bool
  description = "Required to run a Docker daemon (docker build, docker compose)"
  default     = false
}

variable "build_timeout_minutes" {
  type        = number
  description = "Build timeout in minutes"
  default     = 30
}

variable "buildspec" {
  type        = string
  description = "Path of the buildspec file in the repository"
}

variable "source_type" {
  type        = string
  description = "CODEPIPELINE (pipeline stage) or GITHUB (webhook-triggered)"

  validation {
    condition     = contains(["CODEPIPELINE", "GITHUB"], var.source_type)
    error_message = "source_type must be CODEPIPELINE or GITHUB."
  }
}

variable "source_location" {
  type        = string
  description = "HTTPS clone URL of the GitHub repository (GITHUB source only)"
  default     = null
}

variable "connection_arn" {
  type        = string
  description = "CodeConnections connection ARN used to access GitHub (GITHUB source only)"
  default     = null
}

variable "git_clone_depth" {
  type        = number
  description = "0 = full clone (GITHUB source only)"
  default     = 1
}

variable "report_build_status" {
  type        = bool
  description = "Report pass/fail back to GitHub as a commit status (GITHUB source only)"
  default     = false
}

variable "build_status_context" {
  type        = string
  description = "Status check name shown on GitHub (GITHUB source only)"
  default     = null
}

variable "environment_variables" {
  type        = map(string)
  description = "Plain-text environment variables for the build"
  default     = {}
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention"
  default     = 30
}
