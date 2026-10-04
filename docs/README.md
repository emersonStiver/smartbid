# SmartBid

Angular frontend, Spring Boot services and Terraform infrastructure on AWS, in one repository.

## Repository layout

| Path | What it is |
|---|---|
| `frontend/` | Angular app |
| `analyzer-service/` | Spring Boot service (Java 21) |
| `infra/` | Terraform: `modules/` (reusable) and `environments/<account>/<layer>/` (one state per layer) |
| `buildspecs/` | Instructions AWS CodeBuild runs (one file per CodeBuild project) |
| `ci/images/` | The `myapp-ci/tools` build image (Dockerfile + its buildspec) |
| `.github/` | Files GitHub reads: code owners, PR/issue templates, Dependabot, branch ruleset |
| `docs/` | Project documentation |

## CI/CD

GitHub stores the code and hosts pull requests. All CI/CD runs on AWS in the shared account
(`infra/environments/shared/cicd-*`), connected to GitHub through the `myapp-github` CodeConnections connection:

- **Pull request opened/updated** → CodeBuild `myapp-pr-check` (`buildspecs/pr-check.yml`) → pass/fail shown on the PR; merging requires a pass.
- **Merge to `main`** → CodePipeline `myapp-pipeline`: Validate → IntegrationTest → Package → DeployDev → manual approval → DeployProd.
- **Change under `ci/images/` merged to `main`** (or weekly) → CodeBuild `myapp-ci-image-build` rebuilds the tools image.

## Prerequisites (WSL)

- Terraform 1.16.x, AWS CLI v2 (SSO login)
- Node.js 22+, Java 21
- `pre-commit`, `tflint`, `checkov`

## Getting started

```bash
pre-commit install          # enables commit checks (code + commit message)
aws sso login
cd infra/environments/dev/<layer> && terraform init && terraform plan
```

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md): branches, commits and the pull request workflow
- [docs/github-setup.md](docs/github-setup.md): one-time GitHub and CodeConnections setup
