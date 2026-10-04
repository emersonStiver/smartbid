# required_version and required_providers for the state-backend module
terraform {
  required_version = ">= 1.11" #CLI Version
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }
}
