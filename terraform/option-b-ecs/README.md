# Banca Simplificada (Grupo 8) — Infraestructura como Código

Despliegue en **AWS ECS Fargate** de los 3 microservicios del caso de uso "Banca Simplificada" (`accounts`, `transactions`, `alerts`), el broker **NATS** y una base de datos **RDS PostgreSQL**, todo definido con Terraform.

Proyecto adaptado de la plantilla de referencia `test_nest` (que usaba `orders`/`notifications` + Redis) al dominio bancario, reemplazando ElastiCache por RDS PostgreSQL y agregando una capa de **API Gateway** delante del ALB interno.

## Arquitectura desplegada

```
                              Internet
                                  │
                                  ▼
                  ┌───────────────────────────┐
                  │   API Gateway (HTTP API)  │  ← público
                  │   $default stage          │
                  └─────────────┬─────────────┘
                                │  VPC Link
                                ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                     VPC 10.0.0.0/16                          │
   │                                                                │
   │   Subnet pública AZ-a              Subnet pública AZ-b        │
   │                                                                │
   │            ┌──────────────────────────┐                       │
   │            │  ALB interno (puerto 80) │  ← solo desde VPC Link │
   │            └────────────┬─────────────┘                       │
   │                         │ :3000                                │
   │                         ▼                                      │
   │              ┌──────────────────┐                              │
   │              │  accounts task   │  HTTP + publica a NATS       │
   │              │   (Fargate)      │                              │
   │              └───┬──────────┬───┘                              │
   │                  │          │                                  │
   │        ┌─────────┘          └─────────┐                        │
   │        ▼                              ▼                        │
   │  ┌─────────────┐              ┌───────────────┐                │
   │  │ RDS Postgres│              │  NATS (Fargate)│               │
   │  │ (bancadb)   │◄─────────────┤ nats.app.internal              │
   │  └──────▲──────┘              └───────┬────────┘                │
   │         │                             │                        │
   │         │                    ┌────────┴────────┐               │
   │         │                    ▼                 ▼               │
   │         │           ┌────────────────┐ ┌───────────────┐       │
   │         └───────────┤ transactions   │ │    alerts     │       │
   │                      │   (worker)    │ │   (worker)    │       │
   │                      └────────────────┘ └───────────────┘       │
   └──────────────────────────────────────────────────────────────┘
                                  │
                                  └──► CloudWatch Logs
                                  └──► ECR (accounts, transactions, alerts)
                                  └──► Cloud Map (DNS interno app.internal)
```

**Flujo de eventos NATS:** `transfer.requested` → `transactions` → `transfer.completed` / `transfer.failed` → `alerts`

**Patrón de comunicación:**
- Síncrono (HTTP): Internet → API Gateway → VPC Link → ALB interno → `accounts`
- Asíncrono (eventos): `accounts` → NATS → `transactions` → NATS → `alerts`
- Descubrimiento interno: todo por DNS de Cloud Map (`*.app.internal`), nunca por IP hardcodeada

## Recursos creados (por archivo)

| Archivo | Recursos AWS |
|---|---|
| `providers.tf` | Provider AWS (`~> 5.60`), tags por defecto (`Project`, `ManagedBy`, `Course`) |
| `variables.tf` | Variables de región, credenciales, red, ECS/Fargate (`task_cpu`, `task_memory`, `*_desired_count`) y RDS (`db_instance_class`, `db_username`, `db_password`) |
| `network.tf` | VPC `10.0.0.0/16`, 2 subnets públicas (una por AZ), Internet Gateway, route table |
| `security_groups.tf` | 7 SGs encadenados: `api_gateway` → `alb` → `accounts` → `nats`/`rds` ← `transactions`/`alerts` |
| `ecr.tf` | 3 repositorios ECR (`banca-g8/accounts`, `/transactions`, `/alerts`) + lifecycle policy (máx. 10 imágenes) |
| `iam.tf` | Rol de ejecución de tareas (`AmazonECSTaskExecutionRolePolicy`) |
| `service_discovery.tf` | Namespace privado `app.internal` + 4 servicios Cloud Map (nats / accounts / transactions / alerts) |
| `alb.tf` | ALB **interno**, target group `ip:3000` para `accounts`, listener HTTP:80 con health check `/accounts/health` |
| `api_gateway.tf` | API Gateway HTTP API público, VPC Link hacia el ALB interno, ruta catch-all (`$default`), CORS abierto |
| `rds.tf` | Subnet group + instancia RDS PostgreSQL 16.3 (`bancadb`), no accesible públicamente |
| `logs.tf` | 4 log groups CloudWatch (`/ecs/banca-g8/{nats,accounts,transactions,alerts}`, retención 7 días) |
| `ecs.tf` | Cluster `banca-g8-cluster`, 4 task definitions Fargate (nats + 3 microservicios), 4 services |
| `outputs.tf` | URL pública del API Gateway, DNS del ALB (referencia interna), URLs de ECR, comando de login a ECR, nombre del cluster, endpoint RDS (sensitive), namespace de Cloud Map |

