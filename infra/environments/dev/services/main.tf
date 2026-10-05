# dev/services — ECS Fargate cluster + the analyzer-service. Apply order: after dev/edge.
# Kept simple on purpose: one task in a public subnet with a public IP, no load balancer.
# The shared pipeline (DeployDev) updates the service with each new image through the deploy role.

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project}/${var.environment}/network/vpc-id"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/${var.project}/${var.environment}/network/public-subnet-ids"
}

locals {
  name        = "${var.project}-${var.environment}"
  service_ref = "${local.name}-${var.service_name}"
  subnet_ids  = split(",", data.aws_ssm_parameter.public_subnet_ids.insecure_value)
}

# ---------------------------------------------------------------------------------------------
# Cluster and logs
# ---------------------------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "service" {
  #checkov:skip=CKV_AWS_158:Dev container logs use CloudWatch default encryption
  #checkov:skip=CKV_AWS_338:Dev logs are kept for var.log_retention_days to control cost
  name              = "/ecs/${local.service_ref}"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------------------------
# IAM: execution role (ECS agent: pull image, write logs) and task role (the application itself).
# Names match the deploy role's iam:PassRole pattern <project>-<env>-*.
# ---------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.service_ref}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

# Includes ECR pull for any repository the account may read: the shared account's repo policy
# grants this account pull access to <project>/<service>
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# No permissions yet; add policies here when the application calls AWS services
resource "aws_iam_role" "task" {
  name               = "${local.service_ref}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

# ---------------------------------------------------------------------------------------------
# Network access: application port from allowed CIDRs only; actuator port stays private
# ---------------------------------------------------------------------------------------------
resource "aws_security_group" "service" {
  name        = local.service_ref
  description = "${var.service_name}: application port in, HTTPS out"
  vpc_id      = data.aws_ssm_parameter.vpc_id.insecure_value

  tags = {
    Name = local.service_ref
  }
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each          = toset(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.service.id
  description       = "Application port"
  ip_protocol       = "tcp"
  from_port         = var.container_port
  to_port           = var.container_port
  cidr_ipv4         = each.key
}

# ECR, S3 (image layers) and CloudWatch Logs are all reached over HTTPS
resource "aws_vpc_security_group_egress_rule" "https" {
  #checkov:skip=CKV_AWS_382:Tasks have no NAT or VPC endpoints; ECR, S3 and CloudWatch are reached over public HTTPS
  security_group_id = aws_security_group.service.id
  description       = "HTTPS to AWS APIs"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------------------------
# Task definition. The pipeline registers new revisions (same settings, new image) on each deploy.
# ---------------------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "service" {
  #checkov:skip=CKV_AWS_336:Spring Boot writes to /tmp; Fargate has no tmpfs mounts for a read-only root
  family                   = local.service_ref
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = var.service_name # must match CONTAINER_NAME in package-publish (imagedefinitions.json)
    image     = var.initial_image
    essential = true
    portMappings = [
      { containerPort = var.container_port, protocol = "tcp" },
      { containerPort = var.management_port, protocol = "tcp" },
    ]
    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = var.environment },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.service.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = var.service_name
      }
    }
    # No container healthCheck yet: the placeholder image has no actuator, and the pipeline copies
    # this definition on every deploy. Add one (curl :8081/actuator/health) once the real image runs.
  }])
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------------------------
# Service: public IP, rolls back automatically if new tasks fail to start
# ---------------------------------------------------------------------------------------------
resource "aws_ecs_service" "service" {
  #checkov:skip=CKV_AWS_333:Dev test setup without a load balancer; the task needs a public IP (ingress limited by allowed_ingress_cidrs)
  name                   = var.service_name
  cluster                = aws_ecs_cluster.this.id
  task_definition        = aws_ecs_task_definition.service.arn
  desired_count          = var.desired_count
  launch_type            = "FARGATE"
  platform_version       = "LATEST"
  propagate_tags         = "SERVICE"
  enable_execute_command = false

  network_configuration {
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # The pipeline owns the running task definition (new image per deploy). Without this,
  # every terraform apply would roll the service back to the placeholder image.
  lifecycle {
    ignore_changes = [task_definition]
  }
}
