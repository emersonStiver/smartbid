# shared/bootstrap — Calls state-backend. First apply uses local state, then migrate into its own bucket.
module "state-backend" {
  source                  = "../../../modules/state-backend"
  bucket_name             = "emer-tfstate-${var.environment}-${var.account_id}"
  versioning_enabled      = var.versioning_enabled
  lifecycle_rules_enabled = var.lifecycle_rules_enabled
}



