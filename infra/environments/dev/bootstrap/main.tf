# The label must stay "state_backend": that's the name the existing bucket has in the state file.
# Renaming it makes Terraform plan to destroy and recreate the state bucket.
module "state_backend" {
  source                  = "../../../modules/state-backend"
  bucket_name             = "emer-tfstate-${var.environment}-${var.account_id}"
  versioning_enabled      = var.versioning_enabled
  lifecycle_rules_enabled = var.lifecycle_rules_enabled
  deny_bucket_deletion    = var.deny_bucket_deletion
}
