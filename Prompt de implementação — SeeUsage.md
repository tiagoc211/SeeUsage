# SEEUSAGE — IMPLEMENTAÇÃO COMPLETA

Estás a trabalhar num repositório Git limpo chamado:

`seeusage`

A tua missão é construir, testar, polir e entregar uma aplicação macOS completamente funcional chamada **SeeUsage**.

Não quero um scaffold, mockup ou proof of concept. Trabalha até existir uma aplicação utilizável e empacotável que obtenha dados reais do Codex e do Antigravity instalados nesta máquina.

Podes:

- criar, alterar e eliminar ficheiros dentro do repositório;
- executar comandos;
- investigar os CLIs instalados;
- consultar documentação e código open-source;
- clonar referências para `/tmp`;
- compilar;
- executar testes;
- lançar a aplicação;
- corrigir bugs;
- fazer commits Git intermédios e finais.

Não peças confirmação para decisões normais de implementação. Escolhe a solução mais simples e robusta e continua até o produto estar funcional.

---

# 1. PRINCÍPIO MAIS IMPORTANTE: CÓDIGO MÍNIMO

Quero o código **o mais limpo, pequeno, direto e funcional possível**.

Este requisito tem prioridade elevada em todas as decisões técnicas.

Não quero:

- abstrações sem necessidade real;
- arquitetura enterprise;
- protocolos criados “porque podem ser úteis no futuro”;
- classes wrapper que só chamam outra classe;
- camadas artificiais;
- factories desnecessárias;
- dependency injection frameworks;
- state management complexo;
- ficheiros com 20 linhas que podiam fazer parte de outro ficheiro coerente;
- genericização prematura;
- padrões de design usados apenas por estética;
- código duplicado;
- comentários a explicar código óbvio;
- features especulativas;
- dependências externas que possam ser evitadas.

Regra geral:

```text
a solução mais pequena que seja robusta
>
uma solução mais sofisticada teoricamente extensível
```

Antes de criar uma abstração pergunta:

```text
Isto resolve um problema real que já existe nesta aplicação?
```

Se a resposta for não, não a cries.

Objetivo:

```text
mínimo de código
+
mínimo de dependências
+
mínimo de processos
+
mínimo de estado
+
máxima legibilidade
+
dados corretos
```

Não otimizes para quantidade de código produzido.

O melhor resultado pode ser uma aplicação relativamente pequena.

---

# 2. AMBIENTE CONDA OBRIGATÓRIO

Existe nesta máquina um ambiente Conda dedicado chamado:

```bash
seeu
```

Todo o trabalho de desenvolvimento que possa razoavelmente correr dentro deste ambiente deve ser executado nele.

Logo no início verifica:

```bash
conda env list
```

e confirma a existência de:

```text
seeu
```

Depois trabalha preferencialmente através de:

```bash
conda run -n seeu <comando>
```

ou, numa shell dedicada:

```bash
conda activate seeu
```

Exemplos:

```bash
conda run -n seeu git status
conda run -n seeu swift --version
conda run -n seeu swift build
conda run -n seeu swift test
```

Se determinadas ferramentas nativas do macOS não fizerem parte conceptualmente do ambiente Conda, é aceitável executá-las diretamente.

Exemplos:

```text
open
xcodebuild
codesign
plutil
osascript
```

O mesmo se aplica a CLIs externos cuja instalação esteja fora do Conda:

```text
codex
agy
```

Mas o ambiente de desenvolvimento dedicado deve ser `seeu`.

Não cries outro virtualenv.

Não cries outro ambiente Conda.

Não instales ferramentas globalmente sem necessidade.

Se precisares de uma ferramenta auxiliar e ela puder ser instalada de forma limpa no `seeu`, usa esse ambiente.

No relatório final indica claramente que o desenvolvimento e testes foram feitos através do ambiente:

```text
seeu
```

---

# 3. OBJETIVO DO PRODUTO

SeeUsage deve ser uma pequena aplicação **nativa macOS**, residente na barra de menus, que mostra num único local:

## Codex

Usage/quota de **vários perfis Codex simultaneamente**, mesmo com planos diferentes.

Neste computador podem existir:

