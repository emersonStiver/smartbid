account_id  = "965452087758"
environment = "shared"
stack       = "cicd-pipeline"
project     = "smartbid"
managed_by  = "terraform"

github_repository = "emersonStiver/smartbid"
main_branch       = "main"

trigger_file_paths = [
  "analyzer-service/**",
  "buildspecs/**",
  "ci/integration/**",
]

# Names must match environments/<env>/services
deploy_environments = {
  dev = {
    cluster_name = "smartbid-dev"
    service_name = "analyzer-service"
  }
  # prod = {
  #   cluster_name = "smartbid-prod"
  #   service_name = "analyzer-service"
  # }
}

enable_prod_stages = false
