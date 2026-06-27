resource "aws_cloudwatch_log_group" "nats" {
  name              = "/ecs/${var.project_name}/nats"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "accounts" {
  name              = "/ecs/${var.project_name}/accounts"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "transactions" {
  name              = "/ecs/${var.project_name}/transactions"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "alerts" {
  name              = "/ecs/${var.project_name}/alerts"
  retention_in_days = 7
}
