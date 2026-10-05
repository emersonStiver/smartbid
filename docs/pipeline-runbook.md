# Pipeline runbook

How to stand up the CI/CD pipeline (shared account) that deploys `analyzer-service` to ECS in the dev account.

```
GitHub ──(smartbid-github connection)──▶ smartbid-pipeline (shared 965452087758)
  PR opened ──webhook──▶ smartbid-pr-check ──status "smartbid/pr-check"──▶ PR
  merge to main ──▶ Source → Validate (build-test ∥ security-scan) → IntegrationTest → Package → DeployDev
                                                                                          │ assumes
                                                                                          ▼
                                                     smartbid-dev-deploy-role (dev 897744508036)
                                                     ECS smartbid-dev / analyzer-service (public IP)
```

## Apply order (first time)

Each step reads what the previous ones created. Run from WSL at the repo root; the providers use
`AWS_PROFILE`, so set it per account. `terraform init` once per folder.

| # | Profile | Stack | Why this order |
|---|---|---|---|
| 1 | dev | `infra/environments/dev/bootstrap` | Creates `smartbid-dev-deploy-role`; shared KMS/bucket policies reference it |
| 2 | dev | `infra/environments/dev/edge` | VPC + public subnets, published to SSM |
| 3 | shared | `infra/environments/shared/cicd-foundation` | KMS, buckets, ECR, connection, roles. **Then finish the connection handshake** (stack README) |
| 4 | dev | `infra/environments/dev/services` | ECS cluster/service running a placeholder image |
| 5 | shared | `infra/environments/shared/cicd-builds` | Needs the connection `AVAILABLE` (webhooks) |
| 6 | shared | — | Build the tools image once (below) |
| 7 | shared | `infra/environments/shared/cicd-pipeline` | Creating the pipeline starts its first run |
| 8 | shared | `infra/environments/shared/cicd-notifications` | Reads the pipeline and project ARNs |

```bash
export AWS_PROFILE=dev
terraform -chdir=infra/environments/dev/bootstrap init
terraform -chdir=infra/environments/dev/bootstrap plan    # expect: deploy role + policy, nothing else
terraform -chdir=infra/environments/dev/bootstrap apply
```

Repeat `init` / `plan` / `apply` for each stack with the matching profile.

### Step 6: build the CI tools image

Every project except `smartbid-ci-image-build` runs on `smartbid-ci/tools:latest`, which doesn't exist until this runs:

```bash
AWS_PROFILE=shared aws codebuild start-build --project-name smartbid-ci-image-build
```

Takes ~10 minutes. Afterwards it rebuilds on every merge touching `ci/images/**` and every Monday.

## Check that it works

1. **Pipeline:** AWS Console (shared) → CodePipeline → `smartbid-pipeline`: all stages green.
2. **App:** print the task's public IP, then call it:

   ```bash
   terraform -chdir=infra/environments/dev/services output -raw find_public_ip | AWS_PROFILE=dev bash
   curl http://<public-ip>:8080/api/v1/analyzer-service/testEndpoint
   ```

3. **Reports:** CodeBuild → Report groups: unit tests, coverage, integration tests, security findings.
4. **Supply chain:** ECR `smartbid/analyzer-service` shows the commit-SHA tag plus cosign `.sig` / `.att` entries;
   the SBOM is in `s3://smartbid-reports-965452087758-us-east-1/sbom/`.
5. **GitHub:** open a PR → `smartbid/pr-check` appears → make it required (`docs/github-setup.md`, section 7).

## Day to day

- Merging a PR that touches `analyzer-service/**`, `buildspecs/**` or `ci/integration/**` runs the pipeline.
  Infrastructure changes (`infra/**`) are applied by hand with `terraform apply` (validated by `pr-check`).
- A failed run: open the failed action → **View details** → CodeBuild logs and the report group tab.
- Retrying a run is safe: `package-publish` reuses an image already pushed for that commit.

## Things to know

- **Task settings vs the pipeline.** The pipeline creates new task definition revisions (new image, same settings)
  and Terraform ignores the service's task definition. After changing CPU, memory, ports or env vars in
  `dev/services`, the change reaches the service on the next pipeline deploy only if you also update the service's
  task definition (`aws ecs update-service --task-definition <new-revision>`).
- **No container health check yet** in the task definition (the placeholder image has no actuator). Add one in
  `dev/services` once the real image is deployed.
- **The public IP changes on every deployment** (no load balancer). Restrict `allowed_ingress_cidrs` to your IP.
- **`prevent_destroy`** protects the KMS keys, buckets, app repo and connection. To tear down, remove those
  lifecycle blocks first, and empty the buckets.
- **Cost while running** (approx.): Fargate task ~$18/month, public IPv4 ~$4, 2 KMS keys $2, CodeBuild per
  build minute, Container Insights a few dollars. Pause the app with `desired_count = 0` in `dev/services`.
- **Prod later:** add the prod account to `deploy_targets` (foundation), a `prod/bootstrap` deploy role,
  `prod/edge` + `prod/services`, a `prod` entry in `deploy_environments`, and `enable_prod_stages = true` (pipeline).