## Prerrequisitos

- **Terraform ≥ 1.6**
- **AWS CLI** configurada con permisos suficientes (ECS, ECR, RDS, API Gateway, IAM, VPC, Cloud Map, CloudWatch)
- **Docker** local para construir y empujar imágenes (con soporte `--platform linux/amd64` si trabajás en Apple Silicon / Windows ARM)
- Cuenta AWS con límites de Fargate y RDS disponibles en la región elegida

## ⚠️ Antes de empezar: credenciales

Este proyecto **no** debe versionar credenciales. `terraform.tfvars` está en `.gitignore` (ver más abajo) y nunca debe subirse a GitHub. Copiá el ejemplo y completá tus propios valores:

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
# terraform.tfvars (NO subir a git)
aws_region = "us-east-1"

access_key = "TU_ACCESS_KEY"
secret_key = "TU_SECRET_KEY"

project_name = "banca-g8"
image_tag    = "latest"

db_username = "bancaadmin"
db_password = "una-password-segura"
```

> Recomendado: en vez de `access_key`/`secret_key` en el archivo, usar variables de entorno (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) o el perfil de `aws configure`, y quitar esas dos variables del provider.

## Flujo de despliegue (paso a paso)

### 1. Crear la infraestructura

```bash
terraform init
terraform plan
terraform apply
```

Al terminar verás los outputs definidos en `outputs.tf`, entre ellos:

```
api_gateway_url   = "https://abc123xyz.execute-api.us-east-1.amazonaws.com"
alb_dns_name      = "banca-g8-alb-123456.us-east-1.elb.amazonaws.com"   # interno, solo referencia
ecr_accounts_url  = "925181413822.dkr.ecr.us-east-1.amazonaws.com/banca-g8/accounts"
ecr_transactions_url = "925181413822.dkr.ecr.us-east-1.amazonaws.com/banca-g8/transactions"
ecr_alerts_url    = "925181413822.dkr.ecr.us-east-1.amazonaws.com/banca-g8/alerts"
ecr_login_command = "aws ecr get-login-password --region us-east-1 | docker login ..."
cluster_name      = "banca-g8-cluster"
service_discovery_namespace = "app.internal"
```

> En este punto los servicios `accounts`, `transactions` y `alerts` arrancan pero **fallan** porque todavía no hay imágenes en ECR. Es esperable.
>
> RDS puede tardar **5-10 minutos** en estar disponible. Terraform espera; tené paciencia con el primer apply.

### 2. Construir y subir las imágenes

Ejecutar desde la **raíz del monorepo NestJS** (no desde `terraform/`), porque el build necesita `libs/contracts` en el contexto:

```bash
# Login a ECR (copiá el comando del output ecr_login_command)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# accounts
docker build --platform linux/amd64 -f apps/accounts/Dockerfile \
  -t <ecr_accounts_url>:latest .
docker push <ecr_accounts_url>:latest

# transactions
docker build --platform linux/amd64 -f apps/transactions/Dockerfile \
  -t <ecr_transactions_url>:latest .
docker push <ecr_transactions_url>:latest

# alerts
docker build --platform linux/amd64 -f apps/alerts/Dockerfile \
  -t <ecr_alerts_url>:latest .
