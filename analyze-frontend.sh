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
OUTPUT=""
BROWSER=""
ERRORS=0
WARNINGS=0
SUGGESTIONS=0
REPORT_DATA='{"errors":[],"warnings":[],"suggestions":[]}'

# ── Parse args ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --strict)   STRICT=true ;;
    --fix)      FIX=true ;;
    --output)   OUTPUT="$2"; shift ;;
    --browser)  BROWSER="$2"; shift ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
  shift
done

# ── Helpers ──────────────────────────────────────────────────
error()      { echo -e "${RED}  ✖ [ERRO]${RESET} $1"; ERRORS=$((ERRORS+1)); }
warning()    { echo -e "${YELLOW}  ⚠ [WARN]${RESET} $1"; WARNINGS=$((WARNINGS+1)); }
suggestion() { echo -e "${BLUE}  ➜ [INFO]${RESET} $1"; SUGGESTIONS=$((SUGGESTIONS+1)); }
ok()         { echo -e "${GREEN}  ✔${RESET} $1"; }
section()    { echo -e "\n${BOLD}━━━ $1 ━━━${RESET}"; }

# ── Detectar package manager ─────────────────────────────────
PM="npm"
[[ -f "yarn.lock" ]] && PM="yarn"
[[ -f "pnpm-lock.yaml" ]] && PM="pnpm"

echo -e "${BOLD}╔══════════════════════════════════════════╗"
echo -e "║     🔭 Orion Frontend Analyzer v1.0     ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo -e "Package manager: ${PM} | Strict: ${STRICT} | Fix: ${FIX}\n"

# ════════════════════════════════════════════════════════════
# 1. TYPESCRIPT
# ════════════════════════════════════════════════════════════
section "TypeScript — Type Check"
if [[ -f "tsconfig.json" ]]; then
  if command -v tsc &>/dev/null; then
    TSC_OUT=$(npx tsc --noEmit 2>&1 || true)
    if [[ -n "$TSC_OUT" ]]; then
      while IFS= read -r line; do error "$line"; done <<< "$TSC_OUT"
    else
      ok "Sem erros de tipo"
    fi
  else
    warning "tsc não encontrado — instale typescript"
  fi
else
  suggestion "Sem tsconfig.json — considere adicionar TypeScript"
fi

# ════════════════════════════════════════════════════════════
# 2. ESLINT
# ════════════════════════════════════════════════════════════
section "ESLint — Linting JS/TS"
if [[ -f ".eslintrc*" ]] || [[ -f "eslint.config*" ]] || \
   grep -q '"eslintConfig"' package.json 2>/dev/null; then
  FIX_FLAG=$([[ "$FIX" == true ]] && echo "--fix" || echo "")
  ESLINT_OUT=$(npx eslint . --ext .js,.jsx,.ts,.tsx \
    --format stylish $FIX_FLAG 2>&1 || true)
  if echo "$ESLINT_OUT" | grep -q "error"; then
    while IFS= read -r line; do
      [[ "$line" =~ "error" ]] && error "$line" || true
      [[ "$line" =~ "warning" ]] && warning "$line" || true
    done <<< "$ESLINT_OUT"
  else
    ok "ESLint sem erros"
    [[ -n "$ESLINT_OUT" ]] && echo "$ESLINT_OUT" | grep "warning" | \
      while IFS= read -r line; do warning "$line"; done || true
  fi
else
  warning "ESLint não configurado — crie .eslintrc.json"
fi

# ════════════════════════════════════════════════════════════
# 3. STYLELINT
# ════════════════════════════════════════════════════════════
section "Stylelint — CSS/SCSS"
if command -v npx &>/dev/null && [[ -f ".stylelintrc*" ]] 2>/dev/null; then
  FIX_FLAG=$([[ "$FIX" == true ]] && echo "--fix" || echo "")
  STYLE_OUT=$(npx stylelint "**/*.{css,scss,less}" $FIX_FLAG 2>&1 || true)
  if [[ -n "$STYLE_OUT" ]]; then
    while IFS= read -r line; do warning "$line"; done <<< "$STYLE_OUT"
  else
    ok "Sem erros de CSS"
  fi
else
  suggestion "Stylelint não configurado — adicione .stylelintrc.json"
fi

# ════════════════════════════════════════════════════════════
# 4. ACESSIBILIDADE — atributos obrigatórios
# ════════════════════════════════════════════════════════════
section "Acessibilidade — HTML/JSX"

# Imagens sem alt
ALT_MISSING=$(grep -rn "<img" --include="*.tsx" --include="*.jsx" \
  --include="*.html" . 2>/dev/null | grep -v "alt=" || true)
