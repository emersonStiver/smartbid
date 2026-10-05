# Outputs other layers need from the codebuild-project module
output "name" {
  value = aws_codebuild_project.this.name
}

output "arn" {
  value = aws_codebuild_project.this.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
