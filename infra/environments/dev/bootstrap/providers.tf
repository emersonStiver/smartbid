provider "aws" {
  region = "us-east-1"
  #Alias
  #Profile from credentials file
  #Credentials can be provided in multiple ways
  #1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
  #2. AWS Credentials file (~/.aws/credentials)
  #3. Directly in the provider block (not recommended for production)
  #Assume role
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = {
      Environment = var.environment
      AccountID   = var.account_id
    }
  }
}

