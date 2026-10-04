# AWS provider: region, allowed_account_ids, assume_role, default_tags
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = {
      "Account"     = var.account_id
      "Stack"       = var.stack
      "Environment" = var.environment
    }
  }
}