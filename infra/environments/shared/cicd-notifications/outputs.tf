output "sns_topic_arn" {
  value = aws_sns_topic.cicd.arn
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.cicd.dashboard_name
}
