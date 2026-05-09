# 🔭 Frontend Analyzer

Análise estática completa para projetos frontend modernos.

## Instalação

```bash
cp analyze-frontend.sh /seu-projeto/scripts/
chmod +x /seu-projeto/scripts/analyze-frontend.sh
```

Adicione ao `package.json`:

```json
{
  "scripts": {
    "analyze":         "bash scripts/analyze-frontend.sh",
    "analyze:strict":  "bash scripts/analyze-frontend.sh --strict",
    "analyze:fix":     "bash scripts/analyze-frontend.sh --fix",
    "analyze:ci":      "bash scripts/analyze-frontend.sh --strict --output report.json",
    "analyze:full":    "bash scripts/analyze-frontend.sh --full"
  }
}
```

## Módulos

| # | Módulo | O que verifica |
|---|---|---|
| 1 | TypeScript | tsc --noEmit |
| 2 | ESLint | JS/TS/JSX |
| 3 | Prettier | Formatação |
| 4 | Stylelint | CSS/SCSS |
| 5 | Acessibilidade | alt, aria-label, noopener |
| 6 | Segurança | npm audit, secrets, eval, XSS |
| 7 | Env vars | .env vs .env.example |
| 8 | Dependências | outdated, Browserslist |
| 9 | Qualidade | console.log, TODO, any |
| 10 | Performance | lazy loading, useEffect |
| 11 | Testes | cobertura estimada, E2E |
| 12 | Full mode | Knip, jscpd, Madge, secretlint |
