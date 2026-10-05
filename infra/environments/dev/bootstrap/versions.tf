terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = {
      # HOSTNAME registry.terraform.io
      # Namespace: hashicorp
      # Type: aws
      source  = "registry.terraform.io/hashicorp/aws"
      version = "6.67.0"
    }
  }
}