if [[ -n "$ALT_MISSING" ]]; then
  while IFS= read -r line; do
    warning "Img sem alt: $line"
  done <<< "$ALT_MISSING"
else
  ok "Todas as <img> têm atributo alt"
fi

# Botões sem aria-label ou texto
BTN_NO_LABEL=$(grep -rn "<button" --include="*.tsx" --include="*.jsx" \
  --include="*.html" . 2>/dev/null | \
  grep -v "aria-label\|aria-labelledby\|>[^<]" || true)
[[ -n "$BTN_NO_LABEL" ]] && \
  warning "Botões sem aria-label detectados — verifique acessibilidade" || \
  ok "Botões com labels adequados"

# Inputs sem label associada
INPUT_NO_LABEL=$(grep -rn "<input" --include="*.tsx" --include="*.jsx" \
  --include="*.html" . 2>/dev/null | \
  grep -v "aria-label\|aria-labelledby\|id=" || true)
[[ -n "$INPUT_NO_LABEL" ]] && \
  warning "Inputs sem label associada detectados" || \
  ok "Inputs com labels adequados"

# ════════════════════════════════════════════════════════════
# 5. DEPENDÊNCIAS
# ════════════════════════════════════════════════════════════
section "Dependências — Segurança e Saúde"

# Vulnerabilidades
if [[ "$PM" == "npm" ]]; then
  AUDIT_OUT=$(npm audit --json 2>/dev/null || true)
  CRITICAL=$(echo "$AUDIT_OUT" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); \
     print(d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))" \
    2>/dev/null || echo "0")
  HIGH=$(echo "$AUDIT_OUT" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); \
     print(d.get('metadata',{}).get('vulnerabilities',{}).get('high',0))" \
    2>/dev/null || echo "0")
  [[ "$CRITICAL" -gt 0 ]] && error "$CRITICAL vulnerabilidade(s) CRÍTICA(s) — rode npm audit fix"
  [[ "$HIGH" -gt 0 ]]     && warning "$HIGH vulnerabilidade(s) HIGH — rode npm audit fix"
  [[ "$CRITICAL" -eq 0 && "$HIGH" -eq 0 ]] && ok "Sem vulnerabilidades críticas/high"
fi

# Dependências não utilizadas
if command -v npx &>/dev/null; then
  UNUSED=$(npx depcheck --json 2>/dev/null | python3 -c \
    "import json,sys; d=json.load(sys.stdin); \
     unused=d.get('dependencies',[]); \
     [print(p) for p in unused[:5]]" 2>/dev/null || true)
  [[ -n "$UNUSED" ]] && \
    warning "Dependências não utilizadas: $UNUSED" || \
    ok "Sem dependências não utilizadas detectadas"
fi

# ════════════════════════════════════════════════════════════
# 6. VARIÁVEIS DE AMBIENTE
# ════════════════════════════════════════════════════════════
section "Variáveis de Ambiente"
if [[ -f ".env.example" ]] && [[ -f ".env" ]]; then
  MISSING_VARS=$(comm -23 \
    <(grep -oP '^[A-Z_]+(?==)' .env.example | sort) \
    <(grep -oP '^[A-Z_]+(?==)' .env | sort) || true)
  [[ -n "$MISSING_VARS" ]] && \
    error "Variáveis no .env.example mas não no .env: $MISSING_VARS" || \
    ok ".env completo em relação ao .env.example"
elif [[ ! -f ".env" ]]; then
  warning "Arquivo .env não encontrado"
else
  suggestion "Crie um .env.example para documentar variáveis necessárias"
fi

# Variáveis de ambiente vazadas no código (nunca hardcode!)
LEAKED=$(grep -rn "NEXT_PUBLIC_\|REACT_APP_\|VITE_" \
  --include="*.ts" --include="*.tsx" --include="*.js" \
  --include="*.jsx" . 2>/dev/null | \
  grep -v "process.env\|import.meta.env\|//\|\.env" || true)
[[ -n "$LEAKED" ]] && \
  error "Possível vazamento de variável de ambiente no código!" || \
  ok "Sem variáveis de ambiente hardcoded"

# ════════════════════════════════════════════════════════════
# 7. ROTAS / NAVEGAÇÃO
# ════════════════════════════════════════════════════════════
section "Rotas e Navegação"

