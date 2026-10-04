terraform {
  backend "s3" {
    bucket       = "emer-tfstate-shared-965452087758"
    region       = "us-east-1"
    key          = "cicd-foundation/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}