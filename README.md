# SeeUsage

Uma aplicação nativa macOS para a barra de menus que monitoriza e apresenta, num único local, as quotas e rate limits de múltiplos perfis **Codex** (`CODEX_HOME`) e do **Antigravity** (`agy`).

```text
SeeUsage                     ↻  ⚙
Atualizado agora

CODEX

Pessoal                       Plus
5 h        █████████░   90%
           Reset em 4 h 42 min

7 dias     ██████░░░░   62%
           Reset domingo às 20:56

Trabalho                      Plus
5 h        ░░░░░░░░░░    1%
           Reset em 25 min

7 dias     █████░░░░░   53%
           Reset domingo às 21:17

ANTIGRAVITY

Gemini
5 h        ██████░░░░   63%
           Reset em 1 h 2 min
7 dias     ████████░░   84%
           Reset segunda às 03:47

Claude and GPT
5 h        ██████████  100%
           Reset em 3 h 55 min
7 dias     ██████████  100%
           Reset quarta às 03:40
```

---

## Funcionalidades

- **Multi-Perfil Codex**: Consulta em simultâneo múltiplos perfis (`~/.codex-profiles/*` e `~/.codex`) com planos independentes, sem trocar a conta ativa do terminal nem tocar em `auth.json`.
- **Antigravity**: Consulta a identidade ativa no `agy` (`/usage`) suportando múltiplos modelos e quotas (Gemini, Claude, GPT).
- **Menu Bar Informativa**: Apresenta a **menor quota restante** atual (ex: `1%`), alertando para quotas críticas em tempo real.
- **Janelas Dinâmicas**: Suporta e humaniza durações genéricas de janelas (`5 h`, `24 h`, `7 dias`, etc.) e tempos relativos de reset adaptados ao fuso horário local.
- **Consulta Concorrente e Resiliente**: Atualiza todos os perfis em paralelo; se um provider falhar, os restantes continuam visíveis.
- **Processos Temporários**: Inicia processos temporários e fecha-os de imediato após a consulta, sem daemons nem processos órfãos.
- **100% Privado e Local**: Nenhuma credencial ou token é guardado, copiado ou transmitido. Sem telemetria ou servidores externos.

---

## Requisitos

- macOS 14.0+ (Sonoma ou superior)
- Apple Silicon ou Intel
- Codex CLI (`codex`) instalado
- Antigravity CLI (`agy`) instalado
- Ambiente Conda dedicado: `seeu`

---

## Como Funciona

### Codex
A SeeUsage lança temporariamente o processo oficial do Codex com o ambiente isolado do perfil pretendido:
```bash
CODEX_HOME="/path/to/profile" codex app-server --stdio
```
Comunica via JSON-RPC (`initialize` → `initialized` → `account/rateLimits/read`), extrai os limites da sessão e semanais, e termina o subprocesso imediatamente. Nenhuma credencial (`auth.json`) é lida ou modificada.

### Antigravity
A SeeUsage invoca o comando read-only do CLI oficial:
```bash
agy -p "/usage" --output-format text --print-timeout 30s
```
Interpreta as linhas estruturadas devolvidas por cada grupo de modelos e calcula as percentagens restantes sem gastar quota de inferência.

---

## Desenvolvimento e Build

O desenvolvimento e testes são realizados através do ambiente Conda `seeu`:

```bash
# Ativar o ambiente Conda
conda activate seeu

# Compilar em modo debug
conda run -n seeu swift build

# Executar a suite de testes unitários
conda run -n seeu swift test

# Compilar em modo release
conda run -n seeu swift build -c release

# Obter dump em tempo real das quotas via CLI
conda run -n seeu swift run SeeUsage --dump
```

---

## Empacotamento e Instalação

### Criar a Aplicação macOS (`dist/SeeUsage.app`)
```bash
./scripts/build_app.sh
```

### Instalar em `~/Applications`
```bash
./scripts/install.sh
```

Depois de instalado, podes abrir diretamente a aplicação:
```bash
open ~/Applications/SeeUsage.app
```

---

## Privacidade e Segurança

- **Zero Storage de Credenciais**: A SeeUsage não lê, não persiste e não manipula tokens OAuth, senhas ou ficheiros de autenticação.
- **Comunicação Segura**: Toda a recolha de dados é delegada diretamente aos binários oficiais instalados na máquina do utilizador.
- **Sem Telemetria**: Sem analytics, rastreamento ou chamadas de rede não autorizadas.

---

## Resolução de Problemas (Troubleshooting)

- **"Codex CLI não encontrado"**:
  Verifica se o `codex` está instalado (ex: `/opt/homebrew/bin/codex`). Podes definir um caminho customizado em **Definições → Executáveis**.
- **"Antigravity CLI não encontrado"**:
  Verifica se o `agy` está no teu PATH (ex: `~/.local/bin/agy`). Podes configurar o caminho em **Definições → Executáveis**.
- **"Perfil Codex não autenticado"**:
  Abre o terminal e corre `CODEX_HOME="/caminho/do/perfil" codex login` para autenticar o perfil em questão.
- **"Inicia sessão no Antigravity CLI"**:
  Corre `agy` no teu terminal para iniciar sessão.

---

## Limitações Conhecidas

- **Antigravity Multi-Conta**: A versão atual monitoriza apenas a conta atualmente ativa no CLI `agy`.
- **Read-Only**: A SeeUsage é puramente um monitor de utilização e não efetua troca de credenciais nem login/logout automático.