```text
~/.codex-profiles/pessoal
~/.codex-profiles/trabalho
```

Cada diretório é um `CODEX_HOME` independente.

O utilizador pode ter aliases como:

```text
cxp
cxt
```

mas a aplicação não deve depender deles.

Tem de consultar vários perfis sem:

- mudar a conta ativa;
- substituir `auth.json`;
- copiar tokens;
- fazer logout/login;
- modificar os perfis;
- interferir com sessões Codex abertas.

## Antigravity

Mostrar usage/quota da conta atualmente autenticada através do Antigravity CLI:

```text
agy
```

A v1 não precisa de gerir múltiplas contas Antigravity.

---

# 4. SEEUSAGE É READ-ONLY

SeeUsage é um monitor.

Não é:

- account switcher;
- gestor OAuth;
- wrapper para sessões Codex;
- wrapper para sessões Antigravity.

Nunca alterar autenticação para consultar usage.

---

# 5. PESQUISA ANTES DA IMPLEMENTAÇÃO

Antes de implementar os providers, analisa implementações existentes.

Clona referências apenas para `/tmp`, nunca para dentro do repo.

Por exemplo:

```bash
gh repo clone johnkueh/usage-bar /tmp/usage-bar
gh repo clone vlondon/AgentUsage /tmp/AgentUsage
gh repo clone openai/codex /tmp/openai-codex
```

Também podes consultar, se forem úteis:

```text
sameerbajaj/CodexAccounts
CodePrometheus/codex-buddy
vulonviing/agents-deck
shyim/agm
tnduyh5/agy-tools
```

Analisa principalmente:

- obtenção de rate limits;
- múltiplos `CODEX_HOME`;
- execução de subprocessos;
- resolução do caminho de executáveis;
- protocolo do `codex app-server`;
- `/usage` do Antigravity;
- timeouts;
- menu bar nativa.

Não copies arquiteturas inteiras.

Extrai apenas as ideias necessárias.

Se duas implementações fizerem a mesma coisa e uma tiver 30 linhas enquanto outra tiver 200, privilegia a solução simples se tiver a mesma robustez.

---

# 6. STACK

Implementa com:

```text
Swift 6
SwiftUI
macOS 14+
Foundation
Swift Package Manager
AppKit apenas quando necessário
```

Usa:

```swift
MenuBarExtra
```

Evita dependências externas.

Não usar:

```text
Electron
React
Tauri
Node backend
Python GUI
localhost server
WebView
Docker
```

Esta aplicação é suficientemente pequena para ser nativa.

---

# 7. TAMANHO E ORGANIZAÇÃO DO CÓDIGO

Não cries uma árvore enorme só porque existe neste prompt uma possível arquitetura.

Usa o **menor número razoável de ficheiros**.

Uma estrutura aceitável pode ser algo como:

```text
seeusage/
├── Package.swift
├── README.md
├── Sources/
│   └── SeeUsage/
│       ├── SeeUsageApp.swift
│       ├── Models.swift
│       ├── UsageStore.swift
│       ├── CodexClient.swift
│       ├── AntigravityClient.swift
│       ├── ProcessRunner.swift
│       ├── Settings.swift
│       └── Views.swift
├── Tests/
│   └── SeeUsageTests/
└── scripts/
    ├── build_app.sh
    └── install.sh
```

Isto é apenas uma referência.

Se conseguires fazer melhor com menos ficheiros, faz.

Se um ficheiro crescer demasiado ou misturar responsabilidades, divide-o.

Objetivo:

```text
cada ficheiro existe porque torna o código mais simples
```

e não porque uma arquitetura típica diz que deve existir.

---

# 8. MODELO DE DADOS

Codex e Antigravity devem convergir para um pequeno modelo comum.

Algo conceptualmente semelhante a:

```swift
enum ProviderKind: String, Codable {
    case codex
    case antigravity
}

struct UsageProfile: Identifiable, Codable {
    let id: UUID
    var provider: ProviderKind
    var name: String
    var homePath: String?
}

struct UsageWindow: Identifiable {
    let id: String
    let label: String
    let remainingPercent: Double?
    let durationMinutes: Int?
    let resetsAt: Date?
    let scope: String?
}

struct UsageSnapshot {
    let profileID: UUID
    let plan: String?
    let windows: [UsageWindow]
    let fetchedAt: Date
    let error: String?
}
```

