# S3 backend: this account's state bucket, key = "bootstrap/terraform.tfstate", use_lockfile = true

terraform {
  backend "s3" {
    bucket       = "emer-tfstate-dev-897744508036"
    key          = "bootstrap/terraform.tfstate"
    use_lockfile = true
    region       = "us-east-1"
    encrypt      = true
  }
}


