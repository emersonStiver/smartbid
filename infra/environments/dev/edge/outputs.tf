# Outputs consumed by later layers (also published to SSM for the services stack)
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