Mantém apenas os campos necessários.

Não reproduzas DTOs gigantes dos providers.

---

# 9. CODEX — NÃO LER CREDENCIAIS

Não abras nem interpretes:

```text
auth.json
```

Pode ser usado apenas para detetar que um diretório parece ser um `CODEX_HOME`.

Nunca:

- imprimir conteúdo;
- guardar tokens;
- copiar tokens;
- fazer parsing de OAuth;
- chamar APIs privadas diretamente.

---

# 10. CODEX — FONTE DE DADOS

Usa o Codex oficial através de:

```bash
CODEX_HOME="/perfil" codex app-server --stdio
```

Confirma a sintaxe da versão realmente instalada.

Para cada perfil:

```text
CODEX_HOME isolado
↓
codex app-server
↓
JSON-RPC
↓
account/rateLimits/read
```

Usa `Process`.

Não uses:

```bash
sh -c
```

Configura diretamente:

```swift
process.executableURL
process.arguments
process.environment
```

Herda o ambiente atual e muda apenas:

```text
CODEX_HOME
```

---

# 11. CODEX — PROCESSO TEMPORÁRIO

Não mantenhas vários app-servers permanentemente a correr.

A cada refresh:

```text
spawn
→ initialize
→ rateLimits/read
→ opcional account/usage/read
→ fechar processo
```

Isto mantém o código muito mais pequeno.

O refresh será pouco frequente, portanto não existe razão para gerir daemons persistentes.

Depois do refresh não devem permanecer processos órfãos.

---

# 12. CODEX — JSON-RPC

Confirma o protocolo atual no código do Codex instalado/repositório.

A sequência esperada é equivalente a:

```json
{"id":1,"method":"initialize","params":{"clientInfo":{"name":"seeusage","version":"1.0"}}}
```

depois:

```json
{"method":"initialized","params":{}}
```

depois:

```json
{"id":2,"method":"account/rateLimits/read"}
```

Opcionalmente, se disponível:

```json
{"id":3,"method":"account/usage/read"}
```

e eventualmente:

```json
{
  "id":4,
  "method":"account/read",
  "params":{"refreshToken":false}
}
```

Não assumes que estes payloads permanecem exatamente iguais.

Verifica a versão atual.

---

# 13. CODEX — RATE LIMITS

A fonte de verdade é:

```text
account/rateLimits/read
```

Suporta respostas atuais como:

```text
rateLimits
```

e:

```text
rateLimitsByLimitId
```

Não hardcodes:

```text
primary = 5h
secondary = weekly
```

Utiliza:

```text
windowDurationMins
```

Uma quota pode ter:

```text
300
10080
```

ou qualquer outra duração.

Humaniza genericamente:

```text
60      → 1 h
300     → 5 h
1440    → 24 h
10080   → 7 dias
```

Não descartes janelas desconhecidas.

---

# 14. PERCENTAGENS CODEX

Se o provider devolver:

```text
usedPercent
```

a UI deve apresentar principalmente:

```text
remaining = 100 - usedPercent
```

com clamp:

```text
0...100
```

Exemplo:

```text
usedPercent = 27
→
73% restante
```

Mantém a semântica clara.

---

# 15. RESET CODEX

Se existir:

```text
resetsAt
```

converte para `Date`.

Apresenta no timezone local.

Exemplos:

```text
Reset em 2 h 14 min
Reset amanhã às 18:00
Reset sexta às 10:30
```

Não cries um sistema complexo para isto.

Uma função pequena de formatação chega.

---

# 16. PLANO CODEX

Se o response fornecer:

```text
planType
```

mostra:

```text
Pro
Plus
Team
```

Se não existir, omite.

Não inventes informação de subscrição.

---

# 17. ACCOUNT/USAGE/READ

Se a versão atual do Codex suportar de forma simples:

```text
account/usage/read
```

podes obter:

- tokens acumulados;
- daily buckets;
- atividade recente.

