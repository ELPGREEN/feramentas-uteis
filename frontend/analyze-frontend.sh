#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  🔭 ORION FRONTEND ANALYZER — Universal Edition v2.0
#  Análise completa: lint, tipos, acessibilidade, segurança, performance,
#  duplicação, dependências circulares, secrets, bundle e muito mais.
#
#  USO:
#    bash scripts/analyze-frontend.sh [opções]
#    npm run analyze             → básico
#    npm run analyze:strict      → modo rigoroso (exit 1 em qualquer erro)
#    npm run analyze:fix         → autocorrige formatação
#    npm run analyze:ci          → CI/CD com report.json
#    npm run analyze:full        → tudo + ferramentas extras (knip, jscpd, madge)
#
#  OPÇÕES:
#    --strict        Modo rigoroso — exit 1 em erros
#    --fix           Autocorrige via ESLint/Prettier
#    --full          Ativa verificações extras (knip, jscpd, madge, secretlint)
#    --output <f>    Salva relatório em arquivo (JSON)
#    --browser <b>   Simula Browserslist para o navegador especificado
#    --no-color      Desativa cores (útil para logs de CI)
#    --quiet         Mostra só o resumo final
#    --help          Exibe esta ajuda
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail
IFS=$'\n\t'

# ── Cores ────────────────────────────────────────────────────────────────────
if [[ "${NO_COLOR:-}" == "1" ]] || [[ "${1:-}" == "--no-color" ]]; then
  RED=''; YELLOW=''; GREEN=''; BLUE=''; CYAN=''; MAGENTA=''; BOLD=''; DIM=''; RESET=''
else
  RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
  BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
fi

# ── Defaults ─────────────────────────────────────────────────────────────────
STRICT=false
FIX=false
FULL=false
QUIET=false
OUTPUT=""
BROWSER=""
ERRORS=0
WARNINGS=0
SUGGESTIONS=0
SKIPPED=0
declare -a REPORT_ERRORS=()
declare -a REPORT_WARNINGS=()
declare -a REPORT_SUGGESTIONS=()
START_TIME=$(date +%s)

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --strict)        STRICT=true ;;
    --fix)           FIX=true ;;
    --full)          FULL=true ;;
    --quiet)         QUIET=true ;;
    --no-color)      ;;
    --output)        OUTPUT="$2"; shift ;;
    --browser)       BROWSER="$2"; shift ;;
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^#  \?//'
      exit 0 ;;
    *) echo "Opção desconhecida: $1 (use --help)"; exit 1 ;;
  esac
  shift
done

