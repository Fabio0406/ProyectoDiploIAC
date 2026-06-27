output "alb_dns_name" {
  description = "URL pública del ALB — usar esta en el frontend"
  value       = aws_lb.main.dns_name
}

output "ecr_accounts_url" {
  description = "URL del repo ECR para accounts"
  value       = aws_ecr_repository.accounts.repository_url
}

output "ecr_transactions_url" {
  description = "URL del repo ECR para transactions"
  value       = aws_ecr_repository.transactions.repository_url
}

output "ecr_alerts_url" {
  description = "URL del repo ECR para alerts"
  value       = aws_ecr_repository.alerts.repository_url
}

output "ecr_login_command" {
  description = "Comando para autenticar Docker contra ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.ecr_registry}"
}

output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "rds_endpoint" {
  description = "Endpoint del RDS PostgreSQL"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "service_discovery_namespace" {
  description = "Namespace DNS interno (Cloud Map)"
  value       = aws_service_discovery_private_dns_namespace.main.name
}
