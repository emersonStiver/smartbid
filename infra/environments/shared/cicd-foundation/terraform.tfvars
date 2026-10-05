account_id  = "965452087758"
environment = "shared"
stack       = "cicd-foundation"
project     = "smartbid"
managed_by  = "terraform"

deploy_targets = {
  dev = { account_id = "897744508036" }
  # prod = { account_id = "<prod-account-id>" }
}

app_repositories = ["analyzer-service"]

artifact_retention_days = 30
reports_retention_days  = 365

# Optional pieces of the plan (see README.md before enabling)
create_docker_hub_secret       = false
enable_docker_hub_pull_through = false
create_scanner_tokens_secret   = false
enable_codeartifact            = false
