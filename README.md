# feramentas-uteis
comando para um editor de frontend que realize uma análise abrangente e automatizada do código frontend,
🔍 Análise Estática & Qualidade
Ferramenta	Instalar	Para quê
Knip	npm i -D knip	Detecta exports, arquivos e deps não usados — muito mais preciso que depcheck 
jscpd	npm i -D jscpd	Copy-paste detector — encontra código duplicado em todo o projeto 
SonarJS	npx sonarqube-scanner	Análise profunda de bugs, code smells e vulnerabilidades em JS/TS 
Madge	npm i -D madge	Visualiza dependências circulares entre módulos
⚡ Performance
Ferramenta	Comando	Para quê
Lighthouse CI	npm i -g @lhci/cli	Roda Lighthouse no CI/CD — score de performance, acessibilidade, SEO 
Bundlephobia CLI	npx bundlephobia <pkg>	Custo de cada dependência no bundle antes de instalar
source-map-explorer	npx source-map-explorer	Visualiza o que está pesando no bundle final
🧪 Testes
Ferramenta	Para quê
Ferramenta	Para quê
Vitest	Substitui Jest — muito mais rápido, nativo com Vite 
Playwright	E2E moderno — testa Chrome, Firefox e Safari com uma API só
axe-core	Testes de acessibilidade automáticos integrados ao Jest/Playwright
