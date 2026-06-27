resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  ecr_registry = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  accounts_image     = "${aws_ecr_repository.accounts.repository_url}:${var.image_tag}"
  transactions_image = "${aws_ecr_repository.transactions.repository_url}:${var.image_tag}"
  alerts_image       = "${aws_ecr_repository.alerts.repository_url}:${var.image_tag}"

  nats_dns_url = "nats://nats.${aws_service_discovery_private_dns_namespace.main.name}:4222"
  db_url       = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.main.address}:5432/bancadb"
}

# ── NATS ─────────────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "nats" {
  family                   = "${var.project_name}-nats"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "nats"
    image     = "nats:2.10-alpine"
    essential = true
    command   = ["-js", "-m", "8222"]
    portMappings = [
      { containerPort = 4222, protocol = "tcp" },
      { containerPort = 8222, protocol = "tcp" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.nats.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "nats"
      }
    }
  }])
}

resource "aws_ecs_service" "nats" {
  name            = "nats"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nats.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.nats.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.nats.arn
  }
}

# ── accounts (HTTP, detrás del ALB) ─────────────────────────────────────────
resource "aws_ecs_task_definition" "accounts" {
  family                   = "${var.project_name}-accounts"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "accounts"
    image     = local.accounts_image
    essential = true
    portMappings = [
      { containerPort = 3000, protocol = "tcp" }
    ]
    environment = [
      { name = "NATS_URL",            value = local.nats_dns_url },
      { name = "DATABASE_URL",        value = local.db_url },
      { name = "ACCOUNTS_HTTP_PORT",  value = "3000" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.accounts.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "accounts"
      }
    }
  }])
}

resource "aws_ecs_service" "accounts" {
  name            = "accounts"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.accounts.arn
  desired_count   = var.accounts_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.accounts.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.accounts.arn
    container_name   = "accounts"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.accounts.arn
  }

  depends_on = [aws_lb_listener.http]
}

# ── transactions (worker NATS) ───────────────────────────────────────────────
resource "aws_ecs_task_definition" "transactions" {
  family                   = "${var.project_name}-transactions"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "transactions"
    image     = local.transactions_image
    essential = true
    environment = [
      { name = "NATS_URL",     value = local.nats_dns_url },
      { name = "DATABASE_URL", value = local.db_url }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.transactions.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "transactions"
      }
    }
  }])
}

resource "aws_ecs_service" "transactions" {
  name            = "transactions"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.transactions.arn
  desired_count   = var.transactions_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.transactions.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.transactions.arn
  }
}

# ── alerts (worker NATS) ──────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "alerts" {
  family                   = "${var.project_name}-alerts"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([{
    name      = "alerts"
    image     = local.alerts_image
    essential = true
    environment = [
      { name = "NATS_URL", value = local.nats_dns_url }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.alerts.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "alerts"
      }
    }
  }])
}

resource "aws_ecs_service" "alerts" {
  name            = "alerts"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.alerts.arn
  desired_count   = var.alerts_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.alerts.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.alerts.arn
  }
}
