terraform {
  backend "s3" {
    bucket       = "emer-tfstate-dev-897744508036"
    key          = "agent/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}