# ── Helpers ───────────────────────────────────────────────────────────────────
_log()       { [[ "$QUIET" == false ]] && echo -e "$1" || true; }
error()      { _log "${RED}  ✖ [ERRO]${RESET} $1"; ERRORS=$((ERRORS+1)); REPORT_ERRORS+=("$1"); }
warning()    { _log "${YELLOW}  ⚠ [WARN]${RESET} $1"; WARNINGS=$((WARNINGS+1)); REPORT_WARNINGS+=("$1"); }
suggestion() { _log "${BLUE}  ➜ [INFO]${RESET} $1"; SUGGESTIONS=$((SUGGESTIONS+1)); REPORT_SUGGESTIONS+=("$1"); }
ok()         { _log "${GREEN}  ✔${RESET} $1"; }
skip()       { _log "${DIM}  ○ [SKIP]${RESET} $1"; SKIPPED=$((SKIPPED+1)); }
section()    { _log "\n${BOLD}${CYAN}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

has_cmd()    { command -v "$1" &>/dev/null; }
has_pkg()    { [[ -f "node_modules/.bin/$1" ]] || has_cmd "$1"; }
run_npx()    { npx --yes "$@" 2>/dev/null; }

# ── Detectar package manager & framework ─────────────────────────────────────
PM="npm"
[[ -f "yarn.lock" ]]       && PM="yarn"
[[ -f "pnpm-lock.yaml" ]]  && PM="pnpm"
[[ -f "bun.lockb" ]]       && PM="bun"

FRAMEWORK="unknown"
[[ -f "next.config.js" ]] || [[ -f "next.config.ts" ]] || [[ -f "next.config.mjs" ]] && FRAMEWORK="Next.js"
[[ -f "vite.config.js" ]] || [[ -f "vite.config.ts" ]]  && FRAMEWORK="Vite"
[[ -f "nuxt.config.js" ]] || [[ -f "nuxt.config.ts" ]]  && FRAMEWORK="Nuxt"
[[ -f "astro.config.mjs" ]]                              && FRAMEWORK="Astro"
[[ -f "svelte.config.js" ]]                              && FRAMEWORK="SvelteKit"
[[ -f "remix.config.js" ]]                               && FRAMEWORK="Remix"

SRC_DIR="src"
[[ ! -d "src" ]] && [[ -d "app" ]]         && SRC_DIR="app"
[[ ! -d "src" ]] && [[ ! -d "app" ]]       && SRC_DIR="."

_log ""
_log "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
_log "${BOLD}║       🔭 Orion Frontend Analyzer — Universal v2.0    ║${RESET}"
_log "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
_log "  Framework : ${BOLD}${FRAMEWORK}${RESET}"
_log "  PM        : ${BOLD}${PM}${RESET}"
_log "  Src dir   : ${BOLD}${SRC_DIR}${RESET}"
_log "  Flags     : strict=${STRICT} fix=${FIX} full=${FULL}"
_log ""

# ════════════════════════════════════════════════════════════════════════════
# 1. TYPESCRIPT
# ════════════════════════════════════════════════════════════════════════════
section "1/12 · TypeScript — Type Check"
if [[ -f "tsconfig.json" ]]; then
  if has_cmd tsc || has_pkg tsc; then
    TSC_OUT=$(npx tsc --noEmit 2>&1 || true)
    if [[ -n "$TSC_OUT" ]]; then
      COUNT=$(echo "$TSC_OUT" | grep -c "error TS" || true)
      error "$COUNT erro(s) de tipo TypeScript"
      echo "$TSC_OUT" | grep "error TS" | head -10 | \
        while IFS= read -r l; do _log "    ${DIM}$l${RESET}"; done
    else
      ok "Sem erros de tipo"
    fi
  else
    skip "tsc não encontrado — instale typescript"
  fi
else
  suggestion "Sem tsconfig.json — considere adicionar TypeScript ao projeto"
fi

# ════════════════════════════════════════════════════════════════════════════
# 2. ESLINT
# ════════════════════════════════════════════════════════════════════════════
section "2/12 · ESLint — Linting JS/TS/JSX"
ESLINT_CFG=false
for f in .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yaml \
          .eslintrc.yml eslint.config.js eslint.config.mjs eslint.config.ts; do
  [[ -f "$f" ]] && ESLINT_CFG=true && break
done
grep -q '"eslintConfig"' package.json 2>/dev/null && ESLINT_CFG=true

if [[ "$ESLINT_CFG" == true ]]; then
  FIX_FLAG=$([[ "$FIX" == true ]] && echo "--fix" || echo "")
  ESLINT_OUT=$(npx eslint "$SRC_DIR" --ext .js,.jsx,.ts,.tsx,.mjs,.cjs \
    --format compact $FIX_FLAG 2>&1 || true)
  E_COUNT=$(echo "$ESLINT_OUT" | grep -c " Error - " || true)
  W_COUNT=$(echo "$ESLINT_OUT" | grep -c " Warning - " || true)
  [[ $E_COUNT -gt 0 ]] && error "$E_COUNT erro(s) ESLint" || ok "ESLint sem erros"
  [[ $W_COUNT -gt 0 ]] && warning "$W_COUNT aviso(s) ESLint"
  echo "$ESLINT_OUT" | grep " Error - " | head -5 | \
    while IFS= read -r l; do _log "    ${DIM}$l${RESET}"; done
else
  warning "ESLint não configurado — crie .eslintrc.json"
fi

# ════════════════════════════════════════════════════════════════════════════
# 3. PRETTIER
# ════════════════════════════════════════════════════════════════════════════
section "3/12 · Prettier — Formatação"
PRETTIER_CFG=false
for f in .prettierrc .prettierrc.js .prettierrc.json .prettierrc.yaml \
          prettier.config.js prettier.config.mjs; do
  [[ -f "$f" ]] && PRETTIER_CFG=true && break
done

if [[ "$PRETTIER_CFG" == true ]] && has_pkg prettier; then
  if [[ "$FIX" == true ]]; then
    npx prettier --write "$SRC_DIR/**/*.{ts,tsx,js,jsx,css,scss,json}" \
      2>/dev/null && ok "Prettier: formatação aplicada" || \
      warning "Prettier: alguns arquivos não puderam ser formatados"
  else
    PRETTIER_OUT=$(npx prettier --check \
      "$SRC_DIR/**/*.{ts,tsx,js,jsx,css,scss}" 2>&1 || true)
    BAD=$(echo "$PRETTIER_OUT" | grep -c "^Code style" || true)
    [[ $BAD -gt 0 ]] && \
      warning "$BAD arquivo(s) fora do padrão — rode --fix" || \
      ok "Formatação Prettier ok"
  fi
else
  suggestion "Prettier não configurado — adicione .prettierrc"
fi

# ════════════════════════════════════════════════════════════════════════════
# 4. STYLELINT
# ════════════════════════════════════════════════════════════════════════════
section "4/12 · Stylelint — CSS/SCSS/Modules"
STYLELINT_CFG=false
for f in .stylelintrc .stylelintrc.json .stylelintrc.js stylelint.config.js; do
  [[ -f "$f" ]] && STYLELINT_CFG=true && break
done

if [[ "$STYLELINT_CFG" == true ]] && has_pkg stylelint; then
  FIX_FLAG=$([[ "$FIX" == true ]] && echo "--fix" || echo "")
  STYLE_OUT=$(npx stylelint \
    "$SRC_DIR/**/*.{css,scss,less,module.css}" $FIX_FLAG 2>&1 || true)
  S_E=$(echo "$STYLE_OUT" | grep -c "✖" || true)
  S_W=$(echo "$STYLE_OUT" | grep -c "⚠" || true)
  [[ $S_E -gt 0 ]] && error "$S_E erro(s) Stylelint" || ok "CSS sem erros Stylelint"
  [[ $S_W -gt 0 ]] && warning "$S_W aviso(s) Stylelint"
else
  suggestion "Stylelint não configurado — adicione .stylelintrc.json"
fi

# ════════════════════════════════════════════════════════════════════════════
# 5. ACESSIBILIDADE
# ════════════════════════════════════════════════════════════════════════════
section "5/12 · Acessibilidade — WCAG / ARIA"

ALT_MISSING=$(grep -rn "<img" \
  --include="*.tsx" --include="*.jsx" \
  --include="*.html" --include="*.vue" --include="*.svelte" \
  "$SRC_DIR" 2>/dev/null | grep -v 'alt=' | grep -v '//' || true)
ALT_COUNT=$(echo "$ALT_MISSING" | grep -c "<img" || true)
[[ $ALT_COUNT -gt 0 ]] && warning "$ALT_COUNT <img> sem atributo alt" \
                        || ok "Todas as <img> têm alt"

BTN_BAD=$(grep -rn "<button" \
  --include="*.tsx" --include="*.jsx" --include="*.html" \
  "$SRC_DIR" 2>/dev/null | \
  grep -v 'aria-label\|aria-labelledby\|title=' || true)
BTN_COUNT=$(echo "$BTN_BAD" | grep -c "<button" || true)
[[ $BTN_COUNT -gt 0 ]] && warning "$BTN_COUNT botão(ões) sem aria-label" \
                        || ok "Botões com labels acessíveis"

INPUT_BAD=$(grep -rn "<input" \
  --include="*.tsx" --include="*.jsx" --include="*.html" \
  "$SRC_DIR" 2>/dev/null | \
  grep -v 'aria-label\|aria-labelledby\|id=' || true)
INPUT_COUNT=$(echo "$INPUT_BAD" | grep -c "<input" || true)
[[ $INPUT_COUNT -gt 0 ]] && warning "$INPUT_COUNT <input> sem label" \
                          || ok "<input>s com labels"

BLANK_BAD=$(grep -rn 'target="_blank"' \
  --include="*.tsx" --include="*.jsx" --include="*.html" \
  "$SRC_DIR" 2>/dev/null | \
  grep -v 'noopener\|noreferrer' || true)
BLANK_COUNT=$(echo "$BLANK_BAD" | grep -c 'target="_blank"' || true)
[[ $BLANK_COUNT -gt 0 ]] && \
  warning "$BLANK_COUNT link(s) target=_blank sem rel=noopener" || \
  ok "Links externos seguros"

# ════════════════════════════════════════════════════════════════════════════
# 6. SEGURANÇA
# ════════════════════════════════════════════════════════════════════════════
section "6/12 · Segurança — Vulnerabilidades e Secrets"

if [[ "$PM" == "npm" ]]; then
  AUDIT_JSON=$(npm audit --json 2>/dev/null || echo '{}')
  CRIT=$(echo "$AUDIT_JSON" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); \
     print(d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))" \
    2>/dev/null || echo "0")
  HIGH=$(echo "$AUDIT_JSON" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); \
     print(d.get('metadata',{}).get('vulnerabilities',{}).get('high',0))" \
    2>/dev/null || echo "0")
  MOD=$(echo "$AUDIT_JSON" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); \
     print(d.get('metadata',{}).get('vulnerabilities',{}).get('moderate',0))" \
    2>/dev/null || echo "0")
  [[ "$CRIT" -gt 0 ]] && error "$CRIT vulnerabilidade(s) CRÍTICA(s) — npm audit fix --force"
  [[ "$HIGH" -gt 0 ]] && warning "$HIGH vulnerabilidade(s) HIGH — npm audit fix"
  [[ "$MOD"  -gt 0 ]] && suggestion "$MOD vulnerabilidade(s) moderate"
  [[ "$CRIT" -eq 0 && "$HIGH" -eq 0 ]] && ok "Sem vulnerabilidades críticas/high"
