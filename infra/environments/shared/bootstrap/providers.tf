# AWS provider: region, allowed_account_ids, assume_role, default_tags

provider "aws" {
  region              = var.region
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = {
      Project     = "smartbid"
      Environment = var.environment
      AccountID   = var.account_id
      ManagedBy   = var.managed_by
      Stack       = var.stack
    }
  }
}