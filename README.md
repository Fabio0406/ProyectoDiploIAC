# Sistema Bancario — Microservicios con NestJS + NATS + PostgreSQL

Tres microservicios NestJS que implementan un sistema bancario simplificado: gestión de cuentas, procesamiento atómico de transferencias y alertas. Se comunican vía NATS, persisten en PostgreSQL, se contenedorizan con Docker y se despliegan en AWS con Terraform.

| Nivel | Descripción | Herramienta |
|---|---|---|
| **1. Local — desarrollo** | Apps en Node con hot-reload, infra en Docker. | `docker-compose.yml` (NATS + PostgreSQL) + `npm run start:*` |
| **2. Local — producción** | Stack completo en contenedores. | `docker-compose.prod.yml` |
| **3. AWS — producción** | VPC, ECS Fargate, ALB, RDS, ECR, Cloud Map. | `terraform/option-b-ecs/` |

---

## 1. Arquitectura

```
   REST                ┌──────────────────────┐
   ──────────────────► │   accounts (HTTP)    │
   GET/POST/PUT/DELETE │   :3000              │
   /accounts           │                      │
   POST /accounts/     │  1. valida cuentas   │
        transfer       │  2. publica evento   │
                       └──────────┬───────────┘
                                  │ transfer.requested
                                  ▼
                       ┌──────────────────────┐
                       │    NATS broker       │
                       └──────┬───────┬───────┘
                              │       │
               transfer.      │       │ transfer.requested
               completed /    │       ▼
               transfer.      │  ┌────────────────────┐
               failed         │  │   transactions     │  ── SELECT FOR UPDATE
                              │  │   (NATS only)      │  ── valida saldo
                              │  │                    │  ── actualiza balances
                              │  │                    │  ── guarda registro
                              │  └────────────────────┘
                              │       │ transfer.completed
                              │       │ transfer.failed
                              │       ▼
                              │  ┌────────────────────┐
                              └─►│   alerts           │
                                 │   (NATS only)      │  ── log de alertas
                                 │                    │  ── alerta si >= $10.000
                                 └────────────────────┘
```

| Microservicio    | Responsabilidad | Expone |
|---|---|---|
| `accounts`       | CRUD de cuentas. Inicia transferencias publicando un evento en NATS. | HTTP :3000 |
| `transactions`   | Escucha `transfer.requested`. Procesa la transferencia de forma atómica (locking pesimista, transacción DB). Publica resultado. | NATS only |
| `alerts`         | Escucha `transfer.completed` y `transfer.failed`. Registra logs y emite alertas para transferencias >= $10.000. | NATS only |

**Patrones utilizados:**

- **Event Pattern (`emit` / `@EventPattern`)**: publish/subscribe, _fire & forget_. `accounts` dispara `transfer.requested` sin esperar respuesta.
- **Locking pesimista**: `transactions` hace `SELECT ... FOR UPDATE` para evitar condiciones de carrera.
- **ACID**: la transferencia (débito + crédito + registro) ocurre dentro de una sola transacción DB con rollback automático ante cualquier error.
- **Auditoría**: las transferencias fallidas se registran en `transfer_records` con el motivo del fallo, incluso después del rollback.
- **Contratos compartidos** (`@app/contracts`): un único lugar para los nombres de los eventos y los tipos de payload.

---

## 2. Estructura del proyecto

```
.
├── apps/
│   ├── accounts/                   ← Microservicio 1 (HTTP + cliente NATS)
│   │   ├── src/
│   │   │   ├── main.ts
│   │   │   ├── app.module.ts       ← TypeORM + cliente NATS
│   │   │   ├── accounts.module.ts
│   │   │   ├── accounts.controller.ts
│   │   │   ├── accounts.service.ts
│   │   │   ├── account.entity.ts   ← tabla `accounts`
│   │   │   └── account.dto.ts
│   │   └── Dockerfile
│   ├── transactions/               ← Microservicio 2 (NATS puro)
│   │   ├── src/
│   │   │   ├── main.ts
│   │   │   ├── app.module.ts
│   │   │   ├── transactions.module.ts
│   │   │   ├── transactions.controller.ts  ← @EventPattern
│   │   │   ├── transactions.service.ts     ← lógica atómica
│   │   │   └── transfer-record.entity.ts  ← tabla `transfer_records`
│   │   └── Dockerfile
│   └── alerts/                     ← Microservicio 3 (NATS puro, sin DB)
│       ├── src/
│       │   ├── main.ts
│       │   ├── app.module.ts
│       │   ├── alerts.module.ts
│       │   ├── alerts.controller.ts  ← @EventPattern
│       │   └── alerts.service.ts
│       └── Dockerfile
│
├── libs/
│   └── contracts/                  ← Tipos y constantes compartidas (@app/contracts)
│       └── src/
│           ├── index.ts
│           ├── nats.constants.ts   ← NATS_SERVICE, DEFAULT_NATS_URL
│           └── banking.contracts.ts ← nombres de eventos + interfaces de payload
│
├── terraform/
│   └── option-b-ecs/               ← Nivel 3: AWS ECS Fargate
│       ├── providers.tf
│       ├── variables.tf
│       ├── network.tf
│       ├── security_groups.tf
│       ├── ecr.tf
│       ├── iam.tf
│       ├── ecs.tf
│       ├── rds.tf
│       ├── alb.tf
│       ├── service_discovery.tf
│       ├── api_gateway.tf
│       ├── logs.tf
│       ├── outputs.tf
│       └── README.md
│
├── docker-compose.yml          ← Nivel 1: NATS + PostgreSQL para dev
├── docker-compose.prod.yml     ← Nivel 2: stack completo dockerizado
├── Makefile                    ← atajos para los 3 niveles
├── deploy.sh                   ← pipeline end-to-end Nivel 3
├── destroy.sh                  ← destrucción de infra AWS
└── .env                        ← variables de entorno locales
```

