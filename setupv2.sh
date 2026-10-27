
#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================================
# Setup Linux Mint - Gabriel Carlos
# Instala aplicativos e configura o ambiente de desenvolvimento
# Pode ser executado novamente sem reinstalar tudo.
# ==========================================================

GIT_NAME="Gabriel Carlos"
GIT_EMAIL="gabrielcarlossleite@gmail.com"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33mAVISO: %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mERRO: %s\033[0m\n' "$*" >&2; exit 1; }

trap 'status=$?; printf "\nERRO na linha %s\nComando: %s\nCódigo: %s\n" "$LINENO" "$BASH_COMMAND" "$status" >&2' ERR

command -v apt >/dev/null 2>&1 ||
  fail "Este script requer Linux Mint ou uma distribuição baseada em APT."

[[ $EUID -ne 0 ]] ||
  fail "Execute como seu usuário normal, sem sudo."

# Solicita a senha uma única vez.
sudo -v

# Mantém a autenticação sudo ativa durante a execução.
(while sleep 60; do sudo -n true 2>/dev/null || exit; done) &
KEEPALIVE_PID=$!
trap 'kill "$KEEPALIVE_PID" 2>/dev/null || true' EXIT

# ----------------------------------------------------------
# Funções de verificação e instalação
# ----------------------------------------------------------

apt_instalado() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null |
    grep -q '^install ok installed$'
}

