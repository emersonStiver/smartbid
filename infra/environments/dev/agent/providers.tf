provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      "Account"     = var.account_id
      "Stack"       = var.stack
      "Environment" = var.environment
    }
  }
}