elif [[ "$PM" == "pnpm" ]]; then
  pnpm audit 2>/dev/null | grep -E "critical|high" | \
    while IFS= read -r l; do warning "pnpm audit: $l"; done || \
    ok "pnpm audit: sem issues críticos"
fi

SECRET_PATTERNS='(api[_-]?key|secret|password|passwd|token|bearer|private[_-]?key|aws_|ghp_|sk-|AIza)[[:space:]]*[=:][[:space:]]*["'"'"'][A-Za-z0-9+/=_\-]{8,}'
SECRETS_FOUND=$(grep -rniE "$SECRET_PATTERNS" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  --include="*.env" --include="*.json" \
  "$SRC_DIR" 2>/dev/null | \
  grep -v node_modules | grep -v ".env.example" | \
  grep -v "//.*\(test\|mock\|example\|sample\|fake\)" || true)
SEC_COUNT=$(echo "$SECRETS_FOUND" | grep -c "." || true)
[[ $SEC_COUNT -gt 0 ]] && error "$SEC_COUNT possível(is) secret(s) hardcoded!" \
                        || ok "Sem secrets hardcoded detectados"

DANGEROUS=$(grep -rn "dangerouslySetInnerHTML" \
  --include="*.tsx" --include="*.jsx" "$SRC_DIR" 2>/dev/null || true)