Mas esta funcionalidade é secundária.

Se acrescentar demasiada complexidade, deixa-a fora da primeira implementação.

Prioridade absoluta:

```text
rate limits corretos
```

---

# 18. DESCOBERTA DE PERFIS CODEX

No primeiro arranque verifica:

```text
~/.codex
~/.codex-profiles/*
```

Considera sinais como:

```text
auth.json
config.toml
state.sqlite
sessions/
```

Não precisas de todos.

Perfis como:

```text
~/.codex-profiles/pessoal
~/.codex-profiles/trabalho
```

devem ser detetados automaticamente.

Nome inicial:

```text
pessoal → Pessoal
trabalho → Trabalho
```

---

# 19. ADICIONAR PERFIL MANUALMENTE

Settings:

```text
+ Adicionar perfil Codex
```

Usa `NSOpenPanel`.

Guarda apenas:

```text
id
nome
path
```

Permite:

```text
renomear
remover da SeeUsage
```

Nunca apagues a pasta real.

---

# 20. ANTIGRAVITY

Usa o CLI oficial.

Consulta read-only:

```bash
agy -p "/usage" --output-format text --print-timeout 30s
```

Confirma a sintaxe instalada com:

```bash
agy --help
agy --version
```

Não uses prompts normais.

Não inicies conversa.

Não gastes quota de inferência.

---

# 21. PARSER ANTIGRAVITY

Analisa a implementação atual do AgentUsage.

O parser deve aceitar scopes existentes como:

```text
Gemini
Claude/GPT
```

mas não deve depender exclusivamente desses nomes.

Qualquer scope novo deve poder ser mostrado.

Normaliza para:

```text
label
scope
remainingPercent
reset
```

Ignora whitespace e headers conhecidos.

Se o formato for inesperado, devolve um erro claro.

Não cries parsing excessivamente sofisticado para casos hipotéticos.

---

# 22. JSON DO ANTIGRAVITY

Investiga:

```bash
agy -p "/usage" --output-format json
```

Se a versão instalada devolver JSON claramente estruturado e estável:

```text
usa JSON
```

Se o texto tab-separated for mais simples e comprovadamente robusto:

```text
usa text
```

Não mantenhas dois parsers grandes só “por segurança”.

Escolhe a implementação mais pequena que funcione corretamente.

---

# 23. MULTI-ACCOUNT ANTIGRAVITY

Não implementar nesta versão.

Não:

- manipular Keychain;
- copiar OAuth;
- substituir credenciais;
- alterar `state.vscdb`;
- reiniciar IDE;
- fazer account switching.

A app monitoriza apenas a identidade atualmente autenticada no `agy`.

---

# 24. RESOLVER EXECUTÁVEIS

Uma app aberta pelo Finder pode não receber o PATH do terminal.

Resolve:

```text
codex
agy
```

Verifica, de forma simples:

1. override manual;
2. `PATH`;
3. locais conhecidos.

Inclui pelo menos:

```text
/opt/homebrew/bin
/usr/local/bin
/usr/bin
/bin
~/.local/bin
~/.bun/bin
~/.volta/bin
~/.asdf/shims
~/.local/share/mise/shims
```

e, se necessário:

```text
~/.nvm/versions/node/*/bin
```

Não cries um resolver enorme.

Uma função curta que procure os locais razoáveis é suficiente.

Apple Silicon torna:

```text
/opt/homebrew/bin
```

especialmente importante.

---

# 25. EXECUÇÃO DE PROCESSOS

Cria uma pequena função/helper reutilizável para:

```text
executable
arguments
environment
stdin
timeout
```

Resultado:

```text
stdout
stderr
exitCode
```

Requisitos:

- assíncrono;
- não bloquear MainActor;
- timeout;
- matar processo em timeout;
- não deixar zombies;
- não usar shell.

Só cria um protocolo/mock abstraction se for realmente necessário para testes.

Prefere a versão mais pequena possível.

---

# 26. TIMEOUTS

Valores iniciais:

```text
Codex: 15 s
Antigravity: 35 s
```

Ajusta apenas se os testes reais mostrarem necessidade.

---

