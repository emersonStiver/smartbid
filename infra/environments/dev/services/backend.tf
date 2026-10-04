# S3 backend: this account's state bucket, key = "services/terraform.tfstate", use_lockfile = true
terraform {
  backend "s3" {
    bucket       = "emer-tfstate-dev-897744508036"
    key          = "services/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}