variable "account_id" {
  type        = string
  description = "The account id where the stack will be created"
}

variable "stack" {
  type        = string
  description = "the stack name"
}

variable "environment" {
  type        = string
  description = "the environment name"
}