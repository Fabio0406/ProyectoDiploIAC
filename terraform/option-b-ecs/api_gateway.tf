# ── VPC Link (puente entre API Gateway y el ALB interno) ─────────────────────
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project_name}-vpc-link"
  security_group_ids = [aws_security_group.api_gateway.id]
  subnet_ids         = aws_subnet.public[*].id

  tags = { Name = "${var.project_name}-vpc-link" }
}

# ── API Gateway HTTP API ──────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "Punto de entrada publico hacia el microservicio accounts"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = { Name = "${var.project_name}-api" }
}

# ── Integración: API GW → ALB interno via VPC Link ───────────────────────────
resource "aws_apigatewayv2_integration" "accounts" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = aws_lb_listener.http.arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

# ── Ruta catch-all: reenvía todo al ALB ──────────────────────────────────────
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.accounts.id}"
}

# ── Stage (auto-deploy activa el gateway inmediatamente) ─────────────────────
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = { Name = "${var.project_name}-api-stage" }
}
