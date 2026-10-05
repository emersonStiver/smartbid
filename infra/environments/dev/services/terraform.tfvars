# Non-secret values for dev/services (committed). Secrets go in Secrets Manager/SSM.
account_id  = "897744508036"
environment = "dev"
stack       = "services"
project     = "smartbid"

service_name = "analyzer-service"

# Only used until the pipeline's first DeployDev replaces it with the analyzer-service image
initial_image = "public.ecr.aws/docker/library/nginx:stable-alpine"

container_port  = 8080
management_port = 8081
cpu             = 512
memory          = 1024
desired_count   = 1

# Replace with your public IP for safety, e.g. ["203.0.113.10/32"]
allowed_ingress_cidrs = ["0.0.0.0/0"]

log_retention_days = 14
