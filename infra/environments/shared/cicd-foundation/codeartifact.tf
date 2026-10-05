# Optional (enable_codeartifact): a private proxy for npm / PyPI / Maven dependencies.
# A CodeArtifact repository can have only one external connection, so each public registry gets a
# "store" repository and <project>-deps aggregates them as upstreams.

locals {
  codeartifact_stores = var.enable_codeartifact ? {
    npm   = "public:npmjs"
    pypi  = "public:pypi"
    maven = "public:maven-central"
  } : {}
}

resource "aws_codeartifact_domain" "this" {
  count          = var.enable_codeartifact ? 1 : 0
  domain         = var.project
  encryption_key = aws_kms_key.artifacts.arn
}

resource "aws_codeartifact_repository" "store" {
  for_each   = local.codeartifact_stores
  repository = "${each.key}-store"
  domain     = aws_codeartifact_domain.this[0].domain

  external_connections {
    external_connection_name = each.value
  }
}

resource "aws_codeartifact_repository" "deps" {
  count      = var.enable_codeartifact ? 1 : 0
  repository = "${var.project}-deps"
  domain     = aws_codeartifact_domain.this[0].domain

  dynamic "upstream" {
    for_each = aws_codeartifact_repository.store
    content {
      repository_name = upstream.value.repository
    }
  }
}
