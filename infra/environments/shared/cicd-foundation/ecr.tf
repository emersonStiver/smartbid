# ---------------------------------------------------------------------------------------------
# Application images: <project>/<service>, immutable tags (the commit SHA), scanned on push
# ---------------------------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  #checkov:skip=CKV_AWS_136:AES256 at rest; a CMK would need KMS grants for cross-account pulls from the workload accounts
  for_each             = toset(var.app_repositories)
  name                 = "${var.project}/${each.key}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "app_repository" {
  statement {
    sid = "AllowWorkloadAccountsPull"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    principals {
      type        = "AWS"
      identifiers = local.deploy_account_roots
    }
  }
}

resource "aws_ecr_repository_policy" "app" {
  for_each   = length(var.deploy_targets) > 0 ? aws_ecr_repository.app : {}
  repository = each.value.name
  policy     = data.aws_iam_policy_document.app_repository.json
}

resource "aws_ecr_lifecycle_policy" "app" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 14 days"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 14 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep the 100 most recent images (includes cosign .sig/.att entries)"
        selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 100 }
        action       = { type = "expire" }
      },
    ]
  })
}

# ---------------------------------------------------------------------------------------------
# CI tools image: every tag immutable except "latest", which CodeBuild projects reference
# ---------------------------------------------------------------------------------------------
resource "aws_ecr_repository" "ci_tools" {
  #checkov:skip=CKV_AWS_51:Immutable except the "latest" tag (IMMUTABLE_WITH_EXCLUSION), which CodeBuild projects reference
  #checkov:skip=CKV_AWS_136:AES256 at rest is sufficient for the internal tools image
  name                 = "${var.project}-ci/tools"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  image_tag_mutability_exclusion_filter {
    filter      = "latest"
    filter_type = "WILDCARD"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "ci_tools" {
  repository = aws_ecr_repository.ci_tools.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 10 most recent tools images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------------------------
# Docker build cache (buildx --cache-to type=registry): cache tags are overwritten on every build
# ---------------------------------------------------------------------------------------------
resource "aws_ecr_repository" "build_cache" {
  #checkov:skip=CKV_AWS_51:Cache tags must be overwritten on every build
  #checkov:skip=CKV_AWS_136:AES256 at rest is sufficient for build cache layers
  #checkov:skip=CKV_AWS_163:Cache layers are never deployed; the final image is scanned instead
  name                 = "${var.project}-ci/build-cache"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "build_cache" {
  repository = aws_ecr_repository.build_cache.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Remove untagged cache layers after 7 days"
      selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
      action       = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------------------------
# Pull-through cache: base images come through your own ECR (no Docker Hub rate limits)
#   <registry>/ecr-public/docker/library/maven:...  ->  public.ecr.aws/docker/library/maven:...
#   <registry>/docker-hub/library/...               ->  registry-1.docker.io/library/...
# ---------------------------------------------------------------------------------------------
resource "aws_ecr_pull_through_cache_rule" "ecr_public" {
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}

resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  count                 = var.enable_docker_hub_pull_through ? 1 : 0
  ecr_repository_prefix = "docker-hub"
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = aws_secretsmanager_secret.docker_hub[0].arn
}

# Settings for the repositories ECR creates automatically on the first pull through the cache
resource "aws_ecr_repository_creation_template" "pull_through" {
  for_each             = toset(local.pull_through_prefixes)
  prefix               = each.key
  description          = "Repositories created by the ${each.key} pull-through cache"
  applied_for          = ["PULL_THROUGH_CACHE"]
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 20 most recent cached base images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 20 }
      action       = { type = "expire" }
    }]
  })
}