docker push <ecr_alerts_url>:latest
```

> En Windows, usar **Git Bash** para estos comandos: el pipe con `aws ecr get-login-password | docker login` no funciona igual en PowerShell.

### 3. Forzar redeploy de los servicios ECS

```bash
aws ecs update-service --cluster banca-g8-cluster --service accounts     --force-new-deployment
aws ecs update-service --cluster banca-g8-cluster --service transactions --force-new-deployment
aws ecs update-service --cluster banca-g8-cluster --service alerts       --force-new-deployment
```

### 4. Probar end-to-end

```bash
# Crear una cuenta
curl -X POST https://<api_gateway_url>/accounts \
  -H "Content-Type: application/json" \
  -d '{"titular":"ana","saldo":500}'

# Iniciar una transferencia: accounts publica transfer.requested en NATS
curl -X POST https://<api_gateway_url>/accounts/transfer \
  -H "Content-Type: application/json" \
  -d '{"origen":"<id-cuenta-origen>","destino":"<id-cuenta-destino>","monto":100}'
```

En Windows/PowerShell usar `Invoke-RestMethod` en vez de `curl`.

### 5. Ver logs

```bash
aws logs tail /ecs/banca-g8/accounts     --follow
aws logs tail /ecs/banca-g8/transactions --follow
aws logs tail /ecs/banca-g8/alerts       --follow
aws logs tail /ecs/banca-g8/nats         --follow
```

## Desarrollo local (antes de desplegar a AWS)

```bash
docker-compose up
```

Levanta NATS + PostgreSQL localmente para probar los 3 microservicios sin necesidad de AWS.

## Limpieza

```bash
terraform destroy
```

> ⚠️ ECR no elimina repos con imágenes — los repos ya tienen `force_delete = true`, así que no debería trabarse. Si falla igual, vaciá las imágenes manualmente antes.
>
> RDS también tarda algunos minutos en destruirse. `skip_final_snapshot = true` evita que pida un snapshot final.

## Conceptos clave del diseño

1. **API Gateway + VPC Link delante del ALB interno**: el ALB ya no es público (`internal = true`); solo el API Gateway lo es. Esto responde al feedback de que `accounts` no debía recibir tráfico HTTP directamente sin una capa de gateway pública.
2. **`awsvpc` network mode**: cada tarea Fargate tiene su propia ENI con IP; por eso el target group del ALB es `type = "ip"`.
3. **Cloud Map vs ALB**: el tráfico este-oeste entre microservicios (accounts → NATS → transactions → NATS → alerts) usa DNS interno (`*.app.internal`); el ALB es solo para tráfico norte-sur (API Gateway → accounts).
4. **RDS en vez de Redis**: se reemplazó ElastiCache por RDS PostgreSQL porque el dominio bancario necesita integridad transaccional y consistencia de saldo, no solo un caché clave-valor.
5. **Encadenamiento de Security Groups**: las reglas referencian otros SGs (`referenced_security_group_id`) en vez de CIDRs — mínimo privilegio real: `transactions` y `alerts` no aceptan ningún ingreso directo (son workers puros de NATS), y RDS solo acepta desde `accounts` y `transactions`.
6. **Sin NAT Gateway**: las tareas están en subnets públicas para evitar el costo de un NAT Gateway; RDS no tiene IP pública (`publicly_accessible = false`) aunque esté en una subnet pública, así que solo es alcanzable desde dentro de la VPC.
7. **Secretos**: `access_key`, `secret_key`, `db_username` y `db_password` están marcados `sensitive = true` en `variables.tf`. Aun así, **el state de Terraform los guarda en texto plano** — por eso `terraform.tfstate*` nunca debe subirse a git (ver `.gitignore`).

## Seguridad: qué NO subir a GitHub

Este repo incluye (o debería incluir) un `.gitignore` con al menos:

```gitignore
terraform.tfvars
*.tfvars
!terraform.tfvars.example

*.tfstate
*.tfstate.*
.terraform/
```

`terraform.tfvars` contiene las credenciales de AWS y la password de RDS en texto plano. El `terraform.tfstate` guarda esos mismos secretos como atributos de recursos (por ejemplo, `password` de `aws_db_instance`), aunque las variables estén marcadas `sensitive`. Si alguno de estos archivos ya se subió a git, hay que reescribir el historial (no alcanza con un commit nuevo) y **rotar inmediatamente** las credenciales expuestas en IAM y la password de RDS.
