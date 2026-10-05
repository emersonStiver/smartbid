# GitHub connection used by CodeBuild (webhook projects) and CodePipeline (Source stage).
# Created in PENDING status: finish the handshake once in the console (see README.md).
resource "aws_codeconnections_connection" "github" {
  name          = "${var.project}-github"
  provider_type = "GitHub"

  lifecycle {
    prevent_destroy = true
  }
}
