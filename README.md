ferramentas para complementar o `analyze-frontend.sh`:

***

## 🔍 Análise Estática & Qualidade

| Ferramenta | Instalar | Para quê |
|---|---|---|
| **[Knip](https://github.com/webpro/knip)** | `npm i -D knip` | Detecta exports, arquivos e deps não usados — muito mais preciso que depcheck  [github](https://github.com/topics/code-quality?l=typescript) |
| **[jscpd](https://github.com/kucherenko/jscpd)** | `npm i -D jscpd` | Copy-paste detector — encontra código duplicado em todo o projeto  [github](https://github.com/topics/code-quality?l=typescript) |
| **[SonarJS](https://github.com/SonarSource/SonarJS)** | `npx sonarqube-scanner` | Análise profunda de bugs, code smells e vulnerabilidades em JS/TS  [github](https://github.com/topics/code-quality?l=typescript) |
| **[Madge](https://github.com/pahen/madge)** | `npm i -D madge` | Visualiza dependências circulares entre módulos |

***

## ⚡ Performance

| Ferramenta | Comando | Para quê |
|---|---|---|
| **[Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)** | `npm i -g @lhci/cli` | Roda Lighthouse no CI/CD — score de performance, acessibilidade, SEO  [javascript.plainenglish](https://javascript.plainenglish.io/the-2025-frontend-performance-toolkit-10-must-have-tools-youre-probably-not-using-0094d64ff04e) |
| **[Bundlephobia CLI](https://bundlephobia.com)** | `npx bundlephobia <pkg>` | Custo de cada dependência no bundle antes de instalar |
| **[source-map-explorer](https://github.com/danvk/source-map-explorer)** | `npx source-map-explorer` | Visualiza o que está pesando no bundle final |

***

## 🧪 Testes

| Ferramenta | Para quê |
|---|---|
| **[Vitest](https://vitest.dev)** | Substitui Jest — muito mais rápido, nativo com Vite  [requestly](https://requestly.com/guides/best-tools-for-frontend-developers-in-2025/) |
| **[Playwright](https://playwright.dev)** | E2E moderno — testa Chrome, Firefox e Safari com uma API só |
| **[axe-core](https://github.com/dequelabs/axe-core)** | Testes de acessibilidade automáticos integrados ao Jest/Playwright |

***

## 🔒 Segurança

```bash
# Audit completo (vai além do npm audit)
npx better-npm-audit

# Detecta secrets/tokens acidentalmente commitados
npx secretlint "**/*"
```

***

## Integração no `analyze-frontend.sh`

Os três que mais valem adicionar ao script atual:

```bash
# No início do script — adicionar essas seções:

# Seção 10: Código duplicado
npx jscpd . --min-lines 10 --reporters console --ignore "**/node_modules/**"

# Seção 11: Exports/arquivos não usados
npx knip --reporter compact

# Seção 12: Dependências circulares
npx madge --circular --extensions ts,tsx src/
```

O **Knip** + **jscpd** são os que trazem o maior retorno imediato para projetos React/Next.js. [github](https://github.com/topics/code-quality?l=typescript)