DNG_COUNT=$(echo "$DANGEROUS" | grep -c "dangerouslySet" || true)
[[ $DNG_COUNT -gt 0 ]] && \
  warning "$DNG_COUNT uso(s) de dangerouslySetInnerHTML (risco XSS)" || \
  ok "Sem dangerouslySetInnerHTML"

EVAL_FOUND=$(grep -rn "\beval(" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  "$SRC_DIR" 2>/dev/null | grep -v "//\|node_modules" || true)
EVAL_COUNT=$(echo "$EVAL_FOUND" | grep -c "eval(" || true)
[[ $EVAL_COUNT -gt 0 ]] && \
  error "$EVAL_COUNT uso(s) de eval() — vulnerabilidade de segurança" || \
  ok "Sem uso de eval()"

# ════════════════════════════════════════════════════════════════════════════
# 7. VARIÁVEIS DE AMBIENTE
# ════════════════════════════════════════════════════════════════════════════
section "7/12 · Variáveis de Ambiente"

if [[ -f ".env.example" ]] || [[ -f ".env.sample" ]]; then
  EXAMPLE_FILE=".env.example"
  [[ -f ".env.sample" ]] && EXAMPLE_FILE=".env.sample"
  if [[ -f ".env" ]]; then
    MISSING_VARS=$(comm -23 \
      <(grep -oP '^[A-Z_][A-Z0-9_]+(?==)' "$EXAMPLE_FILE" | sort) \
      <(grep -oP '^[A-Z_][A-Z0-9_]+(?==)' .env | sort) 2>/dev/null || true)
    [[ -n "$MISSING_VARS" ]] && \
      error "Variáveis ausentes no .env: $(echo $MISSING_VARS | tr '\n' ' ')" || \
      ok ".env completo"
  else
    warning ".env não encontrado mas ${EXAMPLE_FILE} existe"
  fi
