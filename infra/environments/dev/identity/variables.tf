# Variable declarations for dev/identity
variable "environment" {
  description = "The environment name"
  type        = string
}
variable "account_id" {
  description = "The account id where the stack will be created"
  type        = string
}
variable "stack" {
  description = "The stack name"
  type        = string
}