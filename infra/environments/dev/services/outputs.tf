# Outputs consumed by later layers
output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.service.name
}

output "find_public_ip" {
  description = "The task's public IP changes on every deployment; this command prints the current one"
  value       = <<-EOT
    TASK=$(aws ecs list-tasks --cluster ${aws_ecs_cluster.this.name} --service-name ${aws_ecs_service.service.name} --query 'taskArns[0]' --output text --profile dev)
    ENI=$(aws ecs describe-tasks --cluster ${aws_ecs_cluster.this.name} --tasks $TASK --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text --profile dev)
    aws ec2 describe-network-interfaces --network-interface-ids $ENI --query 'NetworkInterfaces[0].Association.PublicIp' --output text --profile dev
  EOT
}