---

## 3. Schema de base de datos

PostgreSQL — tablas creadas automáticamente por TypeORM (`synchronize: true`):

**`accounts`**
```sql
id         UUID PRIMARY KEY DEFAULT gen_random_uuid()
owner      VARCHAR NOT NULL
balance    DECIMAL(12, 2) DEFAULT 0
createdAt  TIMESTAMP DEFAULT NOW()
```

**`transfer_records`**
```sql
id              UUID PRIMARY KEY
transferId      VARCHAR NOT NULL
fromAccountId   VARCHAR NOT NULL
toAccountId     VARCHAR NOT NULL
amount          DECIMAL(12, 2) NOT NULL
status          VARCHAR DEFAULT 'pending'   -- 'completed' | 'failed'
failReason      VARCHAR NULLABLE
processedAt     TIMESTAMP DEFAULT NOW()
```

---

## 4. Nivel 1 — Desarrollo local

Solo NATS y PostgreSQL corren en Docker; las apps corren en Node con hot-reload.

```bash
cp .env.example .env        # ajustar variables si es necesario
npm install
make up                     # arranca NATS + PostgreSQL

# en tres terminales separadas:
npm run start:accounts
npm run start:transactions
npm run start:alerts
```

Probar:

```bash
# Crear cuentas
curl -X POST http://localhost:3000/accounts \
  -H "Content-Type: application/json" \
  -d '{"owner":"alice","balance":5000}'

curl -X POST http://localhost:3000/accounts \
  -H "Content-Type: application/json" \
  -d '{"owner":"bob","balance":1000}'

# Listar cuentas
curl http://localhost:3000/accounts

# Iniciar una transferencia
curl -X POST http://localhost:3000/accounts/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromAccountId":"<uuid-alice>","toAccountId":"<uuid-bob>","amount":200}'
# → {"message":"...", "transferId":"<uuid>", "status":"processing"}

# Consultar una cuenta
curl http://localhost:3000/accounts/<uuid>
```

En la terminal de `transactions` verás la transferencia procesada con locking pesimista.  
En la terminal de `alerts` verás el evento registrado (y alerta si el monto >= $10.000).

Bajar la infra:

```bash
make down
```

---

## 5. Nivel 2 — Stack completo dockerizado

Construye las imágenes de los 3 servicios y levanta todo junto. Sirve para validar los Dockerfiles antes de subir a ECR.

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Las apps resuelven servicios por nombre DNS (`nats://nats:4222`, `postgresql://postgres:5432`), no por `localhost`.

Bajar:

```bash
docker compose -f docker-compose.prod.yml down
```

---

## 6. Nivel 3 — Despliegue en AWS

El despliegue completo está automatizado con [`deploy.sh`](./deploy.sh). La guía detallada de cada recurso AWS vive en [`terraform/option-b-ecs/README.md`](./terraform/option-b-ecs/README.md).

### 6.1. Prerrequisitos

| Herramienta | Para qué |
|---|---|
| **Docker Desktop** | Construir y pushear las imágenes. Debe estar corriendo. |
| **AWS CLI v2** | Login a ECR, force-new-deployment en ECS. |
| **Terraform** ≥ 1.6 | Aprovisionar VPC, ECS, RDS, ALB, etc. |
| **Bash** | Ejecutar `deploy.sh` (Git Bash en Windows). |
| **Cuenta AWS** | Con permisos de admin o equivalentes. |

Instalación rápida en Windows:

```powershell
winget install Docker.DockerDesktop
winget install Amazon.AWSCLI
winget install HashiCorp.Terraform
winget install Git.Git
```

En macOS:

```bash
brew install --cask docker
brew install awscli terraform
```

### 6.2. Configurar credenciales AWS

**Opción A — `aws configure`** (recomendada):

