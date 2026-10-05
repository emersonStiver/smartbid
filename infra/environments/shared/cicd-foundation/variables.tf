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

variable "deploy_targets" {
  description = "Workload accounts the pipeline deploys to. Each needs a <project>-<env>-deploy-role (created in that account's bootstrap stack)."
  type = map(object({
    account_id = string
  }))
}

variable "app_repositories" {
  description = "Application images, one ECR repository each (<project>/<name>)"
  type        = list(string)
}

variable "artifact_retention_days" {
  description = "Days pipeline artifacts are kept"
  type        = number
  default     = 30
}

variable "reports_retention_days" {
  description = "Days SBOMs and scan reports are kept"
  type        = number
  default     = 365
}

variable "create_docker_hub_secret" {
  description = "Create the empty ecr-pullthroughcache/docker-hub secret (put the credentials in it yourself)"
  type        = bool
  default     = false
}

variable "enable_docker_hub_pull_through" {
  description = "Create the docker-hub pull-through cache rule. Enable only after the secret holds valid credentials."
  type        = bool
  default     = false
}

variable "create_scanner_tokens_secret" {
  description = "Create the empty <project>/ci/scanner-tokens secret for Semgrep/Snyk tokens"
  type        = bool
  default     = false
}

variable "enable_codeartifact" {
  description = "Create the CodeArtifact domain and dependency proxy repositories"
  type        = bool
  default     = false
}