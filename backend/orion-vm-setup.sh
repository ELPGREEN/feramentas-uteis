#!/usr/bin/env bash
# orion-vm-setup.sh — Diagnóstico da VM Orion (GCP / FastAPI)

set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

ok()      { echo -e "${GREEN}  ✔${RESET} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${RESET} $1"; }
err()     { echo -e "${RED}  ✖${RESET} $1"; }
section() { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     ⚙️  Orion VM Diagnostics             ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"

section "1. Serviço systemd"
systemctl is-active orion &>/dev/null && ok "orion.service ATIVO" || err "orion.service INATIVO"
systemctl is-enabled orion &>/dev/null && ok "Habilitado no boot" || warn "Não habilitado no boot"

section "2. Variáveis de Ambiente"
sudo systemctl show orion --property=Environment 2>/dev/null | \
  grep -oP '[A-Z_]+=\S+' | while IFS= read -r var; do
  KEY=$(echo "$var" | cut -d= -f1)
  ok "$KEY definida"
done

section "3. Endpoints FastAPI"
BASE="http://localhost:8080"
for EP in "health" "docs"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/${EP}" 2>/dev/null || echo "000")
  [[ "$CODE" == "200" ]] && ok "/${EP} → ${CODE}" || err "/${EP} → ${CODE}"
done

section "4. Memória"
curl -s "${BASE}/health" 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
used=d['memory_used_mb']; total=d['memory_total_mb']
pct=round(used/total*100)
print(f'  RAM: {used}MB / {total}MB ({pct}%)')
" 2>/dev/null || echo "  RAM: N/A"

section "5. Drop-ins systemd"
ls /etc/systemd/system/orion.service.d/ 2>/dev/null | while IFS= read -r f; do
  [[ "$f" == *.disabled ]] && warn "$f (desativado)" || ok "$f ativo"
done

section "6. Arquivo .env"
ENV_PATH="$(eval echo ~$(logname))/orion-vm-bundle/.env"
[[ -f "$ENV_PATH" ]] && ok ".env encontrado" || err ".env não encontrado em $ENV_PATH"

echo -e "\n${GREEN}${BOLD}✨ Diagnóstico concluído.${RESET}\n"
