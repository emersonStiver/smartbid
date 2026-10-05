# Variable declarations for dev/network
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

variable "project" {
  description = "Project name used as resource name prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for the subnets, pinned so the layout never changes on its own"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "One public subnet per availability zone (same order as availability_zones)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "public_subnet_cidrs needs exactly one CIDR per availability zone."
  }
}