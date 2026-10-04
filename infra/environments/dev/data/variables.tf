# Variable declarations for dev/data

variable "environment" {
  description = "The environment name "
  type        = string
}
variable "account_id" {
  description = "The AWS account ID for the environment"
  type        = string
}
variable "stack" {
  description = "The stack name"
  type        = string
}