# 27. CONCORRÊNCIA

Se existirem:

```text
Codex Pessoal
Codex Trabalho
Antigravity
```

consulta-os em paralelo com Swift concurrency.

Pode ser:

```swift
withTaskGroup
```

ou alternativa ainda mais simples.

Falhas são independentes.

Exemplo:

```text
Pessoal       OK
Trabalho      erro
Antigravity   OK
```

A UI não deve falhar toda.

---

# 28. CACHE

Mantém a última snapshot válida em memória.

Persistência em disco só se puder ser implementada de maneira pequena e limpa.

Se persistires:

```text
~/Library/Application Support/SeeUsage/
```

Guarda apenas dados não sensíveis.

Nunca guardar:

```text
tokens OAuth
cookies
auth.json
prompts
conversas
```

Se o provider falhar e houver dados antigos:

```text
mostrar último valor
+
Desatualizado
```

---

# 29. CONFIGURAÇÃO

Configuração mínima:

```text
perfis Codex
override codex path
override agy path
refresh interval
```

Persistência simples.

`UserDefaults` é aceitável se chegar para estes dados.

Não introduzas uma base de dados.

---

# 30. REFRESH

Refresh:

```text
ao abrir
manual
automático
```

Default:

```text
5 minutos
```

Opções razoáveis:

```text
5
10
15
30 minutos
```

Não fazer polling agressivo.

Evita dois refreshes simultâneos.

---

# 31. UI

Interface pequena e nativa.

Aproximadamente:

```text
360–420 px
```

Evita:

- cards gigantes;
- dashboard SaaS;
- glassmorphism;
- gradientes;
- animações inúteis;
- aspeto “gerado por IA”.

Usa:

```text
SwiftUI
SF Symbols
fontes do sistema
spacing consistente
```

---

# 32. MENU BAR

Usa:

```swift
MenuBarExtra
```

A barra pode mostrar um símbolo simples.

Opcionalmente:

```text
42%
```

representando a **menor quota restante**, nunca média.

Assim:

```text
Pessoal 80%
Trabalho 42%
Antigravity 75%

Menu bar → 42%
```

---

# 33. CONTEÚDO DO POPOVER

Uma referência:

```text
SeeUsage                     ↻  ⚙︎
Atualizado há 1 min

CODEX

Pessoal                       Pro
5 h        ███████░░░   73%
           Reset em 2 h

7 dias     █████░░░░░   51%
           Reset sexta


Trabalho                     Plus
5 h        █████████░   91%

7 dias     ███████░░░   68%


ANTIGRAVITY

Gemini
████████░░ 82%

Claude / GPT
█████░░░░░ 53%
```

Não precisas de copiar exatamente.

Privilegia densidade e legibilidade.

---

# 34. COMPONENTES UI

Não dividas a UI em dezenas de componentes.

Extrai apenas componentes realmente reutilizados, por exemplo:

```text
UsageBar
ProfileSection
```

Se uma View só é usada uma vez e tem poucas linhas, pode permanecer no mesmo ficheiro.

---

# 35. ESTADOS DE ERRO

Mensagens simples.

Codex não encontrado:

```text
Codex CLI não encontrado.
```

Perfil sem autenticação:

```text
Perfil Codex não autenticado.
```

Antigravity não encontrado:

```text
Antigravity CLI não encontrado.
```

Antigravity não autenticado:

```text
Inicia sessão no Antigravity CLI.
```

Formato inesperado:

```text
Não foi possível interpretar a usage.
```

Timeout:

```text
Tempo limite excedido.
```

Sem stack traces na UI.

---

# 36. SETTINGS

Settings simples.

### Codex

```text
Pessoal
~/.codex-profiles/pessoal

Trabalho
~/.codex-profiles/trabalho

+ Adicionar perfil
```

### Executáveis

```text
Codex: Auto (...)
Antigravity: Auto (...)
```

### Refresh

```text
5 min
10 min
15 min
30 min
```

Não acrescentes settings desnecessários.

---

# 37. PRIVACIDADE

Sem:

```text
analytics
telemetria
Sentry
Firebase
tracking
servidor próprio
```

Toda a aplicação é local.

