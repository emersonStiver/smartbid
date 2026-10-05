# Terraform creates the secret containers only; the values are put in by hand (never in code or state):
#   aws secretsmanager put-secret-value --secret-id <name> --secret-string '<json>'

# Docker Hub credentials for the docker-hub pull-through cache rule.
# ECR requires the "ecr-pullthroughcache/" name prefix.
# Value: {"username":"<docker-hub-user>","accessToken":"<docker-hub-access-token>"}
resource "aws_secretsmanager_secret" "docker_hub" {
  #checkov:skip=CKV_AWS_149:Read by the ECR pull-through cache; the AWS managed key avoids extra KMS grants for ECR
  #checkov:skip=CKV2_AWS_57:Docker Hub access tokens are rotated by hand
  count                   = var.create_docker_hub_secret ? 1 : 0
  name                    = "ecr-pullthroughcache/docker-hub"
  description             = "Docker Hub credentials for the ECR pull-through cache"
  recovery_window_in_days = 7
}

# Tokens for SaaS scanners (Semgrep, Snyk), read by the security-scan project.
# Value: {"SEMGREP_APP_TOKEN":"...","SNYK_TOKEN":"..."}
resource "aws_secretsmanager_secret" "scanner_tokens" {
  #checkov:skip=CKV2_AWS_57:SaaS scanner tokens are rotated by hand
  count                   = var.create_scanner_tokens_secret ? 1 : 0
  name                    = "${var.project}/ci/scanner-tokens"
  description             = "API tokens for SaaS security scanners"
  kms_key_id              = aws_kms_key.artifacts.arn
  recovery_window_in_days = 7
}
