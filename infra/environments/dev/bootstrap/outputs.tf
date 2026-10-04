# Outputs consumed by later layers
output "state_bucket_name" {
  value = module.state-backend.bucket_name
}

output "state_bucket_id" {
  value = module.state-backend.bucket_id
}

output "state_bucket_arn" {
  value = module.state-backend.bucket_arn
}