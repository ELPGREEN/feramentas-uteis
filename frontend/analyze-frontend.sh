#!/usr/bin/env bash
# ============================================================
#  analyze-frontend — Análise estática completa de frontend
#  Uso: npm run analyze-frontend [-- --strict --output report.json --fix]
# ============================================================

set -euo pipefail

# ── Cores ────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Defaults ─────────────────────────────────────────────────
STRICT=false
FIX=false
FULL=false
OUTPUT=""
QUIET=false
ERRORS=0
WARNINGS=0
SUGGESTIONS=0
START_TIME=$(date +%s)

# ── Parse args ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --strict) STRICT=true ;;
    --fix)    FIX=true ;;
    --full)   FULL=true ;;
    --output) OUTPUT="$2"; shift ;;
    --quiet)  QUIET=true ;;
    --help)
      echo "Uso: analyze-frontend.sh [--strict] [--fix] [--full] [--output report.json] [--quiet]"
      exit 0 ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
  shift
done

# ── Helpers ──────────────────────────────────────────────────
error()      { [[ "$QUIET" == false ]] && echo -e "${RED}  ✖ [ERRO]${RESET} $1"; ERRORS=$((ERRORS+1)); }
warning()    { [[ "$QUIET" == false ]] && echo -e "${YELLOW}  ⚠ [WARN]${RESET} $1"; WARNINGS=$((WARNINGS+1)); }
suggestion() { [[ "$QUIET" == false ]] && echo -e "${BLUE}  ➜ [INFO]${RESET} $1"; SUGGESTIONS=$((SUGGESTIONS+1)); }
ok()         { [[ "$QUIET" == false ]] && echo -e "${GREEN}  ✔${RESET} $1"; }
section()    { [[ "$QUIET" == false ]] && echo -e "\n${BOLD}━━━ $1 ━━━${RESET}"; }

# ── Detectar package manager ─────────────────────────────────
PM="npm"
[[ -f "yarn.lock" ]] && PM="yarn"
[[ -f "pnpm-lock.yaml" ]] && PM="pnpm"
[[ -f "bun.lockb" ]] && PM="bun"

# ── Detectar framework ───────────────────────────────────────
FRAMEWORK="desconhecido"
[[ -f "next.config.js" || -f "next.config.mjs" ]] && FRAMEWORK="Next.js"
[[ -f "vite.config.ts" || -f "vite.config.js" ]] && FRAMEWORK="Vite"
[[ -f "nuxt.config.ts" || -f "nuxt.config.js" ]] && FRAMEWORK="Nuxt"
[[ -f "astro.config.mjs" ]] && FRAMEWORK="Astro"
[[ -f "svelte.config.js" ]] && FRAMEWORK="SvelteKit"

if [[ "$QUIET" == false ]]; then
echo -e "${BOLD}╔══════════════════════════════════════════╗"
echo -e "║   🔭 Orion Frontend Analyzer v2.0       ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo -e "Framework: ${FRAMEWORK} | PM: ${PM} | Strict: ${STRICT} | Fix: ${FIX} | Full: ${FULL}\n"
fi

# ════════════════════════════════════════════════════════════
# 1. TYPESCRIPT
# ════════════════════════════════════════════════════════════
section "TypeScript"
if [[ -f "tsconfig.json" ]]; then
  TSC_OUT=$(npx --yes tsc --noEmit 2>&1 || true)
  if echo "$TSC_OUT" | grep -q "error"; then
    while IFS= read -r line; do [[ -n "$line" ]] && error "$line"; done <<< "$TSC_OUT"
  else
    ok "Sem erros de tipo"
  fi
else
  suggestion "Sem tsconfig.json"
fi

# ════════════════════════════════════════════════════════════
# 2. ESLINT
# ════════════════════════════════════════════════════════════
section "ESLint"
ESLINT_CONFIG=$(ls .eslintrc* eslint.config* 2>/dev/null | head -1)
if [[ -n "$ESLINT_CONFIG" ]]; then
  F=$([[ "$FIX" == true ]] && echo "--fix" || echo "")
  ESLINT_OUT=$(npx --no-install eslint . $F 2>&1 || true)
  if echo "$ESLINT_OUT" | grep -q "error"; then
    while IFS= read -r line; do
      echo "$line" | grep -q "error" && error "$line" || warning "$line"
    done <<< "$ESLINT_OUT"
  else
    ok "ESLint sem erros"
  fi
else
  suggestion "ESLint não configurado"
fi

# ════════════════════════════════════════════════════════════
# 3. ACESSIBILIDADE
# ════════════════════════════════════════════════════════════
section "Acessibilidade"
ALT_MISSING=$(grep -rn "<img" --include="*.tsx" --include="*.jsx" src/ 2>/dev/null | grep -v "alt=" || true)
if [[ -n "$ALT_MISSING" ]]; then
  COUNT=$(echo "$ALT_MISSING" | wc -l)
  warning "$COUNT ocorrências de <img> sem alt na mesma linha (verifique multi-line)"
else
  ok "Todas as <img> têm alt"
fi

# ════════════════════════════════════════════════════════════
# 4. VARIÁVEIS DE AMBIENTE
# ════════════════════════════════════════════════════════════
section "Variáveis de Ambiente"
if [[ -f ".env.example" ]] && [[ -f ".env" ]]; then
  MISSING=$(comm -23 <(grep -oP '^[A-Z_]+(?==)' .env.example | sort -u) <(grep -oP '^[A-Z_]+(?==)' .env | sort -u) || true)
  if [[ -n "$MISSING" ]]; then
    error "Faltam no .env: $(echo $MISSING | tr '\n' ' ')"
  else
    ok ".env completo"
  fi
