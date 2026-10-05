# GitHub setup checklist

One-time setup, in order. Steps 1–6 happen now; step 7 happens once CI/CD development starts.

## 1. Before the first commit (WSL, repo root)

```bash
git config user.name "Your Name"
git config user.email "you@example.com"       # use the email on your GitHub account
git branch --show-current                     # should print: main
pre-commit install                            # installs pre-commit and commit-msg hooks
pre-commit run --all-files                    # fix anything it reports
```

- Replace `@your-github-username` in `.github/CODEOWNERS`.
- The `no-commit-to-branch` hook blocks commits on `main`. The very first commit has to be on `main`, so skip that one hook once:

```bash
git add .
git status                                    # check: no tfstate, tfplan, .terraform/ or .env
SKIP=no-commit-to-branch git commit -m "chore: initial project structure"
```

## 2. Organization and repository

1. GitHub → **Your organizations → New organization** (Free plan) for example `smartbid`.
2. **New repository** in the org, **Private**, *without* a README, .gitignore or license (the repo already has them).
3. Push:

```bash
git remote add origin git@github.com:<org>/<repo>.git
git push -u origin main
```

> **Plan limits for private repos.** On GitHub Free, rulesets on private repositories are **not enforced**, and secret scanning push protection and CodeQL require paid add-ons. Options: make the repo public, upgrade the org to Team, or keep it private and rely on local hooks plus discipline until you upgrade. Public repos get all of these for free.

## 3. Repository settings (Settings → General)

**Pull Requests**
- [ ] Allow merge commits: **off**
- [ ] Allow squash merging: **on** → default message: **Pull request title and description**
- [ ] Allow rebase merging: **off**
- [ ] Always suggest updating pull request branches: **on**
- [ ] Automatically delete head branches: **on**

**Features**
- [ ] Issues: **on**
- [ ] Wiki: **off** (docs live in `docs/`)

## 4. Protect `main` (Settings → Rules → Rulesets)

**New ruleset → Import a ruleset** → select `.github/rulesets/main.json`.

It enforces on the default branch:
- No deletion, no force pushes, linear history
- Changes only via pull request (0 approvals while solo, conversations must be resolved)
- Squash merge only

When a second person joins: raise approvals to 1 and enable **Require review from Code Owners**.

## 5. Security (Settings → Advanced Security / Code security)

- [ ] Dependabot alerts: **on**
- [ ] Dependabot security updates: **on**
- [ ] Dependabot version updates: already configured by `.github/dependabot.yml`
- [ ] Secret scanning + push protection: **on** (see plan limits above)
- [ ] Private vulnerability reporting: **on**
- [ ] CodeQL code scanning, default setup: optional. It runs on GitHub's own runners even though CI/CD runs on AWS.

## 6. Labels and project board

```bash
gh label create "area:infra"     --color 5319e7
gh label create "area:frontend"  --color 1d76db
gh label create "area:analyzer"  --color 0e8a16
gh label create "area:ci-cd"     --color fbca04
```

Create a **Project** (org → Projects → New → Board) with columns *Todo / In progress / In review / Done*, and link it to the repo.

## 7. Later: connect your AWS CI/CD stacks to GitHub

Follow your stack order. The GitHub-related parts of each stack:

| Stack | GitHub-related piece | What to do on the GitHub side |
|---|---|---|
| `cicd-foundation` | `smartbid-github` CodeConnections connection | After `apply`, finish the handshake (below). Grant access to **this repo only**. |
| `cicd-builds` | `smartbid-pr-check` webhook (pull requests) | Nothing to click. The webhook appears under repo **Settings → Webhooks** automatically. Then make its status a required check (below). |
| `cicd-builds` | `smartbid-ci-image-build` webhook (push to `main`, `ci/images/**`) | Nothing. Same automatic webhook. |
| `cicd-pipeline` | Source stage + trigger on push to `main` | Nothing. Every squash merge is one push to `main`, so one pipeline run. `IMAGE_TAG` is that commit's SHA. |
| `cicd-notifications` | `smartbid-pr-check-events` | Nothing. A failed PR check is also visible on the PR itself. |

### Finish the CodeConnections handshake (once)

The connection is created in `PENDING` status; Terraform can't complete the GitHub authorization.

1. AWS Console (shared account) → Developer Tools → Settings → **Connections** → `smartbid-github` → **Update pending connection**.
2. Install the **AWS Connector for GitHub** app on your GitHub organization.
3. Repository access: **Only select repositories** → this repo.
4. Status becomes `AVAILABLE`.

### Make `smartbid-pr-check` a required check

1. Open a test PR. CodeBuild posts a check named **`smartbid/pr-check`** at the bottom of the PR (set by `build_status_context` in `cicd-builds`).
2. **Settings → Rules → Rulesets → protect-main → Add rule → Require status checks to pass** → add `smartbid/pr-check` → enable **Require branches to be up to date before merging**.

> Only add the required check after CodeBuild has reported at least once. If it's required first, every PR waits forever for a check that never arrives.

### Security reminders for `smartbid-pr-check`

- PR code is untrusted until reviewed: `smartbid-codebuild-pr-check-role` gets read-only, reports and tools-image pull only. No deploy permissions, no secrets.
- The webhook's `pull_request_build_policy` builds PRs from **forks** only after a maintainer approves them with a comment. PRs from branches in the repo (yours, Dependabot's) build automatically.
