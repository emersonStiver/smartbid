# Read by cicd-pipeline and cicd-notifications through terraform_remote_state

output "project_names" {
  value = {
    ci_image_build   = module.ci_image_build.name
    pr_check         = module.pr_check.name
    build_test       = module.build_test.name
    security_scan    = module.security_scan.name
    integration_test = module.integration_test.name
    package_publish  = module.package_publish.name
  }
}

output "project_arns" {
  value = {
    ci_image_build   = module.ci_image_build.arn
    pr_check         = module.pr_check.arn
    build_test       = module.build_test.arn
    security_scan    = module.security_scan.arn
    integration_test = module.integration_test.arn
    package_publish  = module.package_publish.arn
  }
}

output "pr_check_status_context" {
  description = "Status check name to require in the GitHub ruleset"
  value       = "${var.project}/pr-check"
}
