#!/usr/bin/env bash
# env-check.sh — Verifica variáveis de ambiente obrigatórias
# Uso: ./env-check.sh [--ref <arquivo>] [--strict]

set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
STRICT=false; REF_FILE=".env.example"

while [[ $# -gt 0 ]]; do
  case $1 in
    --strict) STRICT=true ;;
    --ref)    REF_FILE="$2"; shift ;;
  esac
  shift
done

ERRORS=0
echo -e "\n🔍 Verificando variáveis de ambiente..."
echo -e "   Referência: ${REF_FILE}\n"

if [[ ! -f "$REF_FILE" ]]; then
  echo -e "${YELLOW}⚠  ${REF_FILE} não encontrado${RESET}"
  exit 0
fi

ENV_FILE=".env"
[[ ! -f "$ENV_FILE" ]] && ENV_FILE=".env.local"
[[ ! -f "$ENV_FILE" ]] && { echo -e "${RED}✖ Nenhum .env encontrado${RESET}"; exit 1; }

while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  VAR=$(echo "$line" | cut -d= -f1)
  if grep -q "^${VAR}=" "$ENV_FILE" 2>/dev/null; then
    VAL=$(grep "^${VAR}=" "$ENV_FILE" | cut -d= -f2-)
    [[ -z "$VAL" ]] && echo -e "${YELLOW}⚠  $VAR está vazia${RESET}" \
                    || echo -e "${GREEN}✔  $VAR${RESET}"
  else
    echo -e "${RED}✖  $VAR ausente${RESET}"
    ERRORS=$((ERRORS+1))
  fi
done < "$REF_FILE"

echo ""
[[ $ERRORS -gt 0 ]] && echo -e "${RED}$ERRORS variável(is) ausente(s)${RESET}" \
                     || echo -e "${GREEN}✨ Todas as variáveis presentes${RESET}"

[[ "$STRICT" == true && $ERRORS -gt 0 ]] && exit 1
exit 0