```bash
aws configure
# AWS Access Key ID: ...
# AWS Secret Access Key: ...
# Default region name: us-east-1
# Default output format: json
```

**Opción B — `terraform.tfvars`**:

```bash
cp terraform/option-b-ecs/terraform.tfvars.example terraform/option-b-ecs/terraform.tfvars
# editar y completar access_key / secret_key
```

> `terraform.tfvars` está en `.gitignore`.

### 6.3. Desplegar

**Linux / macOS / WSL / Git Bash:**

```bash
./deploy.sh
```

**Windows (PowerShell):**

```powershell
bash ./deploy.sh
```

El script ejecuta automáticamente:

1. Pre-flight checks (CLIs instaladas, Docker corriendo, credenciales AWS válidas).
2. `terraform init` + `terraform apply -auto-approve`.
3. Login a ECR.
4. `docker build` + `docker push` de los 3 servicios (`--platform linux/amd64`).
5. `aws ecs update-service --force-new-deployment` para cada servicio.
6. Espera a que las tareas queden estables e imprime la URL pública del ALB.

Primera ejecución: **~10-15 min**. Reejecuciones: **~3-5 min**.

### 6.4. Probar el despliegue

```bash
# Crear cuenta
curl -X POST http://<alb_dns_name>/accounts \
  -H "Content-Type: application/json" \
  -d '{"owner":"alice","balance":5000}'

# Iniciar transferencia
curl -X POST http://<alb_dns_name>/accounts/transfer \
  -H "Content-Type: application/json" \
  -d '{"fromAccountId":"<uuid>","toAccountId":"<uuid>","amount":200}'
```

Ver logs en CloudWatch:

```bash
aws logs tail /ecs/banca-g8/accounts      --follow
aws logs tail /ecs/banca-g8/transactions  --follow
aws logs tail /ecs/banca-g8/alerts        --follow
```

### 6.5. Notas para Windows

- Docker Desktop debe estar corriendo antes de ejecutar el script.
- Usar Git Bash o WSL, no CMD ni PowerShell directamente.
- Si Git clonó con CRLF:

  ```bash
  sed -i 's/\r$//' deploy.sh
  ```

### 6.6. Recursos creados en AWS

- **VPC** (`10.0.0.0/16`) con 2 subnets públicas en 2 AZs.
- **ECR** — 3 repositorios: `banca-g8/accounts`, `banca-g8/transactions`, `banca-g8/alerts`.
- **ECS Cluster** con 3 servicios Fargate — 256 CPU / 512 MB por tarea.
- **RDS PostgreSQL 16** — instancia gestionada por AWS.
- **ALB** público en puerto 80 apuntando a `accounts:3000`.
- **Cloud Map** para descubrimiento interno de servicios (`nats.app.internal:4222`).
- **Security Groups** encadenados (least privilege).
- **IAM Role** de ejecución para Fargate (ECR pull + CloudWatch write).
- **CloudWatch Log Groups** por servicio (retención 7 días).

### 6.7. Destruir la infraestructura

```bash
./destroy.sh
# o manualmente:
cd terraform/option-b-ecs && terraform destroy -auto-approve
```

---

## 7. Comandos útiles

### npm

| Comando | Descripción |
|---|---|
| `npm run start:accounts` | Arranca accounts en watch mode |
| `npm run start:transactions` | Arranca transactions en watch mode |
| `npm run start:alerts` | Arranca alerts en watch mode |
| `npm run build:accounts` / `build:transactions` / `build:alerts` | Compila con `nest build` |
| `npm run lint` / `npm run format` | ESLint (con fix) y Prettier |
| `npm test` | Suite de Jest |

### Makefile

Ejecutá `make` o `make help` para ver todos los targets.

| Target | Descripción |
|---|---|
| `make up` / `make down` | Nivel 1 — levanta / baja NATS + PostgreSQL |
| `make prod-up` / `make prod-down` | Nivel 2 — stack completo en Docker |
| `make init` / `make plan` / `make apply` | Terraform init / plan / apply |
| `make login` | Login a ECR |
| `make build` / `make push` | Build + push de los 3 servicios a ECR |
| `make redeploy` | ECS force-new-deployment en los 3 servicios |
| `make deploy` | Pipeline completo (`deploy.sh`) |
| `make outputs` | Terraform outputs (ALB DNS, ECR URLs, RDS endpoint) |
| `make services` | `runningCount` / `desiredCount` de ECS |
| `make logs-accounts` / `logs-transactions` / `logs-alerts` / `logs-nats` | CloudWatch logs en vivo |
| `make destroy` | Destruye la infra de AWS |
| `make clean` | Borra imágenes Docker locales |

> En Windows, el `Makefile` usa Git Bash automáticamente. Si Git no está en `C:\Program Files\Git`, ajustá la variable `SHELL` al inicio del archivo.
