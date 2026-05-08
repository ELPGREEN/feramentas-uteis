text
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

## 📄 Licença
MIT © [ELPGREEN](https://github.com/ELPGREEN)