instalar_pacotes() {
  local faltantes=()
  local pacote

  for pacote in "$@"; do
    if apt_instalado "$pacote"; then
      printf 'Já instalado: %s\n' "$pacote"
    else
      faltantes+=("$pacote")
    fi
  done

  if ((${#faltantes[@]})); then
    log "Instalando pacotes ausentes: ${faltantes[*]}"
    sudo apt install -y "${faltantes[@]}"
  else
    log "Todos os pacotes solicitados já estão instalados."
  fi
}

adicionar_repositorio() {
  local arquivo="$1"
  local conteudo="$2"

  if [[ -f "$arquivo" ]] && grep -Fq "$conteudo" "$arquivo"; then
    printf 'Repositório já configurado: %s\n' "$arquivo"
  else
    printf '%s\n' "$conteudo" |
      sudo tee "$arquivo" >/dev/null
  fi
}

# ----------------------------------------------------------
# Atualização do sistema
# ----------------------------------------------------------

log "Atualizando os repositórios"
sudo apt update

log "Atualizando os pacotes instalados"
sudo apt upgrade -y

# ----------------------------------------------------------
# Dependências básicas
# ----------------------------------------------------------

log "Verificando dependências"

instalar_pacotes \
  zsh git curl wget ca-certificates gnupg \
  gedit fonts-dejavu-core unzip xz-utils \
  build-essential apt-transport-https \
  software-properties-common openssh-client

command -v zsh >/dev/null 2>&1 ||
  fail "Zsh não está disponível após a instalação."

# ----------------------------------------------------------
# Git: preservar configurações existentes
# ----------------------------------------------------------

log "Configurando Git"

if [[ -z "$(git config --global user.name || true)" ]]; then
  git config --global user.name "$GIT_NAME"
else
  log "Nome do Git já configurado; mantendo o valor existente."
fi

if [[ -z "$(git config --global user.email || true)" ]]; then
  git config --global user.email "$GIT_EMAIL"
else
  log "E-mail do Git já configurado; mantendo o valor existente."
fi

if [[ -z "$(git config --global init.defaultBranch || true)" ]]; then
  git config --global init.defaultBranch main
fi

# ----------------------------------------------------------
# Repositório oficial do VS Code
# ----------------------------------------------------------

log "Verificando repositório do VS Code"

if [[ ! -f /etc/apt/keyrings/microsoft.gpg ]]; then
  sudo install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
  sudo chmod a+r /etc/apt/keyrings/microsoft.gpg
fi

adicionar_repositorio \
  /etc/apt/sources.list.d/vscode.list \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main"

# ----------------------------------------------------------
# Repositório oficial do Brave
# ----------------------------------------------------------

log "Verificando repositório do Brave"

sudo install -d -m 0755 /usr/share/keyrings

if [[ ! -f /usr/share/keyrings/brave-browser-archive-keyring.gpg ]]; then
  curl -fsSL \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg |
    sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg >/dev/null
fi

sudo chmod a+r /usr/share/keyrings/brave-browser-archive-keyring.gpg

adicionar_repositorio \
  /etc/apt/sources.list.d/brave-browser-release.list \
  "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://brave-browser-apt-release.s3.brave.com/ stable main"

# ----------------------------------------------------------
# Google Chrome
# ----------------------------------------------------------

log "Verificando Google Chrome"

if command -v google-chrome-stable >/dev/null 2>&1; then
  log "Google Chrome já está instalado."
else
  if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    warn "O instalador direto do Chrome requer arquitetura amd64."
  else
    TMP_DEB="$(mktemp --suffix=.deb)"
    if curl -fL --retry 3 \
      https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
      -o "$TMP_DEB"; then
      sudo apt install -y "$TMP_DEB"
    else
      warn "Não foi possível baixar o Google Chrome."
    fi
    rm -f "$TMP_DEB"
  fi
fi

# ----------------------------------------------------------
# VS Code, Brave e Steam
# ----------------------------------------------------------

log "Atualizando repositórios após configurar os navegadores"
sudo apt update

instalar_pacotes code brave-browser

log "Verificando Steam"

if command -v steam >/dev/null 2>&1 || apt_instalado steam-installer; then
  log "Steam já está instalado."
else
  if ! sudo apt install -y steam-installer; then
    warn "Steam não foi instalado. Verifique o Gerenciador de Aplicativos."
  fi
fi

# ----------------------------------------------------------
# NVM e Node.js
# ----------------------------------------------------------

log "Verificando NVM"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  curl -fsSL \
    https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh |
    bash
else
  log "NVM já está instalado."
fi

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"

  if ! nvm ls --no-colors | grep -q 'lts/'; then
    log "Instalando Node.js LTS"
    nvm install --lts
  else
    log "Já existe uma versão LTS do Node.js instalada."
  fi

  nvm alias default 'lts/*'
  nvm use default
else
  fail "Não foi possível carregar o NVM."
fi

# ----------------------------------------------------------
# Oh My Zsh
# ----------------------------------------------------------

log "Verificando Oh My Zsh"

# Verificação explícita para evitar o erro
# "Zsh is not installed. Please install zsh first."
if ! command -v zsh >/dev/null 2>&1; then
  sudo apt install -y zsh
fi

command -v zsh >/dev/null 2>&1 ||
  fail "Zsh não foi instalado corretamente."

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL \
      https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  log "Oh My Zsh já está instalado."
fi

# Adiciona o carregamento do NVM sem duplicar o bloco.
touch "$HOME/.zshrc"

if ! grep -q '# NVM - setup Linux Mint' "$HOME/.zshrc"; then
  cat >> "$HOME/.zshrc" <<'ZSH'

# NVM - setup Linux Mint
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
ZSH
else
  log "Configuração do NVM no .zshrc já existe."
fi


# =========================================================
# OPENCODE
# =========================================================

echo ""
echo "Configurando OpenCode..."

OPENCODE_BIN="$HOME/.opencode/bin/opencode"
OPENCODE_PATH_LINE='export PATH="$HOME/.opencode/bin:$PATH"'

# Instala somente se o executável não existir
if [[ ! -x "$OPENCODE_BIN" ]]; then
    echo "Instalando OpenCode..."

    if ! curl -fsSL https://opencode.ai/install | bash; then
        echo "AVISO: Não foi possível instalar o OpenCode."
    fi
fi

# Confere novamente após a instalação
if [[ -x "$OPENCODE_BIN" ]]; then
    echo "OpenCode instalado corretamente."

    # Adiciona o diretório ao PATH do Zsh, sem duplicar a configuração
    touch "$HOME/.zshrc"

    if ! grep -Fqx "$OPENCODE_PATH_LINE" "$HOME/.zshrc"; then
        printf '\n%s\n' "$OPENCODE_PATH_LINE" >> "$HOME/.zshrc"
        echo "PATH do OpenCode configurado no .zshrc."
    else
        echo "PATH do OpenCode já configurado."
    fi

    # Disponibiliza o comando imediatamente nesta execução do script
    export PATH="$HOME/.opencode/bin:$PATH"

    # Verifica se o executável funciona
    if "$OPENCODE_BIN" --version; then
        echo "OpenCode pronto para uso."
    else
        echo "AVISO: OpenCode existe, mas falhou ao executar."
    fi
else
    echo "AVISO: Executável do OpenCode não encontrado."
    echo "Verifique a instalação antes de utilizá-lo."
fi


# ----------------------------------------------------------
# Context7
# ----------------------------------------------------------

log "Verificando configuração do Context7"

if command -v npx >/dev/null 2>&1; then
  # O comando setup pode atualizar a configuração existente.
  # Se falhar, o restante do script continuará.
  if npx -y ctx7 setup --opencode --yes; then
    log "Configuração do Context7 concluída."
  else
    warn "Não foi possível concluir o Context7 automaticamente."
  fi
else
  warn "NPM indisponível. Configure o Context7 depois de abrir um terminal."
fi

# ----------------------------------------------------------
# SSH para GitHub/GitLab
# ----------------------------------------------------------

log "Configurando SSH para Git"

SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -f "$SSH_KEY" && -f "$SSH_KEY.pub" ]]; then
  log "Chave SSH existente encontrada; nenhuma chave será sobrescrita."
elif [[ -e "$SSH_KEY" || -e "$SSH_KEY.pub" ]]; then
  fail "Existe um arquivo parcial da chave SSH. Verifique $SSH_DIR."
else
  log "Gerando chave SSH Ed25519"
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY"
fi

chmod 600 "$SSH_KEY"
chmod 644 "$SSH_KEY.pub"

printf '\nChave pública SSH:\n\n'
cat "$SSH_KEY.pub"
printf '\n'
warn "Nunca compartilhe a chave privada: $SSH_KEY"

# ----------------------------------------------------------
# Shell padrão
# ----------------------------------------------------------

log "Configurando Zsh como shell padrão"

ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"

if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
  if grep -Fxq "$ZSH_PATH" /etc/shells; then
    chsh -s "$ZSH_PATH"
    log "Shell padrão alterado para Zsh."
  else
    warn "$ZSH_PATH não está listado em /etc/shells; não alterei o shell."
  fi
else
  log "Zsh já é o shell padrão."
fi

# ----------------------------------------------------------
# Resumo e conclusão: sempre no final
# ----------------------------------------------------------

log "Verificando instalações finais"

printf '\nGit: '
git config --global user.name
printf 'E-mail: '
git config --global user.email
printf 'Zsh: %s\n' "$ZSH_PATH"

command -v node >/dev/null 2>&1 &&
  printf 'Node.js: %s\n' "$(node --version)" ||
  warn "Node.js não está disponível neste terminal."

command -v npm >/dev/null 2>&1 &&
  printf 'NPM: %s\n' "$(npm --version)" ||
  warn "NPM não está disponível neste terminal."

command -v code >/dev/null 2>&1 &&
  printf 'VS Code: instalado\n' ||
  warn "VS Code não foi encontrado."

command -v brave-browser >/dev/null 2>&1 &&
  printf 'Brave: instalado\n' ||
  warn "Brave não foi encontrado."

command -v google-chrome-stable >/dev/null 2>&1 &&
  printf 'Google Chrome: instalado\n' ||
  warn "Google Chrome não foi encontrado."

printf '\n'
printf '%s\n' \
  "==========================================================" \
  "       CONFIGURAÇÃO DO LINUX MINT CONCLUÍDA!" \
  "==========================================================" \
  "" \
  "As etapas obrigatórias terminaram sem erros fatais." \
  "Aplicativos opcionais podem ter sido ignorados se houve avisos." \
  "" \
  "Próximas etapas:" \
  "1. Saia da sessão e entre novamente para ativar o Zsh." \
  "2. Configure a fonte DejaVu Sans Mono nas preferências do terminal." \
  "3. Adicione a chave pública SSH ao GitHub/GitLab, se necessário." \
  "4. Abra o OpenCode e conclua a autenticação, se solicitada." \
  "" \
  "Obrigado! Seu ambiente de desenvolvimento está pronto." \
  "=========================================================="

