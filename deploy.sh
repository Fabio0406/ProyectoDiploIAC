#!/usr/bin/env bash
#
# deploy.sh — Deploy end-to-end de Banca Simplificada (Grupo 8).
#
# Flujo:
#   1. Pre-flight checks (CLIs, credenciales)
#   2. terraform init + apply  → crea infraestructura en AWS
#   3. Build de imágenes Docker (accounts, transactions, alerts)
#   4. Push a ECR
#   5. Force redeploy en ECS
#
# Uso:
#   chmod +x deploy.sh
#   ./deploy.sh

set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  C_GREEN="$(tput setaf 2)"; C_YELLOW="$(tput setaf 3)"
  C_RED="$(tput setaf 1)";   C_BLUE="$(tput setaf 4)"; C_RESET="$(tput sgr0)"
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_RESET=""
fi

step() { printf "\n${C_BLUE}[%s]${C_RESET} %s\n" "$1" "$2"; }
ok()   { printf "${C_GREEN}  OK${C_RESET} %s\n" "$1"; }
warn() { printf "${C_YELLOW}  !!${C_RESET} %s\n" "$1"; }
die()  { printf "${C_RED}ERROR: %s${C_RESET}\n" "$1" >&2; exit 1; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$PROJECT_ROOT/terraform/option-b-ecs"

# =========================================================
# Paso 1 — Pre-flight checks
# =========================================================
step "1/5" "Pre-flight checks"

for bin in terraform aws docker; do
  command -v "$bin" >/dev/null 2>&1 || die "Falta '$bin' en el PATH."
done
ok "CLIs disponibles: terraform, aws, docker"

docker info >/dev/null 2>&1 || die "Docker no está corriendo. Inicialo antes de continuar."
ok "Docker corriendo"

[[ -d "$TF_DIR" ]] || die "No encuentro el directorio Terraform: $TF_DIR"
[[ -f "$TF_DIR/terraform.tfvars" ]] || die "Falta terraform.tfvars en $TF_DIR. Copiá terraform.tfvars.example y completalo con tus credenciales."

aws sts get-caller-identity >/dev/null 2>&1 || die "Credenciales AWS inválidas. Ejecutá 'aws configure'."
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ok "Cuenta AWS autenticada: $ACCOUNT_ID"

AWS_REGION="$(aws configure get region 2>/dev/null || echo us-east-1)"
ok "Región: $AWS_REGION"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# =========================================================
# Paso 2 — Terraform
# =========================================================
step "2/5" "Terraform init + apply"

pushd "$TF_DIR" >/dev/null
terraform init -input=false
terraform apply -auto-approve -input=false
ok "Infraestructura creada"

CLUSTER_NAME="$(terraform output -raw cluster_name)"
API_URL="$(terraform output -raw api_gateway_url)"
popd >/dev/null

# =========================================================
# Paso 3 — Build de imágenes Docker
# =========================================================
step "3/5" "Build de imágenes Docker"

cd "$PROJECT_ROOT"

for svc in accounts transactions alerts; do
  echo "  Building $svc..."
  docker build -t "banca-g8/${svc}:latest" -f "apps/${svc}/Dockerfile" . \
    || die "Falló el build de $svc"
  ok "Build $svc completado"
done

# =========================================================
# Paso 4 — Push a ECR
# =========================================================
step "4/5" "Push a ECR"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"
ok "Login a ECR exitoso"

for svc in accounts transactions alerts; do
  REMOTE_TAG="${ECR_REGISTRY}/banca-g8/${svc}:latest"
  docker tag "banca-g8/${svc}:latest" "$REMOTE_TAG"
  echo "  Pushing $svc..."
  docker push "$REMOTE_TAG"
  ok "Push $svc completado → $REMOTE_TAG"
done

# =========================================================
# Paso 5 — Force redeploy en ECS
# =========================================================
step "5/5" "Force redeploy en ECS"

for svc in accounts transactions alerts; do
  aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$svc" \
    --force-new-deployment \
    --region "$AWS_REGION" \
    --output text --query 'service.serviceName' | xargs -I{} echo "  Redeploy iniciado: {}"
done

ok "Todos los servicios actualizados"

# ── Resumen ──────────────────────────────────────────────────────────────────
cat <<EOF

${C_GREEN}========================================${C_RESET}
${C_GREEN} Deploy completado — Grupo 8${C_RESET}
${C_GREEN}========================================${C_RESET}

  API Gateway URL: ${C_YELLOW}${API_URL}${C_RESET}

  Probar:
    curl ${API_URL}/accounts
    curl -X POST ${API_URL}/accounts/transfer ...

  Ver logs en CloudWatch:
    /banca-g8/accounts
    /banca-g8/transactions
    /banca-g8/alerts

EOF