#!/usr/bin/env bash
#
# destroy.sh — Destrucción end-to-end de la infraestructura de Banca Simplificada (Grupo 8).
#
# Flujo:
#   1. Pre-flight checks (CLIs, credenciales)
#   2. Confirmación explícita (operación destructiva)
#   3. Vacía repositorios ECR (terraform destroy falla si tienen imágenes)
#   4. terraform destroy -auto-approve
#   5. (Opcional) limpia imágenes Docker locales del proyecto
#
# Uso:
#   chmod +x destroy.sh
#   ./destroy.sh                # pide confirmación
#   ./destroy.sh --yes          # sin confirmación (CI / scripts)
#   ./destroy.sh --keep-local   # no borra imágenes Docker locales

set -euo pipefail

ASSUME_YES=0
KEEP_LOCAL=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)     ASSUME_YES=1 ;;
    --keep-local) KEEP_LOCAL=1 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) echo "Argumento desconocido: $arg" >&2; exit 2 ;;
  esac
done

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
step "1/4" "Pre-flight checks"

for bin in terraform aws; do
  command -v "$bin" >/dev/null 2>&1 || die "Falta '$bin' en el PATH."
done
ok "CLIs disponibles: terraform, aws"

[[ -d "$TF_DIR" ]] || die "No encuentro el directorio Terraform: $TF_DIR"
[[ -f "$TF_DIR/terraform.tfvars" ]] || warn "No hay terraform.tfvars. Asegurate de que las credenciales estén configuradas."

aws sts get-caller-identity >/dev/null 2>&1 || die "Credenciales AWS inválidas. Ejecutá 'aws configure'."
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ok "Cuenta AWS autenticada: $ACCOUNT_ID"

AWS_REGION="$(aws configure get region 2>/dev/null || echo us-east-1)"
ok "Región: $AWS_REGION"

# =========================================================
# Paso 2 — Confirmación
# =========================================================
if [[ $ASSUME_YES -eq 0 ]]; then
  echo
  printf "${C_RED}Esta operación borra TODA la infraestructura en AWS (VPC, ECS, ALB, RDS, ECR e imágenes).${C_RESET}\n"
  printf "Cuenta: ${C_YELLOW}%s${C_RESET}   Región: ${C_YELLOW}%s${C_RESET}\n" "$ACCOUNT_ID" "$AWS_REGION"
  read -r -p "Escribí 'destroy' para confirmar: " REPLY
  [[ "$REPLY" == "destroy" ]] || die "Cancelado."
fi

# =========================================================
# Paso 3 — Vaciar repositorios ECR
# =========================================================
step "2/4" "Vaciando repositorios ECR"

empty_ecr_repo() {
  local repo="$1"
  if ! aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
    warn "Repo '$repo' no existe (ya destruido o nunca creado), salteo."
    return 0
  fi

  local image_ids
  image_ids="$(aws ecr list-images --repository-name "$repo" --region "$AWS_REGION" --query 'imageIds[*]' --output json)"

  if [[ "$image_ids" == "[]" || -z "$image_ids" ]]; then
    ok "Repo '$repo' ya está vacío"
    return 0
  fi

  aws ecr batch-delete-image \
    --repository-name "$repo" \
    --region "$AWS_REGION" \
    --image-ids "$image_ids" >/dev/null
  ok "Repo '$repo' vaciado"
}

empty_ecr_repo "banca-g8/accounts"
empty_ecr_repo "banca-g8/transactions"
empty_ecr_repo "banca-g8/alerts"

# =========================================================
# Paso 4 — terraform destroy
# =========================================================
step "3/4" "terraform destroy"

pushd "$TF_DIR" >/dev/null
terraform init -input=false >/dev/null
terraform destroy -auto-approve -input=false
popd >/dev/null
ok "Recursos AWS destruidos"

# =========================================================
# Paso 5 — Limpieza local
# =========================================================
step "4/4" "Limpieza local"

if [[ $KEEP_LOCAL -eq 1 ]]; then
  warn "Se omite la limpieza de imágenes Docker locales (--keep-local)"
else
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    LOCAL_IMAGES="$(docker images --format '{{.Repository}}:{{.Tag}}' \
      | grep -E "(^${ECR_REGISTRY}/banca-g8/(accounts|transactions|alerts)|^banca-g8/(accounts|transactions|alerts))" || true)"
    if [[ -n "$LOCAL_IMAGES" ]]; then
      echo "$LOCAL_IMAGES" | xargs -r docker rmi -f >/dev/null 2>&1 || true
      ok "Imágenes Docker locales borradas"
    else
      ok "No hay imágenes Docker locales del proyecto"
    fi
  else
    warn "Docker no está corriendo, no se limpian imágenes locales"
  fi
fi

cat <<EOF

${C_GREEN}========================================${C_RESET}
${C_GREEN} Infraestructura destruida — Grupo 8${C_RESET}
${C_GREEN}========================================${C_RESET}

Para volver a desplegar:
  ./deploy.sh

EOF