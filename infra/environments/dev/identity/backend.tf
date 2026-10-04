terraform {
  backend "s3" {
    bucket       = "emer-tfstate-dev-897744508036"
    key          = "identity/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

