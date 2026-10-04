terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = "6.66.0"
    }
  }
}