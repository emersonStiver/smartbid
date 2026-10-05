# Contributing

How work moves from an idea to `main`. The same flow applies whether you work alone or on a team.

## The flow

```
issue  →  branch  →  commits  →  push  →  pull request  →  checks + review  →  squash merge  →  delete branch
```

1. **Every change starts with an issue** (bug, feature or task). It records *why* the change exists.
2. **Create a short-lived branch from an up-to-date `main`.** Aim to merge within a day or two.
3. **Commit in small steps** with Conventional Commit messages.
4. **Open a pull request** early (as a draft if it's not ready) and link the issue.
5. **Checks must pass:** local pre-commit hooks, then the CodeBuild `smartbid-pr-check` status on the PR.
6. **Squash merge.** The PR becomes one commit on `main` whose message is the PR title.
7. **Delete the branch.** GitHub does this automatically after merge.

`main` is protected: no direct pushes, no force pushes, merges only through pull requests.

## Branch names

`<type>/<issue-number>-<short-description>`

| Example | Use for |
|---|---|
| `feat/12-cognito-app-client` | New functionality |
| `fix/31-pom-module-path` | Bug fix |
| `chore/40-upgrade-aws-provider` | Maintenance, tooling, dependencies |
| `docs/8-git-workflow` | Documentation only |
| `refactor/27-split-network-layer` | Code changes with no behavior change |

## Commit messages: Conventional Commits

```
<type>(<optional scope>): <description in imperative mood>
```

| Type | Meaning |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `chore` | Maintenance (deps, tooling) |
| `docs` | Documentation |
| `refactor` | Restructure without changing behavior |
| `test` | Tests only |
| `ci` | Build/pipeline changes (buildspecs, CodePipeline) |
| `perf` | Performance |

Scopes used in this repo: `infra`, `frontend`, `analyzer`, `ci`, `deps`.

```
feat(infra): add cognito app client for the frontend
fix(analyzer): correct parent pom relative path
chore(deps): bump hashicorp/aws to 6.67.0
```

The `commit-msg` hook rejects messages that don't follow this format. The **PR title** must follow it too, because it becomes the commit message on `main`.

## Day-to-day commands

```bash
# Start work on issue #12
git switch main
git pull
git switch -c feat/12-cognito-app-client

# Work and commit in small steps
git add infra/modules/cognito
git commit -m "feat(infra): add cognito app client module"

# Publish the branch and open a PR
git push -u origin feat/12-cognito-app-client
gh pr create --fill          # or use the link git prints

# main moved while you were working? Update your branch
git fetch origin
git rebase origin/main
git push --force-with-lease  # safe on YOUR feature branch only, never on main

# After the PR is merged
git switch main
git pull
git branch -d feat/12-cognito-app-client
```

## Infrastructure changes

- Run `terraform plan` for **every layer you changed** and paste the summary into the PR.
- Never commit `*.tfstate`, `tfplan` or secrets. `.gitignore` blocks them; pre-commit is a second safety net.
- Apply to `dev` first. Prod changes go through the pipeline's manual approval.
- A plan that wants to **destroy** something you didn't intend to touch means stop and investigate.

## Skipping a hook

Only when you understand why it's failing:

```bash
SKIP=no-commit-to-branch git commit -m "..."
```

Never use `git commit --no-verify` as a habit; it skips every check.
