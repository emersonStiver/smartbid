# Non-secret values for dev/network (committed). Secrets go in Secrets Manager/SSM.
environment = "dev"
account_id  = "897744508036"
stack       = "edge"
project     = "smartbid"

vpc_cidr            = "10.20.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.20.0.0/24", "10.20.1.0/24"]