Comunicação externa ocorre através dos próprios CLIs oficiais.

---

# 38. LOGGING

Usa `Logger` apenas se ajudar realmente.

Nunca logar:

```text
tokens
auth.json
cookies
credenciais
```

Logs de diagnóstico podem conter:

```text
provider
perfil
exit code
duração
tipo de erro
```

Não cries infraestrutura de logging própria.

---

# 39. TESTES

Os testes devem focar as partes que podem realmente quebrar.

Não testes getters triviais.

## Codex

Cria fixtures para:

```text
rateLimits
rateLimitsByLimitId
1 janela
2 janelas
janela desconhecida
usedPercent
clamp
reset ausente
plan ausente
JSON-RPC notifications antes da resposta
JSON-RPC error
```

Exemplo obrigatório:

```text
usedPercent = 23
→ remainingPercent = 77
```

## Antigravity

Cria fixture baseada no output real desta máquina, removendo dados pessoais.

Testa:

```text
múltiplos scopes
percentagens
reset
whitespace
scope desconhecido
formato inválido
```

## Processos

Testa apenas o que for útil:

```text
success
timeout
non-zero exit
```

Evita construir uma mega-infraestrutura de mocks.

---

# 40. TESTES REAIS

Verifica:

```bash
conda run -n seeu command -v swift
conda run -n seeu swift --version

command -v codex
codex --version

command -v agy
agy --version
```

Podes verificar perfis:

```bash
find ~/.codex-profiles -maxdepth 2 -name auth.json -print
```

Nunca fazer:

```bash
cat ~/.codex-profiles/.../auth.json
```

Testa cada `CODEX_HOME` usando apenas app-server read-only.

Testa:

```bash
agy -p "/usage" --output-format text --print-timeout 30s
```

---

# 41. NÃO GASTAR QUOTA

Durante desenvolvimento/testes não executar:

```bash
codex exec "..."
agy -p "normal prompt"
```

Não precisamos de inferência.

Apenas operações de usage/read-only.

---

# 42. ROBUSTEZ SEM OVERENGINEERING

Os providers vão mudar.

Centraliza o parsing.

Mas não cries uma framework.

Fluxo simples:

```text
output do provider
↓
parser
↓
UsageSnapshot
↓
UI
```

Campos desconhecidos devem normalmente ser ignorados.

Novas janelas de quota devem aparecer sem hardcode.

---

# 43. PERFORMANCE

Quando idle, SeeUsage deve praticamente não fazer trabalho.

Não:

- manter app-server permanente;
- fazer polling frequente;
- usar WebView;
- manter Node;
- criar filesystem watchers;
- criar DB.

Refresh:

```text
spawn concorrente
→ recolher usage
→ fechar processos
→ atualizar UI
→ idle
```

---

# 44. BUILD

Todo o build normal deve ser executado preferencialmente no ambiente:

```text
seeu
```

Exemplos:

```bash
conda run -n seeu swift build
conda run -n seeu swift test
conda run -n seeu swift build -c release
```

Se o Swift toolchain for necessariamente externo ao Conda, isso não invalida o requisito: o processo de desenvolvimento continua iniciado a partir do ambiente `seeu`.

Documenta qualquer exceção real.

---

# 45. APP BUNDLE

Cria:

```text
scripts/build_app.sh
```

que produza:

```text
dist/SeeUsage.app
```

Estrutura:

```text
SeeUsage.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   └── SeeUsage
    └── Resources/
```

Usa:

```text
LSUIElement = true
```

se adequado, para app de menu bar.

Bundle ID sugerido:

```text
app.seeusage.SeeUsage
```

Não exigir Developer ID para build local.

Ad-hoc signing é aceitável se necessário.

---

# 46. INSTALL SCRIPT

Podes criar:

```text
scripts/install.sh
```

para:

```text
build
→ criar .app
→ instalar em ~/Applications ou /Applications
```

Mantém o script curto.

---

# 47. README

README curto mas suficiente:

```text
# SeeUsage

o que é
screenshot
features
requirements
build
installation
como funciona
privacy
troubleshooting
limitations
```

Explica:

### Codex

