## What

<!-- What does this PR change? -->

## Why

<!-- "Closes #123" links the issue and closes it automatically when this PR merges -->
Closes #

## How to test

<!-- Steps a reviewer can follow to verify the change -->

## Checklist

- [ ] PR title follows Conventional Commits, e.g. `feat(infra): add cognito app client` (it becomes the squash commit message on `main`)
- [ ] `pre-commit run --all-files` passes locally
- [ ] No secrets, `.env` files, `*.tfstate` or `tfplan` files included
- [ ] For `infra/` changes: ran `terraform plan` for every changed layer and pasted the summary below

## Terraform plan

<!-- infra/ changes only. Paste the "Plan: X to add, Y to change, Z to destroy" summary per layer. Delete this section otherwise. -->

<details>
<summary>Plan output</summary>

```text

```

</details>
