# S3 backend: this account's state bucket, key = "bootstrap/terraform.tfstate", use_lockfile = true
terraform {
  backend "s3" {
    bucket       = "emer-tfstate-shared-965452087758"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}