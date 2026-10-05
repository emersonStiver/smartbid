# dev/edge — network for the dev workloads. Apply order: 1 (after dev/bootstrap)
# Public subnets only: ECS tasks get a public IP, so no NAT gateway (~$32/month) or VPC endpoints are needed.
# The services stack reads the IDs from SSM: /<project>/<env>/network/*

locals {
  name = "${var.project}-${var.environment}"
  azs  = var.availability_zones
}

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:VPC flow logs left out of dev to control cost; enable for prod
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = local.name
  }
}

# Lock down the default security group so nothing uses it by accident
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-default-do-not-use"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = local.name
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false # ECS assigns public IPs per task (assign_public_ip)

  tags = {
    Name = "${local.name}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name}-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Contract with the services stack
resource "aws_ssm_parameter" "vpc_id" {
  #checkov:skip=CKV2_AWS_34:Resource IDs are not secrets
  name  = "/${var.project}/${var.environment}/network/vpc-id"
  type  = "String"
  value = aws_vpc.this.id
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  #checkov:skip=CKV2_AWS_34:Resource IDs are not secrets
  name  = "/${var.project}/${var.environment}/network/public-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.public[*].id)
}
