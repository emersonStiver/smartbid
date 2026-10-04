provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = var.managed_by
      Stack       = var.stack
    }
  }
}