```text
SeeUsage launches the official Codex app-server using each configured CODEX_HOME and reads account/rateLimits/read.
```

### Antigravity

```text
SeeUsage calls the official agy read-only /usage command.
```

### Privacy

```text
Credentials are never copied or stored by SeeUsage.
```

### Development

Menciona explicitamente:

```bash
conda activate seeu
```

ou:

```bash
conda run -n seeu ...
```

---

# 48. GIT

Antes de trabalhar:

```bash
pwd
git status
git log --oneline --decorate -5
```

Confirma que estás em:

```text
seeusage
```

Não fazer `git init` se `.git` já existir.

Faz commits naturais e pequenos.

Exemplo:

```text
chore: bootstrap SeeUsage

feat: read Codex usage from multiple profiles

feat: add Antigravity usage

feat: add native menu bar interface

feat: add profile settings and refresh

test: cover provider parsers

build: package macOS app

docs: document setup and architecture
```

Não forces commits artificiais apenas para aumentar a quantidade.

---

# 49. GITIGNORE

Nunca commitar:

```text
.build/
dist/
DerivedData/
.DS_Store
auth.json
tokens
local cache
local configuration
logs
```

---

# 50. CLEAN CODE PASS OBRIGATÓRIO

Quando a aplicação estiver funcional, faz uma passagem específica de simplificação.

Procura:

- funções sem uso;
- tipos sem uso;
- propriedades sem uso;
- wrappers redundantes;
- abstrações utilizadas apenas uma vez;
- código duplicado;
- comentários óbvios;
- ficheiros que podem ser combinados;
- branches impossíveis;
- fallbacks desnecessários;
- dependências que possam ser removidas.

Executa:

```text
functional implementation
↓
tests
↓
simplification pass
↓
tests novamente
```

A tarefa não é apenas fazer funcionar.

É fazer funcionar **com o mínimo de código razoável**.

Se conseguires remover 100 linhas sem perder clareza, robustez ou funcionalidades, remove-as.

---

# 51. STYLE DE CÓDIGO

Privilegia:

```swift
guard
early returns
small functions
value types
async/await
clear names
```

Evita:

```text
deep nesting
singletons globais desnecessários
callback pyramids
Any
force unwrap
force try
reflection
runtime tricks
```

Comentários devem explicar:

```text
porquê
```

não:

```text
o que esta linha faz
```

---

# 52. DEFINITION OF DONE

Não terminar até:

```bash
conda run -n seeu swift build
```

passar.

```bash
conda run -n seeu swift test
```

passar.

```bash
conda run -n seeu swift build -c release
```

passar.

E existir:

```text
dist/SeeUsage.app
```

---

# 53. VALIDAÇÃO FUNCIONAL

A aplicação deve:

### Abrir

```bash
open dist/SeeUsage.app
```

e aparecer na barra de menus.

### Codex

Detetar separadamente:

```text
~/.codex-profiles/pessoal
~/.codex-profiles/trabalho
```

quando existem.

### Isolamento

Consultar um perfil nunca altera o outro.

Não altera a conta Codex ativa do terminal.

### Dados reais

Mostrar dados reais de:

```text
account/rateLimits/read
```

### Janelas dinâmicas

Funcionar com:

```text
1
2
3+
```

janelas.

### Antigravity

Mostrar `/usage` real quando `agy` estiver autenticado.

### Falhas parciais

Se um provider falhar, os restantes continuam visíveis.

### Refresh

Manual e automático funcionam.

### Processos

Depois do refresh não ficam:

```text
codex app-server
```

órfãos.

### Privacidade

Nenhuma credencial é armazenada pela aplicação.

---

# 54. TESTE VISUAL

Abre realmente a aplicação.

Confirma:

- largura;
- clipping;
- scroll;
- alinhamento;
- percentagens;
- estados vazios;
- refresh;
- Settings;
- múltiplos perfis;
- erros.

A app deve parecer uma utility macOS normal e não uma página web.

---

# 55. NÃO IMPLEMENTAR AGORA

Não implementar salvo se for praticamente gratuito:

```text
multi-account Antigravity
account switching
Windows
Linux
cloud sync
DB histórica
analytics
notifications avançadas
widgets
Launch at Login complexo
Claude
Grok
Gemini CLI separado
```

