provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = {
      Environment = var.environment
      AccountID   = var.account_id
      Stack       = var.stack
    }
  }
}