# setupv2.sh

Script de provisionamento para Linux Mint (ou qualquer Debian/Ubuntu baseado em APT) que instala aplicativos e configura o ambiente de desenvolvimento de forma automatizada e **idempotente** — pode ser executado quantas vezes for necessário sem reinstalar nada que já esteja presente.

## Requisitos

- Distribuição baseada em APT (Linux Mint, Ubuntu, Debian)
- Executar como usuário **normal**, sem `sudo` (o script pede a senha uma única vez)
- Conexão com a internet

## Uso

```bash
chmod +x setupv2.sh
./setupv2.sh
```

> O script mantém a autenticação `sudo` ativa durante toda a execução (keep-alive em background), então você só digita a senha uma vez.

## O que ele faz

### 1. Pré-checagens
- Verifica se `apt` está disponível
- Recusa execução como root
- Solicita `sudo` uma única vez e o mantém vivo com um loop de 60s

### 2. Atualização do sistema
- `apt update` e `apt upgrade -y`

### 3. Dependências básicas
Instala (apenas as que faltarem):

```
zsh git curl wget ca-certificates gnupg gedit fonts-dejavu-core
unzip xz-utils build-essential apt-transport-https
software-properties-common openssh-client
```

### 4. Git
- Define `user.name`, `user.email` e `init.defaultBranch=main` **somente** se ainda não estiverem configurados (preserva valores existentes)

### 5. Repositórios de terceiros
| Aplicativo | Método |
|---|---|
| **VS Code** | Repo oficial da Microsoft (`/etc/apt/keyrings/microsoft.gpg` + `vscode.list`) |
| **Brave** | Repo oficial (`/usr/share/keyrings/brave-browser-archive-keyring.gpg`) |
| **Google Chrome** | Download direto do `.deb` (apenas `amd64`) |

As chaves e entradas de repositório só são criadas se ainda não existirem.

### 6. Aplicativos
- `code` e `brave-browser` via APT
- `steam-installer` (falha não interrompe o script)
- Google Chrome instalado via `.deb` se não estiver presente

### 7. NVM + Node.js
- Instala o NVM `v0.40.3` se `~/.nvm/nvm.sh` não existir
- Instala a versão **LTS** do Node.js caso nenhuma LTS esteja presente
- Define `lts/*` como alias padrão

### 8. Oh My Zsh
- Verifica `zsh` antes de rodar o instalador (evita erro clássico)
- Instala com `RUNZSH=no CHSH=no KEEP_ZSHRC=yes` (não troca o shell nem sobrescreve o `.zshrc`)
- Adiciona o bloco de carregamento do NVM ao `~/.zshrc` apenas se o marcador `# NVM - setup Linux Mint` não existir

### 9. OpenCode
- Instala via `curl -fsSL https://opencode.ai/install | bash` se `~/.opencode/bin/opencode` não existir
- Adiciona `~/.opencode/bin` ao `PATH` no `~/.zshrc` (sem duplicar)
- Verifica a versão instalada na hora

### 10. Context7
- Roda `npx -y ctx7 setup --opencode --yes` para configurar o MCP do Context7
- Falha aqui é apenas um aviso, não interrompe o script

### 11. SSH (GitHub/GitLab)
- Cria `~/.ssh` com permissões `700`/`600`/`644`
- Gera chave **Ed25519** associada ao e-mail do Git **apenas** se não existir
- Se existir apenas um dos arquivos (privada/pub), aborta com erro
- Exibe a chave pública na tela para você colar no GitHub/GitLab
- **Nunca sobrescreve uma chave existente**

### 12. Shell padrão
- Torna o Zsh o shell padrão com `chsh`, se ainda não for
- Só altera se o caminho do `zsh` estiver listado em `/etc/shells`

### 13. Resumo final
- Imprime Git, Zsh, Node.js, NPM, VS Code, Brave e Chrome
- Lista as próximas etapas manuais (relogar, fonte do terminal, chave SSH no GitHub, autenticação do OpenCode)

## Comportamento seguro

- `set -Eeuo pipefail` + `trap ERR` → mostra linha, comando e código de erro
- Funções auxiliares: `log`, `warn`, `fail`
- **Idempotência**: pacotes, repositórios, chaves SSH, blocos de config e diretórios são verificados antes de serem criados
- Falhas em pacotes opcionais (Steam, Brave, Chrome, Context7, OpenCode) geram apenas `AVISO` e o script continua

## Estrutura de saída

```
==> Atualizando os repositórios
Já instalado: git
==> Instalando pacotes ausentes: ...
...
==========================================================
       CONFIGURAÇÃO DO LINUX MINT CONCLUÍDA!
==========================================================
```

## Personalização

Edite as variáveis no topo do script:

```bash
GIT_NAME="Gabriel Carlos"
GIT_EMAIL="gabrielcarlossleite@gmail.com"
```