Primeiro faz uma v1 excelente.

---

# 56. ORDEM DE PRIORIDADE

Em qualquer decisão:

```text
1. Segurança das credenciais
2. Dados corretos
3. Multi-CODEX_HOME
4. Código pequeno e limpo
5. Robustez
6. Simplicidade
7. Baixo consumo de recursos
8. UX
9. Features secundárias
```

---

# 57. ARQUITETURA FINAL PRETENDIDA

Codex:

```text
CODEX_HOME
↓
codex app-server
↓
account/rateLimits/read
↓
parse
↓
UsageSnapshot
```

Antigravity:

```text
agy
↓
/usage
↓
parse
↓
UsageSnapshot
```

UI:

```text
UsageSnapshot[]
↓
SwiftUI MenuBarExtra
```

Não é preciso muito mais do que isto.

---

# 58. SE ALGO NÃO FUNCIONAR

Investiga e corrige.

Exemplo:

```text
CLI não encontrado pela .app
→ corrigir resolução do executável
```

```text
parser falhou
→ capturar output
→ anonimizar
→ criar fixture
→ corrigir
→ regression test
```

```text
CODEX_HOME não funciona
→ comparar ambiente do subprocesso
→ corrigir
```

Não terminar com uma lista de problemas que consegues resolver.

---

# 59. RESULTADO ESPERADO

Quero conseguir executar:

```bash
conda run -n seeu ./scripts/build_app.sh
open dist/SeeUsage.app
```

e obter algo como:

```text
CODEX

Pessoal
5 h        73%
7 dias     51%

Trabalho
5 h        91%
7 dias     68%


ANTIGRAVITY

Gemini      82%
Claude/GPT  53%
```

com dados reais e sem trocar contas.

---

# 60. REVISÃO FINAL DE QUALIDADE

Antes do último commit:

1. executa todos os testes;
2. release build;
3. abre a aplicação;
4. testa providers reais;
5. testa múltiplos Codex profiles;
6. testa ausência de provider;
7. testa refresh;
8. verifica processos órfãos;
9. verifica warnings do compilador;
10. remove código morto;
11. remove abstrações redundantes;
12. remove dependências desnecessárias;
13. corre testes novamente;
14. corre release build novamente;
15. verifica `git diff`;
16. verifica `git status`.

O working tree final deve estar limpo.

---

# 61. CRITÉRIO DE SIMPLICIDADE

Antes de considerar a tarefa concluída, responde mentalmente:

```text
Se eu tivesse de reconstruir isto amanhã,
há alguma parte que fiz mais complicada do que precisava?
```

Se sim, simplifica.

Uma aplicação como SeeUsage não deve precisar de milhares e milhares de linhas para cumprir este objetivo.

Não persigas um número arbitrário de linhas, mas trata complexidade como um custo.

Prefere:

```swift
20 linhas claras
```

a:

```swift
5 tipos + 3 protocolos + 2 factories
```

quando resolvem o mesmo problema.

---

# 62. RELATÓRIO FINAL

No final responde com:

## Implementado

Resumo curto.

## Arquitetura

Explica em poucas linhas:

```text
Codex → app-server + CODEX_HOME
Antigravity → agy /usage
```

## Ambiente

Confirma utilização do:

```text
Conda env: seeu
```

e indica quaisquer exceções necessárias.

## Validação real

Que perfis/providers foram efetivamente testados.

Não mostrar emails ou credenciais.

## Testes

Resultado de:

```bash
conda run -n seeu swift test
conda run -n seeu swift build -c release
```

## App

Caminho:

```text
dist/SeeUsage.app
```

## Dimensão do projeto

Indica:

```text
número aproximado de ficheiros Swift
número aproximado de linhas Swift
dependências externas
```

Isto serve para confirmar que a solução se manteve pequena.

## Commits

```text
hash — mensagem
```

## Limitações

Apenas limitações reais ainda existentes.

A task só termina quando **SeeUsage estiver funcional, simples, testado, empacotado e com o código tão pequeno e limpo quanto razoavelmente possível**.