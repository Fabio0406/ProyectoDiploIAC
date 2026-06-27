# ── ALB ──────────────────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Permite HTTP entrante desde internet hacia el ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# ── accounts (único servicio HTTP, expuesto detrás del ALB) ──────────────────
resource "aws_security_group" "accounts" {
  name        = "${var.project_name}-accounts-sg"
  description = "Permite trafico solo desde el ALB hacia accounts:3000"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP desde ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-accounts-sg" }
}

# ── transactions (worker NATS, sin ingress directo) ───────────────────────────
resource "aws_security_group" "transactions" {
  name        = "${var.project_name}-transactions-sg"
  description = "transactions no acepta entrante: es un worker NATS puro"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-transactions-sg" }
}

# ── alerts (worker NATS, sin ingress directo) ────────────────────────────────
resource "aws_security_group" "alerts" {
  name        = "${var.project_name}-alerts-sg"
  description = "alerts no acepta entrante: es un worker NATS puro"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alerts-sg" }
}

# ── NATS (broker, solo acepta desde los 3 microservicios) ─────────────────────
resource "aws_security_group" "nats" {
  name        = "${var.project_name}-nats-sg"
  description = "Broker NATS: ingreso solo desde accounts, transactions y alerts"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-nats-sg" }
}

# Reglas separadas para evitar dependencias circulares entre SGs
resource "aws_vpc_security_group_ingress_rule" "nats_from_accounts" {
  security_group_id            = aws_security_group.nats.id
  referenced_security_group_id = aws_security_group.accounts.id
  ip_protocol                  = "tcp"
  from_port                    = 4222
  to_port                      = 4222
  description                  = "NATS desde accounts"
}

resource "aws_vpc_security_group_ingress_rule" "nats_from_transactions" {
  security_group_id            = aws_security_group.nats.id
  referenced_security_group_id = aws_security_group.transactions.id
  ip_protocol                  = "tcp"
  from_port                    = 4222
  to_port                      = 4222
  description                  = "NATS desde transactions"
}

resource "aws_vpc_security_group_ingress_rule" "nats_from_alerts" {
  security_group_id            = aws_security_group.nats.id
  referenced_security_group_id = aws_security_group.alerts.id
  ip_protocol                  = "tcp"
  from_port                    = 4222
  to_port                      = 4222
  description                  = "NATS desde alerts"
}

# ── RDS PostgreSQL (solo desde accounts) ──────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS PostgreSQL: ingreso solo desde accounts"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_accounts" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.accounts.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL desde accounts"
}