# Imports sem arquivo correspondente
BROKEN_IMPORTS=$(grep -rn "^import\|^from\|require(" \
  --include="*.ts" --include="*.tsx" --include="*.js" \
  --include="*.jsx" . 2>/dev/null | \
  grep "\.\./\|\./" | \
  while IFS=: read -r file line content; do
    IMPORT_PATH=$(echo "$content" | grep -oP "(?<=['\"])[^'\"]+(?=['\"])" | head -1)
    if [[ -n "$IMPORT_PATH" ]] && [[ "$IMPORT_PATH" == ./* || "$IMPORT_PATH" == ../* ]]; then
      DIR=$(dirname "$file")
      RESOLVED="$DIR/$IMPORT_PATH"
      for EXT in "" ".ts" ".tsx" ".js" ".jsx" "/index.ts" "/index.tsx" "/index.js"; do
        [[ -e "${RESOLVED}${EXT}" ]] && break
      done
      [[ ! -e "${RESOLVED}" ]] && echo "$file:$line → $IMPORT_PATH"
    fi
  done 2>/dev/null || true)
[[ -n "$BROKEN_IMPORTS" ]] && \
  error "Imports quebrados detectados: $BROKEN_IMPORTS" || \
  ok "Imports locais aparentemente válidos"

# ════════════════════════════════════════════════════════════
# 8. PERFORMANCE — bundle e lazy loading
# ════════════════════════════════════════════════════════════
section "Performance"

# Componentes grandes sem lazy loading
LARGE_COMPONENTS=$(find . -name "*.tsx" -o -name "*.jsx" 2>/dev/null | \
  grep -v node_modules | \
  xargs wc -l 2>/dev/null | \
  awk '$1 > 300 {print $2 " (" $1 " linhas)"}' | \
  grep -v "total" || true)
[[ -n "$LARGE_COMPONENTS" ]] && \
  suggestion "Componentes grandes (>300 linhas) — considere React.lazy():\n$LARGE_COMPONENTS" || \
  ok "Sem componentes excessivamente grandes"

# console.log em produção
CONSOLE_LOGS=$(grep -rn "console\.log" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  . 2>/dev/null | grep -v node_modules || true)
CONSOLE_COUNT=$(echo "$CONSOLE_LOGS" | grep -c "console" 2>/dev/null || echo "0")
[[ "$CONSOLE_COUNT" -gt 0 ]] && \
  warning "${CONSOLE_COUNT} console.log(s) no código — remova antes do deploy" || \
  ok "Sem console.log no código"

# ════════════════════════════════════════════════════════════
# 9. MODO STRICT
# ════════════════════════════════════════════════════════════
if [[ "$STRICT" == true ]]; then
  section "Modo Strict — Verificações Extras"

  # TODO/FIXME/HACK
  TODOS=$(grep -rn "TODO\|FIXME\|HACK\|XXX" \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
    . 2>/dev/null | grep -v node_modules | wc -l || echo "0")
  [[ "$TODOS" -gt 0 ]] && \
    warning "$TODOS comentário(s) TODO/FIXME/HACK pendentes" || \
    ok "Sem TODOs pendentes"

  # any em TypeScript
  TS_ANY=$(grep -rn ": any\|as any" \
    --include="*.ts" --include="*.tsx" . 2>/dev/null | \
    grep -v node_modules | wc -l || echo "0")
  [[ "$TS_ANY" -gt 0 ]] && \
    warning "$TS_ANY uso(s) de 'any' em TypeScript — use tipos específicos"
fi

# ════════════════════════════════════════════════════════════
# RELATÓRIO FINAL
# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  RELATÓRIO FINAL${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${RED}Erros:${RESET}      $ERRORS"
echo -e "  ${YELLOW}Avisos:${RESET}     $WARNINGS"
echo -e "  ${BLUE}Sugestões:${RESET}  $SUGGESTIONS"
echo ""

# Score
TOTAL=$((ERRORS*3 + WARNINGS*1))
if [[ $TOTAL -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}✨ SCORE: 100/100 — Frontend saudável!${RESET}"
elif [[ $TOTAL -lt 5 ]]; then
  echo -e "  ${YELLOW}${BOLD}⚠  SCORE: BOM — Pequenos ajustes necessários${RESET}"
elif [[ $TOTAL -lt 15 ]]; then
  echo -e "  ${YELLOW}${BOLD}⚡ SCORE: REGULAR — Revisão recomendada${RESET}"
else
  echo -e "  ${RED}${BOLD}✖  SCORE: CRÍTICO — Correções obrigatórias${RESET}"
fi

# Salvar output
if [[ -n "$OUTPUT" ]]; then
  {
    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"errors\": $ERRORS,"
    echo "  \"warnings\": $WARNINGS,"
    echo "  \"suggestions\": $SUGGESTIONS,"
    echo "  \"strict\": $STRICT"
    echo "}"
  } > "$OUTPUT"
  echo -e "\n  📄 Relatório salvo em: ${BOLD}$OUTPUT${RESET}"
fi

# Exit code para CI/CD
[[ "$STRICT" == true && $ERRORS -gt 0 ]] && exit 1
[[ $ERRORS -gt 0 ]] && exit 1
exit 0
