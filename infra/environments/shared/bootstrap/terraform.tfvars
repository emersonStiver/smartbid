# Non-secret values for shared/bootstrap (committed). Secrets go in Secrets Manager/SSM.
region                  = "us-east-1"
allowed_account_ids     = ["965452087758"]
environment             = "shared"
account_id              = "965452087758"
versioning_enabled      = true
lifecycle_rules_enabled = true
stack                   = "bootstrap"
managed_by              = "terraform"