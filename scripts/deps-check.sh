#!/usr/bin/env bash
# deps-check.sh — Saúde das dependências
# Uso: ./deps-check.sh [--audit-only] [--outdated-only]

set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

AUDIT_ONLY=false; OUTDATED_ONLY=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --audit-only)    AUDIT_ONLY=true ;;
    --outdated-only) OUTDATED_ONLY=true ;;
  esac
  shift
done

PM="npm"
[[ -f "yarn.lock" ]]      && PM="yarn"
[[ -f "pnpm-lock.yaml" ]] && PM="pnpm"
[[ -f "bun.lockb" ]]      && PM="bun"

echo -e "\n${BOLD}🔍 Verificando dependências (${PM})...${RESET}\n"

if [[ "$OUTDATED_ONLY" == false ]]; then
  echo -e "${BOLD}━━━ Vulnerabilidades${RESET}"
  if [[ "$PM" == "npm" ]]; then
    AUDIT=$(npm audit --json 2>/dev/null || echo "{}")
    C=$(echo "$AUDIT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))
" 2>/dev/null || echo 0)
    H=$(echo "$AUDIT" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('metadata',{}).get('vulnerabilities',{}).get('high',0))
" 2>/dev/null || echo 0)
    [[ $C -gt 0 ]] && echo -e "${RED}  ✖ $C crítica(s) — rode: npm audit fix${RESET}"
    [[ $H -gt 0 ]] && echo -e "${YELLOW}  ⚠ $H high${RESET}"
    [[ $C -eq 0 && $H -eq 0 ]] && echo -e "${GREEN}  ✔ Sem vulnerabilidades críticas${RESET}"
  fi
fi

if [[ "$AUDIT_ONLY" == false ]]; then
  echo -e "\n${BOLD}━━━ Dependências Desatualizadas${RESET}"
  OUTDATED=$(npm outdated 2>/dev/null || true)
  [[ -n "$OUTDATED" ]] && echo "$OUTDATED" \
                       || echo -e "${GREEN}  ✔ Tudo atualizado${RESET}"
fi
echo ""