elif [[ -f ".env" ]]; then
  suggestion "Crie .env.example para documentar variáveis necessárias"
else
  suggestion "Sem .env encontrado"
fi

if [[ -f ".gitignore" ]]; then
  grep -q "^\.env$\|^\.env\.local\|^\.env\.\*" .gitignore 2>/dev/null && \
    ok ".env está no .gitignore" || \
    error ".env NÃO está no .gitignore — risco de vazar secrets!"
fi

# ════════════════════════════════════════════════════════════════════════════
# 8. DEPENDÊNCIAS
# ════════════════════════════════════════════════════════════════════════════
section "8/12 · Dependências — Saúde e Compatibilidade"

if [[ "$PM" == "npm" ]]; then
  OUTDATED=$(npm outdated --json 2>/dev/null || echo '{}')
  OUTDATED_COUNT=$(echo "$OUTDATED" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
  [[ "$OUTDATED_COUNT" -gt 0 ]] && \
    suggestion "$OUTDATED_COUNT dependência(s) desatualizada(s) — rode npm outdated" || \
    ok "Dependências atualizadas"
fi

if [[ -n "$BROWSER" ]]; then
  BL_OUT=$(npx browserslist "$BROWSER" 2>/dev/null || true)
  [[ -n "$BL_OUT" ]] && ok "Browserslist '$BROWSER': $BL_OUT" || \
    warning "Browserslist: '$BROWSER' não reconhecido"
elif [[ -f ".browserslistrc" ]] || grep -q '"browserslist"' package.json 2>/dev/null; then
  ok "Browserslist configurado"
else
  suggestion "Adicione .browserslistrc para definir suporte a navegadores"
fi

if [[ -f ".nvmrc" ]] || [[ -f ".node-version" ]]; then
  ok "Versão do Node fixada (.nvmrc / .node-version)"
else
  suggestion "Adicione .nvmrc para fixar a versão do Node"
fi

# ════════════════════════════════════════════════════════════════════════════
# 9. QUALIDADE DE CÓDIGO
# ════════════════════════════════════════════════════════════════════════════
section "9/12 · Qualidade de Código"

CONSOLE=$(grep -rn "console\.log\|console\.warn\|console\.error" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  "$SRC_DIR" 2>/dev/null | grep -v node_modules | grep -v "// " || true)
C_COUNT=$(echo "$CONSOLE" | grep -c "console\." || true)
[[ $C_COUNT -gt 0 ]] && \
  warning "$C_COUNT console.log/warn/error no código de produção" || \
  ok "Sem console.log no código"

TODOS=$(grep -rn "TODO\|FIXME\|HACK\|XXX\|@ts-ignore\|@ts-nocheck" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  "$SRC_DIR" 2>/dev/null | grep -v node_modules | wc -l || echo "0")
[[ "$TODOS" -gt 0 ]] && \
  suggestion "$TODOS comentário(s) TODO/FIXME/HACK/@ts-ignore pendentes" || \
  ok "Sem TODOs pendentes"

if [[ -f "tsconfig.json" ]]; then
  TS_ANY=$(grep -rn ": any\b\|as any\b\|<any>" \
    --include="*.ts" --include="*.tsx" "$SRC_DIR" 2>/dev/null | \
    grep -v node_modules | grep -v "//.*any" | wc -l || echo "0")
  [[ "$TS_ANY" -gt 5 ]] && \
    warning "$TS_ANY uso(s) de 'any' — substitua por tipos específicos" || \
    ok "Uso de 'any' aceitável ($TS_ANY ocorrências)"
fi

LARGE=$(find "$SRC_DIR" \
  \( -name "*.tsx" -o -name "*.jsx" -o -name "*.ts" -o -name "*.js" \) \
  2>/dev/null | grep -v node_modules | \
  xargs wc -l 2>/dev/null | \
  awk '$1 > 300 && !/total/ {print $2 " (" $1 " linhas)"}' || true)
LARGE_COUNT=$(echo "$LARGE" | grep -c "linhas" || true)
[[ $LARGE_COUNT -gt 0 ]] && \
  suggestion "$LARGE_COUNT arquivo(s) com mais de 300 linhas — divida em componentes" || \
  ok "Nenhum arquivo excessivamente grande"

# ════════════════════════════════════════════════════════════════════════════
# 10. PERFORMANCE
# ════════════════════════════════════════════════════════════════════════════
section "10/12 · Performance"

IMG_LAZY=$(grep -rn "<img\|<Image" \
  --include="*.tsx" --include="*.jsx" --include="*.html" \
  "$SRC_DIR" 2>/dev/null | \
  grep -v 'loading="lazy"\|priority\|eager' || true)
IMG_LAZY_COUNT=$(echo "$IMG_LAZY" | grep -c "<img\|<Image" || true)
[[ $IMG_LAZY_COUNT -gt 0 ]] && \
  suggestion "$IMG_LAZY_COUNT imagem(ns) sem loading='lazy' / priority" || \
  ok "Imagens com lazy loading"

EFFECT_NO_DEPS=$(grep -rn "useEffect(" \
  --include="*.tsx" --include="*.jsx" --include="*.ts" \
  "$SRC_DIR" 2>/dev/null | \
  grep -v "//\|node_modules" | \
  python3 -c "
import sys
count = 0
lines = sys.stdin.readlines()
for i, line in enumerate(lines):
    if 'useEffect(' in line and i+2 < len(lines):
        next_lines = ''.join(lines[i:i+5])
        if '], [])' not in next_lines and '], [' not in next_lines and '})' in next_lines:
            count += 1
print(count)
" 2>/dev/null || echo "0")
[[ "$EFFECT_NO_DEPS" -gt 0 ]] && \
  suggestion "$EFFECT_NO_DEPS useEffect(s) possivelmente sem array de deps" || \
  ok "useEffect com arrays de dependência"

if [[ -d "node_modules" ]]; then
  NM_SIZE=$(du -sm node_modules 2>/dev/null | cut -f1 || echo "0")
  [[ "$NM_SIZE" -gt 500 ]] && \
    suggestion "node_modules: ${NM_SIZE}MB — considere tree-shaking" || \
    ok "node_modules: ${NM_SIZE}MB (normal)"
fi

# ════════════════════════════════════════════════════════════════════════════
# 11. TESTES
# ════════════════════════════════════════════════════════════════════════════
section "11/12 · Testes"

TEST_FW="nenhum"
has_pkg jest   && TEST_FW="Jest"
has_pkg vitest && TEST_FW="Vitest"

if [[ "$TEST_FW" != "nenhum" ]]; then
  ok "Framework de teste: $TEST_FW"
  TEST_FILES=$(find "$SRC_DIR" \
    \( -name "*.test.tsx" -o -name "*.test.ts" \
       -o -name "*.spec.tsx" -o -name "*.spec.ts" \
       -o -name "*.test.js" -o -name "*.spec.js" \) \
    2>/dev/null | grep -v node_modules | wc -l || echo "0")
  COMP_FILES=$(find "$SRC_DIR" \
    \( -name "*.tsx" -o -name "*.jsx" \) 2>/dev/null | \
    grep -v node_modules | \
    grep -v "\.test\.\|\.spec\." | wc -l || echo "1")
  COVERAGE_PCT=$(python3 -c \
    "print(round($TEST_FILES / max($COMP_FILES,1) * 100))" 2>/dev/null || echo "0")
  [[ $COVERAGE_PCT -lt 30 ]] && \
    warning "Cobertura estimada: ~${COVERAGE_PCT}% ($TEST_FILES testes / $COMP_FILES componentes)" || \
    ok "Cobertura estimada: ~${COVERAGE_PCT}% ($TEST_FILES testes)"
  has_pkg playwright && ok "Playwright (E2E) configurado" || \
  has_pkg cypress    && ok "Cypress (E2E) configurado"   || \
    suggestion "Sem testes E2E — considere Playwright"
else
  error "Nenhum framework de teste — adicione Vitest ou Jest"
fi

# ════════════════════════════════════════════════════════════════════════════
# 12. FULL MODE (--full)
# ════════════════════════════════════════════════════════════════════════════
if [[ "$FULL" == true ]]; then
  section "12/12 · Full Mode — Análises Extras"

  if has_pkg knip; then
    _log "\n  ${DIM}Rodando Knip...${RESET}"
    KNIP_OUT=$(npx knip --reporter compact 2>&1 | head -20 || true)
    KNIP_E=$(echo "$KNIP_OUT" | grep -c "Unused\|unused" || true)
    [[ $KNIP_E -gt 0 ]] && \
      warning "Knip: $KNIP_E item(ns) não utilizados" || \
      ok "Knip: sem exports/arquivos não utilizados"
  else
    skip "Knip não disponível — npm i -D knip"
  fi

  if has_pkg jscpd; then
    _log "  ${DIM}Rodando jscpd...${RESET}"
    JSCPD_OUT=$(npx jscpd "$SRC_DIR" \
      --min-lines 8 --min-tokens 50 \
      --reporters console \
      --ignore "**/node_modules/**,**/*.test.*" \
      2>&1 | tail -5 || true)
    echo "$JSCPD_OUT" | grep -q "0 clones\|No duplicate" && \
      ok "jscpd: sem código duplicado" || \
      warning "jscpd: código duplicado detectado"
  else
    skip "jscpd não disponível — npm i -D jscpd"
  fi

  if has_pkg madge; then
    _log "  ${DIM}Rodando Madge...${RESET}"
    MADGE_OUT=$(npx madge --circular \
      --extensions ts,tsx,js,jsx "$SRC_DIR" 2>&1 || true)
    echo "$MADGE_OUT" | grep -q "No circular" && \
      ok "Madge: sem dependências circulares" || \
      warning "Madge: circulares detectadas:\n$(echo "$MADGE_OUT" | head -5)"
  else
    skip "Madge não disponível — npm i -D madge"
  fi

  if has_pkg secretlint; then
    _log "  ${DIM}Rodando secretlint...${RESET}"
    SECRET_OUT=$(npx secretlint "**/*" 2>&1 | head -10 || true)
    echo "$SECRET_OUT" | grep -q "✖\|error" && \
      error "secretlint: secrets detectados!\n$SECRET_OUT" || \
      ok "secretlint: sem secrets"
  else
    skip "secretlint não disponível — npm i -D @secretlint/secretlint"
  fi

  [[ -f "lighthouserc.json" ]] || [[ -f "lighthouserc.js" ]] && \
    ok "Lighthouse CI configurado" || \
    suggestion "Adicione lighthouserc.json para Lighthouse CI"

else
  section "12/12 · Full Mode"
  skip "Rode com --full para: Knip, jscpd, Madge, secretlint, Lighthouse CI"
fi

# ════════════════════════════════════════════════════════════════════════════
# RELATÓRIO FINAL
# ════════════════════════════════════════════════════════════════════════════
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  RELATÓRIO FINAL${RESET}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}"
echo -e "  ${RED}${BOLD}Erros críticos :${RESET} $ERRORS"
echo -e "  ${YELLOW}${BOLD}Avisos         :${RESET} $WARNINGS"
echo -e "  ${BLUE}${BOLD}Sugestões      :${RESET} $SUGGESTIONS"
echo -e "  ${DIM}Pulados        : $SKIPPED${RESET}"
echo -e "  ${DIM}Tempo          : ${ELAPSED}s${RESET}"
echo ""

SCORE_NUM=$((100 - ERRORS * 10 - WARNINGS * 3 - SUGGESTIONS * 1))
[[ $SCORE_NUM -lt 0 ]] && SCORE_NUM=0

if   [[ $SCORE_NUM -ge 90 ]]; then
  echo -e "  ${GREEN}${BOLD}✨ SCORE: ${SCORE_NUM}/100 — Frontend saudável!${RESET}"
elif [[ $SCORE_NUM -ge 70 ]]; then
  echo -e "  ${YELLOW}${BOLD}⚡ SCORE: ${SCORE_NUM}/100 — Bom, pequenos ajustes${RESET}"
elif [[ $SCORE_NUM -ge 50 ]]; then
  echo -e "  ${YELLOW}${BOLD}⚠  SCORE: ${SCORE_NUM}/100 — Revisão recomendada${RESET}"
else
  echo -e "  ${RED}${BOLD}✖  SCORE: ${SCORE_NUM}/100 — Correções obrigatórias${RESET}"
fi
echo ""

# ── Salvar JSON ───────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  python3 - <<PYEOF
import json, datetime
data = {
    "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
    "framework": "${FRAMEWORK}",
    "package_manager": "${PM}",
    "score": ${SCORE_NUM},
    "summary": {
        "errors": ${ERRORS},
        "warnings": ${WARNINGS},
        "suggestions": ${SUGGESTIONS},
        "skipped": ${SKIPPED},
        "elapsed_seconds": ${ELAPSED}
    },
    "strict": ${STRICT},
    "full": ${FULL}
}
with open("${OUTPUT}", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print(f"  📄 Relatório salvo em: ${OUTPUT}")
PYEOF
fi

# ── Exit codes CI/CD ──────────────────────────────────────────────────────────
if [[ "$STRICT" == true ]]; then
  [[ $ERRORS -gt 0 || $WARNINGS -gt 0 ]] && exit 1
fi
[[ $ERRORS -gt 0 ]] && exit 1
exit 0
