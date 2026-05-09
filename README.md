
# 🛠️ Ferramentas Úteis

Coleção de scripts e ferramentas para desenvolvimento frontend, backend e DevOps.  
Mantido por [@ELPGREEN](https://github.com/ELPGREEN).

---

## 📁 Estrutura
feramentas-uteis/
├── frontend/
│ ├── analyze-frontend.sh
│ └── README.md
├── backend/
│ ├── orion-vm-setup.sh
│ └── README.md
├── ci-cd/
│ ├── github-actions/
│ │ └── frontend-analysis.yml
│ └── README.md
├── scripts/
│ ├── env-check.sh
│ ├── deps-check.sh
│ └── README.md
└── README.md

text

## ⚡ Início Rápido

```bash
git clone https://github.com/ELPGREEN/feramentas-uteis.git
cd feramentas-uteis
chmod +x **/*.sh
```

## 🔭 Frontend
| Script | Descrição |
|---|---|
| [`analyze-frontend.sh`](./frontend/analyze-frontend.sh) | Análise estática completa |

## ⚙️ Backend
| Script | Descrição |
|---|---|
| [`orion-vm-setup.sh`](./backend/orion-vm-setup.sh) | Diagnóstico VM Orion GCP |

## 🚀 CI/CD
| Arquivo | Descrição |
|---|---|
| [`frontend-analysis.yml`](./ci-cd/github-actions/frontend-analysis.yml) | GitHub Actions com score em PRs |

## 🔧 Scripts
| Script | Descrição |
|---|---|
| [`env-check.sh`](./scripts/env-check.sh) | Verifica variáveis de ambiente |
| [`deps-check.sh`](./scripts/deps-check.sh) | Saúde de dependências npm |


# ─── 2. PERMISSÃO ─────────────────────────────────────────────────────────
chmod +x scripts/analyze-frontend.sh

# ─── 3. DEPENDÊNCIAS OPCIONAIS (recomendadas) ──────────────────────────────
npm install -D \
  typescript \
  eslint \
  prettier \
  stylelint \
  stylelint-config-standard \
  knip \
  jscpd \
  madge \
  @secretlint/secretlint \
  @secretlint/secretlint-rule-preset-recommend

# ─── 4. ADICIONAR SCRIPTS NO package.json ─────────────────────────────────
# Abra o package.json e adicione dentro de "scripts": { ... }
cat << 'EOF'

  "analyze":          "bash scripts/analyze-frontend.sh",
  "analyze:strict":   "bash scripts/analyze-frontend.sh --strict",
  "analyze:fix":      "bash scripts/analyze-frontend.sh --fix",
  "analyze:ci":       "bash scripts/analyze-frontend.sh --strict --output report.json",
  "analyze:full":     "bash scripts/analyze-frontend.sh --full",
  "analyze:full:ci":  "bash scripts/analyze-frontend.sh --full --strict --output report.json"

EOF

# ─── 5. USAR ──────────────────────────────────────────────────────────────

# Análise básica (12 módulos)
npm run analyze

# Análise + autocorrigir formatação ESLint/Prettier
npm run analyze:fix

# Modo rigoroso (falha no CI se tiver erro)
npm run analyze:strict

# Análise completa com Knip, jscpd, Madge, secretlint
npm run analyze:full

# Gerar relatório JSON (para CI/CD)
npm run analyze:ci
# → gera: report.json na raiz do projeto

# ─── 6. OPÇÕES AVANÇADAS (direto no shell) ─────────────────────────────────

# Sem cores (para logs de CI limpos)
bash scripts/analyze-frontend.sh --no-color

# Só mostrar resumo final
bash scripts/analyze-frontend.sh --quiet

# Salvar relatório em arquivo customizado
bash scripts/analyze-frontend.sh --output relatorio-$(date +%Y%m%d).json

# Tudo junto
bash scripts/analyze-frontend.sh --full --strict --quiet --output report.json
## 📄 Licença
MIT © [ELPGREEN](https://github.com/ELPGREEN)
