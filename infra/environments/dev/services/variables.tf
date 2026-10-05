# Variable declarations for dev/services
variable "account_id" {
  description = "The account id where the stack will be created"
  type        = string
}
variable "environment" {
  description = "The environment for the stack"
  type        = string
}
variable "stack" {
  description = "The stack name"
  type        = string
}

variable "project" {
  description = "Project name used as resource name prefix"
  type        = string
}

variable "service_name" {
  description = "ECS service and container name. Must match the pipeline's deploy_environments and CONTAINER_NAME."
  type        = string
}

variable "initial_image" {
  description = "Placeholder image for the very first deployment; the pipeline replaces it with the real image"
  type        = string
}

variable "container_port" {
  description = "Application port (SERVER_PORT)"
  type        = number
  default     = 8080
}

variable "management_port" {
  description = "Actuator port (MANAGEMENT_SERVER_PORT); not exposed outside the task"
  type        = number
  default     = 8081
}

variable "cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of running tasks"
  type        = number
  default     = 1
}

variable "allowed_ingress_cidrs" {
  description = "Who can reach the application port. Use your own IP (x.x.x.x/32) instead of 0.0.0.0/0 when possible."
  type        = list(string)
}

variable "log_retention_days" {
  description = "CloudWatch retention for container logs"
  type        = number
  default     = 14
}