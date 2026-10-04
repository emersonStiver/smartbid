# shared/cicd-builds — CodeBuild projects.
# GitHub-related (both use the myapp-github connection ARN from cicd-foundation as source auth):
#
# myapp-pr-check — validates pull requests BEFORE merge
#   - buildspec: buildspecs/pr-check.yml, image: myapp-ci/tools, role: myapp-codebuild-pr-check-role
#   - full git clone depth (the buildspec diffs the PR against main)
#   - webhook filter: PULL_REQUEST_CREATED / PULL_REQUEST_UPDATED / PULL_REQUEST_REOPENED, BASE_REF = main
#   - ACTOR_ACCOUNT_ID filter: only your GitHub user ID + dependabot[bot] (PR code is untrusted)
#   - reports pass/fail to GitHub as a commit status -> that status becomes the required check on main
#
# myapp-ci-image-build — rebuilds the myapp-ci/tools image
#   - webhook filter: PUSH, HEAD_REF = main, FILE_PATH = ^ci/images/  (+ weekly EventBridge schedule)
