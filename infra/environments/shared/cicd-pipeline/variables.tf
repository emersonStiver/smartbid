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
  description = "Branch whose pushes (merged PRs) trigger the pipeline"
  type        = string
  default     = "main"
}

variable "trigger_file_paths" {
  description = "Only pushes that change these paths start the pipeline"
  type        = list(string)
}

variable "deploy_environments" {
  description = "ECS service each environment deploys to. Keys must match cicd-foundation deploy_targets."
  type = map(object({
    cluster_name = string
    service_name = string
  }))
}

variable "enable_prod_stages" {
  description = "Add ApproveProd + DeployProd (requires a prod entry in deploy_environments)"
  type        = bool
  default     = false
}