else
  warning ".env.example ou .env ausente"
fi

# ════════════════════════════════════════════════════════════
# 5. PERFORMANCE
# ════════════════════════════════════════════════════════════
section "Performance"
CONSOLE_COUNT=$(grep -rn "console\.log(" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null | grep -v "^\s*//" | wc -l || echo "0")
if [[ "$CONSOLE_COUNT" -gt 0 ]]; then
  warning "$CONSOLE_COUNT console.log(s) ativos no código"
else
  ok "Sem console.log ativos"
fi

# ════════════════════════════════════════════════════════════
# 6. SEGURANÇA
# ════════════════════════════════════════════════════════════
section "Segurança"
EVAL_COUNT=$(grep -rn "\beval(" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null | grep -v "node_modules" | wc -l || echo "0")
if [[ "$EVAL_COUNT" -gt 0 ]]; then
  error "$EVAL_COUNT ocorrência(s) de eval() — risco XSS"
else
  ok "Sem eval() no código"
fi

DANGEROUS_COUNT=$(grep -rn "dangerouslySetInnerHTML" --include="*.tsx" --include="*.jsx" src/ 2>/dev/null | wc -l || echo "0")
if [[ "$DANGEROUS_COUNT" -gt 0 ]]; then
  warning "$DANGEROUS_COUNT ocorrência(s) de dangerouslySetInnerHTML"
else
  ok "Sem dangerouslySetInnerHTML"
fi

# ════════════════════════════════════════════════════════════
# 7. QUALIDADE (MODO STRICT)
# ════════════════════════════════════════════════════════════
if [[ "$STRICT" == true ]]; then
  section "Qualidade (Strict)"
  TODOS=$(grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/ 2>/dev/null | wc -l || echo "0")
  if [[ "$TODOS" -gt 0 ]]; then
    warning "$TODOS TODO/FIXME pendentes"
  else
    ok "Sem TODOs pendentes"
  fi

  ANY_COUNT=$(grep -rn ": any\|as any" --include="*.ts" --include="*.tsx" src/ 2>/dev/null | wc -l || echo "0")
  if [[ "$ANY_COUNT" -gt 0 ]]; then
    warning "$ANY_COUNT usos de 'any' — use tipos específicos"
  fi
fi

# ════════════════════════════════════════════════════════════
# 8. TESTES
# ════════════════════════════════════════════════════════════
section "Testes"
TEST_FILES=$(find src/ -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | wc -l)
COMPONENTS=$(find src/ -name "*.tsx" -o -name "*.jsx" 2>/dev/null | wc -l)
if [[ "$TEST_FILES" -gt 0 ]]; then
  COVERAGE=$((TEST_FILES * 100 / (COMPONENTS + 1)))
  suggestion "$TEST_FILES arquivos de teste para $COMPONENTS componentes (~${COVERAGE}% cobertura estimada)"
fi

# ════════════════════════════════════════════════════════════
# 9. FULL MODE (knip, jscpd, madge, secretlint)
# ════════════════════════════════════════════════════════════
if [[ "$FULL" == true ]]; then
  section "Full Mode"

  if command -v npx &>/dev/null; then
    KNIP_OUT=$(npx --no-install knip 2>&1 || true)
    if [[ -n "$KNIP_OUT" ]]; then
      suggestion "Knip encontrou arquivos não utilizados"
    else
      ok "Knip sem issues"
    fi
  fi

  SECRETS=$(grep -rnP '(?<![A-Za-z])[A-Za-z0-9_]{20,}(?![A-Za-z])' --include="*.ts" --include="*.tsx" --include="*.js" src/ 2>/dev/null | grep -v "node_modules\|\.test\." | grep -v "import\|require\|env\." | head -5 || true)
  if [[ -n "$SECRETS" ]]; then
    error "Possíveis secrets hardcoded detectados"
  else
    ok "Sem secrets aparentes no código"
  fi
fi

# ════════════════════════════════════════════════════════════
# RELATÓRIO FINAL
# ════════════════════════════════════════════════════════════
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  RELATÓRIO FINAL${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${RED}Erros:${RESET}      $ERRORS"
echo -e "  ${YELLOW}Avisos:${RESET}     $WARNINGS"
echo -e "  ${BLUE}Sugestões:${RESET}  $SUGGESTIONS"
echo -e "  ⏱ ${ELAPSED}s"
echo ""

SCORE=$((100 - (ERRORS * 10 + WARNINGS * 3)))
[[ $SCORE -lt 0 ]] && SCORE=0

if [[ $SCORE -ge 90 ]]; then
  echo -e "  ${GREEN}${BOLD}✨ SCORE: ${SCORE}/100${RESET}"
elif [[ $SCORE -ge 70 ]]; then
  echo -e "  ${YELLOW}${BOLD}⚠ SCORE: ${SCORE}/100${RESET}"
else
  echo -e "  ${RED}${BOLD}✖ SCORE: ${SCORE}/100${RESET}"
fi

if [[ -n "$OUTPUT" ]]; then
  cat > "$OUTPUT" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "framework": "$FRAMEWORK",
  "pm": "$PM",
  "score": $SCORE,
  "elapsed_seconds": $ELAPSED,
  "summary": {
    "errors": $ERRORS,
    "warnings": $WARNINGS,
    "suggestions": $SUGGESTIONS
  }
}
EOF
  echo -e "\n  📄 Relatório salvo em: $OUTPUT"
fi

[[ "$STRICT" == true && $ERRORS -gt 0 ]] && exit 1
exit 0
