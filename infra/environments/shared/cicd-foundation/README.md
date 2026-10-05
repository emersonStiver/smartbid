# cicd-foundation

Long-lived CI/CD resources in the shared account. Everything the other `cicd-*` stacks use comes from here
(read through `terraform_remote_state`). Critical resources (KMS keys, buckets, app ECR repos, the GitHub
connection) have `prevent_destroy`.

| File | Contents |
|---|---|
| `kms.tf` | `alias/smartbid-artifacts` (S3, logs, SNS, builds) and `alias/smartbid-signing` (cosign) |
| `s3.tf` | Artifacts bucket (30-day expiry, readable by deploy roles) and reports bucket (SBOMs, scans) |
| `ecr.tf` | `smartbid/<service>` app repos, `smartbid-ci/tools`, `smartbid-ci/build-cache`, pull-through cache |
| `connection.tf` | `smartbid-github` CodeConnections connection |
| `secrets.tf` | Optional Docker Hub and scanner-token secret containers |
| `ssm.tf` | `/smartbid/cicd/<env>/account-id` and `/deploy-role-arn` |
| `iam.tf` | `smartbid-cicd-boundary` and every CodeBuild/CodePipeline role |
| `codeartifact.tf` | Optional dependency proxy |

## Before the first apply

Each workload account in `deploy_targets` must already have its deploy role
(`environments/<env>/bootstrap`). Key and bucket policies reference it.

## After the first apply: finish the GitHub connection

The connection is created in `PENDING` status; Terraform can't complete the GitHub authorization.

1. AWS Console (shared account) → Developer Tools → Settings → **Connections** → `smartbid-github` → **Update pending connection**.
2. Install the **AWS Connector for GitHub** app on your GitHub account.
3. Repository access: **Only select repositories** → `smartbid`.
4. Status becomes `AVAILABLE` (`terraform output connection_status`).

## Optional features

| Variable | Steps |
|---|---|
| Docker Hub pull-through | 1. `create_docker_hub_secret = true` → apply. 2. `aws secretsmanager put-secret-value --secret-id ecr-pullthroughcache/docker-hub --secret-string '{"username":"...","accessToken":"..."}'`. 3. `enable_docker_hub_pull_through = true` → apply. |
| Scanner tokens | `create_scanner_tokens_secret = true` → apply → put the value → reference it in `buildspecs/security-scan.yml` (`env.secrets-manager`). |
| CodeArtifact | `enable_codeartifact = true` → apply. |
