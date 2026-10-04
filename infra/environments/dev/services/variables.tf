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