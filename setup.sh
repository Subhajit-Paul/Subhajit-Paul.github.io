#!/usr/bin/env bash
# =============================================================================
#  setup.sh - Subhajit Paul's Linux Setup Script
#  Usage: curl -LsSf https://subhajit-paul.github.io/setup.sh | bash
#
#  Supports: Debian (based) · Arch (Based) · Fedora/RHEL
# =============================================================================

if [ -z "${BASH_VERSION:-}" ]; then
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  else
    echo "[setup] bash not found. Installing bash first..."
    if   command -v apt-get >/dev/null 2>&1; then apt-get update -qq && apt-get install -y bash
    elif command -v dnf     >/dev/null 2>&1; then dnf install -y bash
    elif command -v pacman  >/dev/null 2>&1; then pacman -Sy --noconfirm bash
    else
      echo "[setup] ERROR: Cannot install bash automatically. Please install bash and re-run." >&2
      exit 1
    fi
    exec bash "$0" "$@"
  fi
fi

set -euo pipefail

# Environment Sanitization
# Minimal containers (Docker, CI) often leave USER, HOME, SHELL unset.
# Derive safe fallbacks before any other code runs.

# USER: try id, fall back to whoami, fall back to root
if [ -z "${USER:-}" ]; then
  USER=$(id -un 2>/dev/null || whoami 2>/dev/null || echo "root")
  export USER
fi

# HOME: try getent passwd, fall back to /root or /home/$USER
if [ -z "${HOME:-}" ] || [ ! -d "${HOME:-}" ]; then
  HOME=$(getent passwd "$USER" 2>/dev/null | cut -d: -f6) \
    || HOME=$(eval echo "~$USER" 2>/dev/null) \
    || HOME="/home/$USER"
  # If we're root, force /root
  [ "$USER" = "root" ] && HOME="/root"
  export HOME
fi

# SHELL: safe default - we're running under bash right now
SHELL="${SHELL:-$(command -v bash)}"
export SHELL

# Colors & Logging 
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[·]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}━━━  $*  ━━━${NC}"; }
skip()    { echo -e "${YELLOW}[:]${NC} $* already installed, skipping."; }

command_exists() { command -v "$1" &>/dev/null; }

print_banner() {

local tw
tw=$(tput cols 2>/dev/null || echo 80)

center() {
local text="$1"
local visible
visible=$(echo -e "$text" | sed 's/\x1b[[0-9;]*m//g')
local len=${#visible}
local pad=$(( (tw - len) / 2 ))
[ $pad -lt 0 ] && pad=0
printf "%${pad}s%b\n" "" "$text"
}

local logo=(
"\e[38;5;49m ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ ${NC}"
"\e[38;5;43m ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗${NC}"
"\e[38;5;37m ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝     ███████╗█████╗     ██║   ██║   ██║██████╔╝${NC}"
"\e[38;5;31m ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗     ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ ${NC}"
"\e[38;5;25m ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗    ███████║███████╗   ██║   ╚██████╔╝██║     ${NC}"
"\e[38;5;19m ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     ${NC}"
)

echo
echo -e "${BOLD}${CYAN}"

center "─────────────────────────────────────────────────────────────────────────────────────────"
echo

for line in "${logo[@]}"; do
center "$line"
done

echo
center "${BOLD}Subhajit Paul's Linux Setup Script${NC}${CYAN}"

echo
center "github.com/Subhajit-Paul"
center "subhajit-paul.github.io"

echo
center "─────────────────────────────────────────────────────────────────────────────────────────"

echo -e "${NC}"
echo
}

print_banner


# Interactive Multi-Select Menu 
# Sets SELECTED=() with 0-based indices of chosen options.
# Reads from /dev/tty directly so it works even when stdin is a curl pipe.
SELECTED=()
prompt_choices() {
  local title="$1"; shift
  local options=("$@")
  SELECTED=()

  echo ""
  echo -e "${BOLD}${CYAN}  ┌─ ${title} ─┐${NC}"
  for i in "${!options[@]}"; do
    printf "  ${YELLOW}[%2d]${NC} %s\n" "$((i+1))" "${options[$i]}"
  done
  echo ""
  echo -e "  ${BLUE}Enter numbers separated by spaces, ${BOLD}a${NC}${BLUE} = all, Enter = skip:${NC}"
  printf "  ${BOLD}> ${NC}"

  # Always read from /dev/tty - works whether piped (curl|bash) or run directly
  if [ ! -e /dev/tty ]; then
    echo ""
    warn "/dev/tty not available. Skipping optional selections."
    warn "Re-run directly with: bash setup.sh"
    return
  fi

  local input
  read -r input < /dev/tty

  if [[ "${input,,}" == "a" ]]; then
    for i in "${!options[@]}"; do SELECTED+=("$i"); done
  elif [[ -n "$input" ]]; then
    for s in $input; do
      if [[ "$s" =~ ^[0-9]+$ ]] && [ "$s" -ge 1 ] && [ "$s" -le "${#options[@]}" ]; then
        SELECTED+=("$((s-1))")
      fi
    done
  fi
}

is_selected() {
  local idx="$1"
  for s in "${SELECTED[@]:-}"; do [[ "$s" == "$idx" ]] && return 0; done
  return 1
}

# OS Detection 
header "Detecting Operating System"

detect_os() {
  [ -f /etc/os-release ] || error "/etc/os-release not found. Cannot detect OS."
  # shellcheck source=/dev/null
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_ID_LIKE="${ID_LIKE:-}"

  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop|kali|elementary) PKG_MANAGER="apt" ;;
    arch|manjaro|endeavouros|garuda|artix)        PKG_MANAGER="pacman" ;;
    fedora|rhel|centos|rocky|almalinux|nobara)    PKG_MANAGER="dnf" ;;
    *)
      if   echo "$OS_ID_LIKE" | grep -qE "debian|ubuntu"; then PKG_MANAGER="apt"
      elif echo "$OS_ID_LIKE" | grep -q  "arch";           then PKG_MANAGER="pacman"
      elif echo "$OS_ID_LIKE" | grep -qE "fedora|rhel";   then PKG_MANAGER="dnf"
      else error "Unsupported OS: '$OS_ID'"
      fi ;;
  esac
  success "OS: ${BOLD}${OS_ID}${NC}  :  package manager: ${BOLD}${PKG_MANAGER}${NC}"
}

detect_os

# Upfront Optional Selections
header "Optional Tool Selection"

OPTIONAL_TOOLS=("LazyGit" "ffmpeg" "git-lfs" "ripgrep-all (rga)" "fastfetch" "bandwhich (network monitor)")
prompt_choices "Extra CLI Tools" "${OPTIONAL_TOOLS[@]}"
OPT_TOOLS_SEL=("${SELECTED[@]:-}")

OPTIONAL_APPS=("Brave Browser" "Docker Engine (CE)" "Steam" "LibreOffice Suite" "VLC")
prompt_choices "Extra Applications" "${OPTIONAL_APPS[@]}"
OPT_APPS_SEL=("${SELECTED[@]:-}")

# Package Manager Helpers
pkg_update() {
  info "Updating package index..."
  case "$PKG_MANAGER" in
    apt)    sudo apt-get update -qq ;;
    pacman) sudo pacman -Sy --noconfirm ;;
    dnf)    sudo dnf check-update -q || true ;;
  esac
}

pkg_install() {
  case "$PKG_MANAGER" in
    apt)    sudo apt-get install -y --no-install-recommends "$@" ;;
    pacman) sudo pacman -S --noconfirm --needed "$@" ;;
    dnf)    sudo dnf install -y "$@" ;;
  esac
}

aur_install() {
  if   command_exists yay;  then yay  -S --noconfirm --needed "$@"
  elif command_exists paru; then paru -S --noconfirm --needed "$@"
  else warn "No AUR helper found (yay/paru). Cannot install: $*"; fi
}

enable_rpmfusion() {
  if ! dnf repolist | grep -q rpmfusion; then
    info "Enabling RPM Fusion..."
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
      2>/dev/null || true
  fi
}

# Base Dependencies
header "Installing Base Dependencies"

pkg_update

case "$PKG_MANAGER" in
  apt)
    pkg_install \
      curl wget git unzip zip tar xz-utils ca-certificates gnupg \
      build-essential cmake make clang gcc g++ \
      libssl-dev libffi-dev zlib1g-dev libbz2-dev libreadline-dev \
      libsqlite3-dev libxml2-dev libxmlsec1-dev \
      liblzma-dev tk-dev llvm net-tools lsof apt-transport-https \
      stow fontconfig
    # PipeWire audio (best-effort; may already be installed)
    pkg_install pipewire-audio pulseaudio-utils 2>/dev/null || true
    ;;
  pacman)
    pkg_install \
      curl wget git unzip zip tar xz ca-certificates gnupg \
      base-devel cmake make clang gcc \
      openssl zlib bzip2 readline sqlite ncurses libxml2 \
      net-tools lsof stow fontconfig \
      pipewire pipewire-pulse wireplumber
    ;;
  dnf)
    pkg_install \
      curl wget git unzip zip tar xz ca-certificates gnupg2 \
      gcc gcc-c++ cmake make clang \
      openssl-devel libffi-devel zlib-devel bzip2-devel readline-devel \
      sqlite-devel ncurses-devel libxml2-devel xz-devel tk-devel llvm \
      net-tools lsof stow fontconfig \
      pipewire pipewire-pulseaudio
    ;;
esac

success "Base dependencies installed."

# Zsh
header "Setting Up Zsh"

if ! command_exists zsh; then
  pkg_install zsh && success "Zsh installed."
else
  skip "zsh"
fi

ZSH_BIN="$(command -v zsh)"
if [ "${SHELL}" != "${ZSH_BIN}" ]; then
  if [ "${USER}" = "root" ]; then
    # Root: just write directly to /etc/passwd via usermod, no password needed
    if command_exists usermod; then
      usermod -s "${ZSH_BIN}" root \
        && success "Default shell : Zsh." \
        || warn "usermod failed - run manually: sudo usermod -s ${ZSH_BIN} root"
    else
      warn "usermod not found - run manually: chsh -s ${ZSH_BIN}"
    fi
  elif command_exists usermod; then
    # usermod requires no password prompt, just sudo (already active)
    sudo usermod -s "${ZSH_BIN}" "${USER}" \
      && success "Default shell : Zsh (re-login required)." \
      || warn "usermod failed - run manually: sudo usermod -s ${ZSH_BIN} ${USER}"
  elif command_exists chsh; then
    # Fallback: sudo chsh avoids the interactive password prompt
    sudo chsh -s "${ZSH_BIN}" "${USER}" \
      && success "Default shell : Zsh (re-login required)." \
      || warn "chsh failed - run manually: sudo chsh -s ${ZSH_BIN} ${USER}"
  else
    warn "Neither usermod nor chsh found - run manually: sudo usermod -s ${ZSH_BIN} ${USER}"
  fi
else
  skip "Zsh default shell"
fi

# Oh My Zsh
header "Installing Oh My Zsh"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed."
else
  skip "Oh My Zsh"
fi

OMZ_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Powerlevel10k
header "Installing Powerlevel10k"

P10K_DIR="${OMZ_CUSTOM}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  success "Powerlevel10k installed."
else
  skip "Powerlevel10k"
fi

# OMZ Plugins
header "Installing Oh My Zsh Plugins"

install_omz_plugin() {
  local name="$1" repo="$2"
  local dir="${OMZ_CUSTOM}/plugins/${name}"
  if [ ! -d "$dir" ]; then
    info "Plugin: ${name}..."
    git clone --depth=1 "$repo" "$dir"
    success "Plugin '${name}' installed."
  else
    skip "Plugin '${name}'"
  fi
}

install_omz_plugin "zsh-autosuggestions"    "https://github.com/zsh-users/zsh-autosuggestions"
install_omz_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"
install_omz_plugin "zsh-completions"        "https://github.com/zsh-users/zsh-completions"
install_omz_plugin "you-should-use"         "https://github.com/MichaelAquilina/zsh-you-should-use"

# Nerd Fonts
header "Installing Nerd Fonts"

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

install_font() {
  local name="$1" url="$2"
  if [ ! -f "${FONT_DIR}/${name}" ]; then
    info "Downloading: ${name}..."
    curl -fsSL "$url" -o "${FONT_DIR}/${name}"
    success "Font: ${name}"
  else
    skip "Font '${name}'"
  fi
}

# MesloLGS NF - required for Powerlevel10k glyphs
P10K_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
install_font "MesloLGS NF Regular.ttf"     "${P10K_BASE}/MesloLGS%20NF%20Regular.ttf"
install_font "MesloLGS NF Bold.ttf"        "${P10K_BASE}/MesloLGS%20NF%20Bold.ttf"
install_font "MesloLGS NF Italic.ttf"      "${P10K_BASE}/MesloLGS%20NF%20Italic.ttf"
install_font "MesloLGS NF Bold Italic.ttf" "${P10K_BASE}/MesloLGS%20NF%20Bold%20Italic.ttf"

# JetBrainsMono Nerd Font - primary coding font
info "Installing JetBrainsMono Nerd Font..."
if ! find "$FONT_DIR" -name "JetBrainsMonoNerdFont*" 2>/dev/null | grep -q .; then
  JB_VER=$(curl -s "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" \
    | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  JB_ZIP="/tmp/JetBrainsMono.zip"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${JB_VER}/JetBrainsMono.zip" \
    -o "$JB_ZIP"
  mkdir -p "$FONT_DIR/JetBrainsMono"
  unzip -oq "$JB_ZIP" -d "$FONT_DIR/JetBrainsMono" -x '*Windows*' 2>/dev/null \
    || unzip -oq "$JB_ZIP" -d "$FONT_DIR/JetBrainsMono" 2>/dev/null
  rm -f "$JB_ZIP"
  success "JetBrainsMono Nerd Font installed."
else
  skip "JetBrainsMono Nerd Font"
fi

fc-cache -fq && success "Font cache refreshed."

# CLI Essentials
header "Installing CLI Essentials"

# fzf
if ! command_exists fzf; then
  info "Installing fzf..."
  git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-bash --no-fish
  success "fzf installed."
else
  skip "fzf"
fi

# ripgrep
if ! command_exists rg; then
  pkg_install ripgrep && success "ripgrep installed."
else
  skip "ripgrep"
fi

# bat
if ! command_exists bat && ! command_exists batcat; then
  pkg_install bat && success "bat installed."
else
  skip "bat"
fi

# bat : batcat symlink on Debian/Ubuntu
if command_exists batcat && ! command_exists bat; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  success "Symlink: bat : batcat"
fi

# tmux
if ! command_exists tmux; then
  pkg_install tmux && success "tmux installed."
else
  skip "tmux"
fi

# btop
if ! command_exists btop; then
  pkg_install btop && success "btop installed."
else
  skip "btop"
fi

# htop
if ! command_exists htop; then
  pkg_install htop && success "htop installed."
else
  skip "htop"
fi

# zoxide
if ! command_exists zoxide; then
  info "Installing zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  success "zoxide installed."
else
  skip "zoxide"
fi

# Optional CLI Tools
header "Installing Selected Optional Tools"

SELECTED=("${OPT_TOOLS_SEL[@]:-}")

# [0] LazyGit
if is_selected 0; then
  if ! command_exists lazygit; then
    info "Installing LazyGit..."
    case "$PKG_MANAGER" in
      pacman) pkg_install lazygit ;;
      apt|dnf)
        LG_VER=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
          | grep '"tag_name"' | sed -E 's/.*"v*([^"]+)".*/\1/')
        curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LG_VER}/lazygit_${LG_VER}_Linux_x86_64.tar.gz" \
          | tar -xz -C /tmp lazygit
        sudo install /tmp/lazygit /usr/local/bin
        ;;
    esac
    success "LazyGit installed."
  else
    skip "LazyGit"
  fi
fi

# [1] ffmpeg
if is_selected 1; then
  if ! command_exists ffmpeg; then
    info "Installing ffmpeg..."
    case "$PKG_MANAGER" in
      apt)    pkg_install ffmpeg ;;
      pacman) pkg_install ffmpeg ;;
      dnf)    enable_rpmfusion; pkg_install ffmpeg ;;
    esac
    success "ffmpeg installed."
  else
    skip "ffmpeg"
  fi
fi

# [2] git-lfs
if is_selected 2; then
  if ! command_exists git-lfs; then
    info "Installing git-lfs..."
    case "$PKG_MANAGER" in
      apt)
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
        pkg_install git-lfs
        ;;
      pacman) pkg_install git-lfs ;;
      dnf)
        curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | sudo bash
        pkg_install git-lfs
        ;;
    esac
    git lfs install --system 2>/dev/null || git lfs install
    success "git-lfs installed."
  else
    skip "git-lfs"
  fi
fi

# [3] ripgrep-all (rga)
if is_selected 3; then
  if ! command_exists rga; then
    info "Installing ripgrep-all (rga)..."
    case "$PKG_MANAGER" in
      pacman) aur_install ripgrep-all ;;
      apt|dnf)
        RGA_VER=$(curl -s "https://api.github.com/repos/phiresky/ripgrep-all/releases/latest" \
          | grep '"tag_name"' | sed -E 's/.*"v*([^"]+)".*/\1/')
        RGA_TARBALL="ripgrep_all-v${RGA_VER}-x86_64-unknown-linux-musl"
        curl -fsSL "https://github.com/phiresky/ripgrep-all/releases/download/v${RGA_VER}/${RGA_TARBALL}.tar.gz" \
          | tar -xz -C /tmp
        sudo install "/tmp/${RGA_TARBALL}/rga" "/tmp/${RGA_TARBALL}/rga-preproc" /usr/local/bin/
        ;;
    esac
    success "ripgrep-all (rga) installed."
  else
    skip "rga"
  fi
fi

# [4] fastfetch
if is_selected 4; then
  if ! command_exists fastfetch; then
    info "Installing fastfetch..."
    case "$PKG_MANAGER" in
      apt)
        FF_VER=$(curl -s "https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest" \
          | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
        curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/download/${FF_VER}/fastfetch-linux-amd64.deb" \
          -o /tmp/fastfetch.deb
        sudo dpkg -i /tmp/fastfetch.deb && rm /tmp/fastfetch.deb
        ;;
      pacman) pkg_install fastfetch ;;
      dnf)    pkg_install fastfetch ;;
    esac
    success "fastfetch installed."
  else
    skip "fastfetch"
  fi
fi

# [5] bandwhich
if is_selected 5; then
  if ! command_exists bandwhich; then
    info "Installing bandwhich (network monitor)..."
    case "$PKG_MANAGER" in
      apt|dnf)
        # Build from source via cargo (most reliable cross-distro)
        if command_exists cargo; then
          cargo install bandwhich
        else
          warn "cargo not found yet. Source ~/.cargo/env and run: cargo install bandwhich"
        fi
        ;;
      pacman) pkg_install bandwhich ;;
    esac
    success "bandwhich installed. Usage: sudo bandwhich"
  else
    skip "bandwhich"
  fi
fi

# Neovim + NVChad
header "Installing Neovim + NVChad"

if ! command_exists nvim; then
  info "Installing Neovim (latest stable binary)..."
  case "$PKG_MANAGER" in
    apt)
      curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
        | sudo tar -xz -C /opt
      sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
      ;;
    pacman) pkg_install neovim ;;
    dnf)    pkg_install neovim ;;
  esac
  success "Neovim installed."
else
  skip "Neovim"
fi

NVIM_CONFIG="$HOME/.config/nvim"
if [ ! -d "$NVIM_CONFIG" ] || [ -z "$(ls -A "$NVIM_CONFIG" 2>/dev/null)" ]; then
  info "Setting up NVChad starter..."
  rm -rf "$NVIM_CONFIG"
  git clone https://github.com/NvChad/starter "$NVIM_CONFIG"
  success "NVChad config at ~/.config/nvim - run 'nvim' once to auto-install plugins."
else
  skip "NVChad (nvim config already exists)"
fi

# VS Code
header "Installing VS Code"

if ! command_exists code; then
  info "Installing VS Code..."
  case "$PKG_MANAGER" in
    apt)
      curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor \
        | sudo tee /usr/share/keyrings/microsoft-archive-keyring.gpg >/dev/null
      echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] \
        https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list
      sudo apt-get update -qq && pkg_install code
      ;;
    pacman) aur_install visual-studio-code-bin ;;
    dnf)
      sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
      sudo tee /etc/yum.repos.d/vscode.repo <<'REPO'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
      pkg_install code
      ;;
  esac
  success "VS Code installed."
else
  skip "VS Code"
fi

# Language Runtimes

# uv (Python)
header "Installing uv (Python toolchain)"
if ! command_exists uv; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  success "uv installed."
else
  skip "uv"
fi

# nvm + Node.js LTS
header "Installing nvm + Node.js LTS"
if [ ! -d "$HOME/.nvm" ]; then
  info "Installing nvm..."
  NVM_VER=$(curl -s "https://api.github.com/repos/nvm-sh/nvm/releases/latest" \
    | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VER}/install.sh" | bash
  success "nvm ${NVM_VER} installed."
else
  skip "nvm"
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if command_exists nvm; then
  nvm ls lts/* &>/dev/null || {
    info "Installing Node.js LTS..."
    nvm install --lts && nvm alias default lts/*
    success "Node.js LTS installed & set as default."
  }
else
  warn "nvm not in current session - Node.js installs on next login."
fi

# Rust
header "Installing Rust (rustup)"
if ! command_exists rustup; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  success "Rust + cargo installed."
else
  skip "rustup"
fi
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Java (Temurin 21 LTS)
header "Installing Java 21 LTS (Temurin)"
if ! command_exists java; then
  info "Installing Temurin JDK 21..."
  case "$PKG_MANAGER" in
    apt)
      wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor \
        | sudo tee /usr/share/keyrings/adoptium-keyring.gpg >/dev/null
      echo "deb [signed-by=/usr/share/keyrings/adoptium-keyring.gpg] \
        https://packages.adoptium.net/artifactory/deb $(. /etc/os-release; echo "$VERSION_CODENAME") main" \
        | sudo tee /etc/apt/sources.list.d/adoptium.list
      sudo apt-get update -qq && pkg_install temurin-21-jdk
      ;;
    pacman)
      pkg_install jdk21-temurin 2>/dev/null || aur_install jdk21-temurin ;;
    dnf)
      sudo tee /etc/yum.repos.d/adoptium.repo <<'REPO'
[Adoptium]
name=Adoptium
baseurl=https://packages.adoptium.net/artifactory/rpm/fedora/$releasever/$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public
REPO
      pkg_install temurin-21-jdk
      ;;
  esac
  success "Temurin JDK 21 installed."
else
  skip "Java (already: $(java -version 2>&1 | head -1))"
fi

# C/C++ Toolchain
header "Verifying C/C++ Toolchain"
for tool in gcc g++ clang cmake make; do
  command_exists "$tool" \
    && success "$tool : $(command -v "$tool")" \
    || { warn "$tool missing - installing..."; pkg_install "$tool"; }
done

# Optional Apps 
header "Installing Selected Optional Apps"

SELECTED=("${OPT_APPS_SEL[@]:-}")

# [0] Brave Browser
if is_selected 0; then
  if ! command_exists brave-browser && ! command_exists brave; then
    info "Installing Brave Browser..."
    case "$PKG_MANAGER" in
      apt)
        sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
          https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] \
          https://brave-browser-apt-release.s3.brave.com/ stable main" \
          | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
        sudo apt-get update -qq && pkg_install brave-browser
        ;;
      pacman) aur_install brave-bin ;;
      dnf)
        sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
        sudo tee /etc/yum.repos.d/brave-browser.repo <<'REPO'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
REPO
        pkg_install brave-browser
        ;;
    esac
    success "Brave Browser installed."
  else
    skip "Brave Browser"
  fi
fi

# [1] Docker Engine
if is_selected 1; then
  if ! command_exists docker; then
    info "Installing Docker Engine (CE)..."
    case "$PKG_MANAGER" in
      apt)
        pkg_install ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
          | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
          | sudo tee /etc/apt/sources.list.d/docker.list
        sudo apt-get update -qq
        pkg_install docker-ce docker-ce-cli containerd.io \
          docker-buildx-plugin docker-compose-plugin
        ;;
      pacman)
        pkg_install docker docker-compose ;;
      dnf)
        sudo dnf config-manager --add-repo \
          https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || \
        sudo dnf config-manager addrepo \
          --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
        pkg_install docker-ce docker-ce-cli containerd.io \
          docker-buildx-plugin docker-compose-plugin
        ;;
    esac
    sudo systemctl enable docker
    sudo systemctl start docker
    success "Docker Engine installed & started."
    warn "Use 'dok' alias to add yourself to the docker group."
  else
    skip "Docker"
  fi
fi

# [2] Steam
if is_selected 2; then
  if ! command_exists steam; then
    info "Installing Steam..."
    case "$PKG_MANAGER" in
      apt) pkg_install steam ;;
      pacman)
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
          printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf
          sudo pacman -Sy
        fi
        pkg_install steam
        ;;
      dnf) enable_rpmfusion; pkg_install steam ;;
    esac
    success "Steam installed."
  else
    skip "Steam"
  fi
fi

# [3] LibreOffice Suite
if is_selected 3; then
  if ! command_exists libreoffice && ! command_exists soffice; then
    info "Installing LibreOffice Suite..."
    case "$PKG_MANAGER" in
      apt)    pkg_install libreoffice ;;
      pacman) pkg_install libreoffice-fresh ;;
      dnf)    pkg_install libreoffice ;;
    esac
    success "LibreOffice installed."
  else
    skip "LibreOffice"
  fi
fi

# [4] VLC
if is_selected 4; then
  if ! command_exists vlc; then
    info "Installing VLC..."
    case "$PKG_MANAGER" in
      apt)    pkg_install vlc ;;
      pacman) pkg_install vlc ;;
      dnf)    enable_rpmfusion; pkg_install vlc ;;
    esac
    success "VLC installed."
  else
    skip "VLC"
  fi
fi

# Dotfiles + Scripts + .zshrc
header "Writing Dotfiles & Configs"

DOTFILES="$HOME/dotfiles"
mkdir -p "$DOTFILES/zsh" "$DOTFILES/nvim/.config/nvim" \
         "$DOTFILES/tmux" "$DOTFILES/git" "$DOTFILES/scripts/bin"

# volfix - restart audio stack
cat > "$DOTFILES/scripts/bin/volfix" <<'VOLFIX'
#!/usr/bin/env bash
# volfix - restart audio daemon (PipeWire or PulseAudio)
if command -v pipewire &>/dev/null; then
  echo "Restarting PipeWire..."
  systemctl --user restart pipewire pipewire-pulse wireplumber
  echo "PipeWire restarted."
elif command -v pulseaudio &>/dev/null; then
  echo "Restarting PulseAudio..."
  pulseaudio -k 2>/dev/null; sleep 1; pulseaudio --start
  echo "PulseAudio restarted."
else
  echo "No audio daemon found." && exit 1
fi
VOLFIX
chmod +x "$DOTFILES/scripts/bin/volfix"
success "volfix script created."

# String Operation Binaries
info "Writing string operation utilities..."

# charcount - count characters in stdin or file
cat > "$DOTFILES/scripts/bin/charcount" <<'SCRIPT'
#!/usr/bin/env bash
# charcount - count characters (excluding or including newlines)
# Usage:  charcount [file]   |   echo "hello" | charcount
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
input=$([ -n "${1:-}" ] && cat "$1" || cat)
total=$(echo -n "$input" | wc -c)
no_spaces=$(echo -n "$input" | tr -d '[:space:]' | wc -c)
no_newlines=$(echo -n "$input" | tr -d '\n' | wc -c)
echo -e "${BOLD}${BLUE}Character Count${NC}"
printf "  Total (with spaces)   : %d\n" "$total"
printf "  Without spaces        : %d\n" "$no_spaces"
printf "  Without newlines      : %d\n" "$no_newlines"
SCRIPT

# wordcount - count words in stdin or file
cat > "$DOTFILES/scripts/bin/wordcount" <<'SCRIPT'
#!/usr/bin/env bash
# wordcount - count words, unique words, average word length
# Usage:  wordcount [file]   |   echo "hello world" | wordcount
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
input=$([ -n "${1:-}" ] && cat "$1" || cat)
total=$(echo "$input" | wc -w)
unique=$(echo "$input" | tr '[:space:]' '\n' | tr '[:upper:]' '[:lower:]' \
  | tr -d '[:punct:]' | grep -v '^$' | sort -u | wc -l)
avg=$(echo "$input" | tr '[:space:]' '\n' | tr -d '[:punct:]' | grep -v '^$' \
  | awk '{ total += length($0); count++ } END { if(count>0) printf "%.1f", total/count; else print 0 }')
echo -e "${BOLD}${BLUE}Word Count${NC}"
printf "  Total words     : %d\n" "$total"
printf "  Unique words    : %d\n" "$unique"
printf "  Avg word length : %s chars\n" "$avg"
SCRIPT

# sentcount - count sentences
cat > "$DOTFILES/scripts/bin/sentcount" <<'SCRIPT'
#!/usr/bin/env bash
# sentcount - count sentences (splits on . ! ? followed by space or end)
# Usage:  sentcount [file]   |   echo "Hello. World!" | sentcount
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
input=$([ -n "${1:-}" ] && cat "$1" || cat)
# Count sentence-ending punctuation followed by whitespace or end-of-string
sentences=$(echo "$input" | grep -oE '[.!?]+(\s|$)' | wc -l)
# Fallback: if no terminators found but there's text, count as 1
if [ "$sentences" -eq 0 ] && [ -n "$(echo "$input" | tr -d '[:space:]')" ]; then
  sentences=1
fi
avg_words=0
words=$(echo "$input" | wc -w)
if [ "$sentences" -gt 0 ]; then
  avg_words=$(awk "BEGIN { printf \"%.1f\", $words/$sentences }")
fi
echo -e "${BOLD}${BLUE}Sentence Count${NC}"
printf "  Sentences             : %d\n" "$sentences"
printf "  Total words           : %d\n" "$words"
printf "  Avg words/sentence    : %s\n" "$avg_words"
SCRIPT

# paracount - count paragraphs
cat > "$DOTFILES/scripts/bin/paracount" <<'SCRIPT'
#!/usr/bin/env bash
# paracount - count paragraphs (separated by blank lines)
# Usage:  paracount [file]   |   cat essay.txt | paracount
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
input=$([ -n "${1:-}" ] && cat "$1" || cat)
# Count non-empty blocks separated by blank lines
paragraphs=$(echo "$input" | awk '
  BEGIN { p=0; in_para=0 }
  /^[[:space:]]*$/ { if(in_para) { p++; in_para=0 } next }
  { in_para=1 }
  END { if(in_para) p++ ; print p }
')
lines=$(echo "$input" | wc -l)
words=$(echo "$input" | wc -w)
echo -e "${BOLD}${BLUE}Paragraph Count${NC}"
printf "  Paragraphs  : %d\n" "$paragraphs"
printf "  Lines       : %d\n" "$lines"
printf "  Words       : %d\n" "$words"
SCRIPT

# replaceone - replace FIRST occurrence of a pattern in a file (in-place or stdout)
cat > "$DOTFILES/scripts/bin/replaceone" <<'SCRIPT'
#!/usr/bin/env bash
# replaceone - replace FIRST occurrence of OLD with NEW
# Usage:
#   replaceone "old" "new" file.txt          # edits file in-place
#   echo "hello world" | replaceone "o" "0"  # reads from stdin
GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
if [ -t 0 ]; then
  # File mode
  if [ "$#" -lt 3 ]; then
    echo -e "${RED}Usage: replaceone \"old\" \"new\" file.txt${NC}"
    exit 1
  fi
  old="$1"; new="$2"; file="$3"
  [ -f "$file" ] || { echo -e "${RED}File not found: $file${NC}"; exit 1; }
  # sed: replace only the FIRST match in the whole file (not per-line)
  python3 -c "
import sys, re
old, new, path = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
result = re.sub(re.escape(old), new, text, count=1)
open(path, 'w').write(result)
changed = text != result
print(('\033[0;32m Replaced first occurrence\033[0m') if changed else '\033[1;33m! Pattern not found\033[0m')
" "$old" "$new" "$file"
else
  # Stdin mode
  if [ "$#" -lt 2 ]; then
    echo -e "${RED}Usage: echo \"text\" | replaceone \"old\" \"new\"${NC}"
    exit 1
  fi
  old="$1"; new="$2"
  python3 -c "
import sys, re
old, new = sys.argv[1], sys.argv[2]
text = sys.stdin.read()
print(re.sub(re.escape(old), new, text, count=1), end='')
" "$old" "$new"
fi
SCRIPT

# replaceall - replace ALL occurrences of a pattern in a file (in-place or stdout)
cat > "$DOTFILES/scripts/bin/replaceall" <<'SCRIPT'
#!/usr/bin/env bash
# replaceall - replace ALL occurrences of OLD with NEW
# Usage:
#   replaceall "old" "new" file.txt          # edits file in-place, shows count
#   echo "hello world" | replaceall "l" "L"  # reads from stdin
GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
if [ -t 0 ]; then
  # File mode
  if [ "$#" -lt 3 ]; then
    echo -e "${RED}Usage: replaceall \"old\" \"new\" file.txt${NC}"
    exit 1
  fi
  old="$1"; new="$2"; file="$3"
  [ -f "$file" ] || { echo -e "${RED}File not found: $file${NC}"; exit 1; }
  python3 -c "
import sys, re
old, new, path = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
count = len(re.findall(re.escape(old), text))
result = re.sub(re.escape(old), new, text)
open(path, 'w').write(result)
if count:
    print(f'\033[0;32m Replaced {count} occurrence(s)\033[0m')
else:
    print('\033[1;33m! Pattern not found\033[0m')
" "$old" "$new" "$file"
else
  # Stdin mode
  if [ "$#" -lt 2 ]; then
    echo -e "${RED}Usage: echo \"text\" | replaceall \"old\" \"new\"${NC}"
    exit 1
  fi
  old="$1"; new="$2"
  python3 -c "
import sys, re
old, new = sys.argv[1], sys.argv[2]
text = sys.stdin.read()
print(re.sub(re.escape(old), new, text), end='')
" "$old" "$new"
fi
SCRIPT

# Mark all binaries executable
chmod +x \
  "$DOTFILES/scripts/bin/charcount" \
  "$DOTFILES/scripts/bin/wordcount" \
  "$DOTFILES/scripts/bin/sentcount" \
  "$DOTFILES/scripts/bin/paracount" \
  "$DOTFILES/scripts/bin/replaceone" \
  "$DOTFILES/scripts/bin/replaceall"

success "String operation utilities created."

# .zshrc 
cat > "$DOTFILES/zsh/.zshrc" <<'ZSHRC'

#  ~/.zshrc  -  managed via ~/dotfiles

# Powerlevel10k instant prompt - keep near top
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  you-should-use
  fzf
  tmux
  rust
  python
  node
  nvm
  docker
)

source "$ZSH/oh-my-zsh.sh"

# PATH
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/dotfiles/scripts/bin:$PATH"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ]          && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# uv + cargo
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"
[ -f "$HOME/.cargo/env" ]     && source "$HOME/.cargo/env"

# zoxide
eval "$(zoxide init zsh --cmd cd)"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
export FZF_DEFAULT_OPTS="
  --height 50% --layout=reverse --border
  --bind 'ctrl-/:toggle-preview'
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=numbers --line-range=:500 {}'"

# Editor
export EDITOR='nvim'
export VISUAL='nvim'

#  ALIASES

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ll='ls -lAh --color=auto'
alias la='ls -A --color=auto'
alias l='ls --color=auto'
alias cls='clear'

# Editors
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# System
alias top='btop'
alias mem='free -h'
alias df='df -h'
alias ports='netstat -tulanp'
alias ip='ip -c a'
alias myip='curl -s ifconfig.me && echo'
alias path='echo $PATH | tr ":" "\n"'
alias weather='curl wttr.in'
alias ff='fastfetch'

alias stfu='sudo shutdown -h now'
alias fkof='sudo reboot'

# Distro-aware system update
if command -v apt &>/dev/null; then
  alias update='sudo apt update && sudo apt upgrade -y'
elif command -v pacman &>/dev/null; then
  alias update='sudo pacman -Syu --noconfirm'
elif command -v dnf &>/dev/null; then
  alias update='sudo dnf upgrade -y'
fi

# bat (handles batcat vs bat across distros)
if command -v batcat &>/dev/null; then
  alias b='batcat'
  alias cat='batcat --paging=never'
  alias less='batcat'
  export BAT_BIN='batcat'
elif command -v bat &>/dev/null; then
  alias b='bat'
  alias cat='bat --paging=never'
  alias less='bat'
  export BAT_BIN='bat'
fi
export BAT_THEME="Catppuccin Mocha"

# bat global aliases - pipe any command's help through bat for colour
alias -g -- -h='-h 2>&1 | batcat --language=help --style=plain'
alias -g -- --help='--help 2>&1 | batcat --language=help --style=plain'

# fzf file finder with bat preview
alias f="fzf --preview 'batcat --color=always --style=numbers --line-range=:500 {}'"

# Git
alias gs='git status'
alias ga='git add'
alias gaa='git add .'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate --all'
alias gdiff='git diff --stat'
alias gstash='git stash'
alias gpop='git stash pop'
alias gbr='git branch -a'
alias gco='git checkout'
alias lg='lazygit'
# Undo last commit but keep changes staged
alias gundo='git reset --soft HEAD~1'
# Show what changed in last commit
alias glast='git show --stat HEAD'

# Python 
alias py='python3'
alias so='source .venv/bin/activate'
alias deac='deactivate'
alias uvsync='uv venv && source .venv/bin/activate && uv sync'
alias uvrun='uv run'
alias uvpkg='uv pip list'
alias uvfreeze='uv pip freeze > requirements.txt && echo "requirements.txt written"'

# Docker
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs -f'
alias dstop='docker stop $(docker ps -q)'
# Nuke all containers + images
alias deldok='docker ps -aq | xargs -r docker rm && docker images -q | xargs -r docker rmi'
# Add user to docker group (run once after Docker install, then re-login)
alias dok='sudo groupadd docker 2>/dev/null; sudo usermod -aG docker $USER && newgrp docker'
# Planutils container
alias plan='docker run -it --privileged planutils-dev:latest bash'

# Planning 
alias pddl="python3 /home/subhajitp/util/downward/fast-downward.py"
alias ai="npx https://github.com/google-gemini/gemini-cli"

# Process hunting
alias psg='ps aux | grep -v grep | grep -i'       # psg nginx
alias psport='ss -tlnp | grep'                     # psport 8080
pskill() {                                         # pskill nginx
  local pids
  pids=$(ps aux | grep -v grep | grep -i "$1" | awk '{print $2}')
  [ -z "$pids" ] && { echo "No process matching: $1"; return 1; }
  echo "$pids" | xargs kill -9 && echo "Killed: $pids"
}
portpid() { lsof -ti:"$1" || echo "Nothing on port $1"; }  # portpid 8080

# Network
alias bw='sudo bandwhich'                         # network monitor
alias pingg='ping -c 5 8.8.8.8'                  # quick connectivity check
alias dns='cat /etc/resolv.conf'
alias listening='ss -tlnp'
alias established='ss -tnp state established'

# Files & Disk
alias duh='du -h --max-depth=1 | sort -hr'       # disk usage current dir
alias duf='du -sh *'                              # size of each item here
alias largest='find . -type f -printf "%s %p\n" | sort -rn | head -20'
alias newest='find . -type f -newer . -maxdepth 2'
alias mkdirp='mkdir -p'                           # always create parents
alias cpv='cp -v'
alias mvv='mv -v'
# Safe rm - move to trash instead of immediate delete
trash() { mkdir -p "$HOME/.trash" && mv "$@" "$HOME/.trash/" && echo "Moved to ~/.trash"; }
alias trashls='ls -lA "$HOME/.trash"'
alias trashempty='rm -rf "$HOME/.trash"/*  && echo "Trash emptied"'

# Archives
alias mktar='tar -czvf'                           # mktar archive.tar.gz dir/
alias untar='tar -xzvf'                           # untar archive.tar.gz
alias mkzip='zip -r'                              # mkzip archive.zip dir/
extract() {                                       # extract any archive format
  case "$1" in
    *.tar.gz|*.tgz)  tar -xzvf "$1" ;;
    *.tar.bz2|*.tbz) tar -xjvf "$1" ;;
    *.tar.xz)        tar -xJvf "$1" ;;
    *.tar)           tar -xvf  "$1" ;;
    *.zip)           unzip "$1"     ;;
    *.gz)            gunzip "$1"    ;;
    *.bz2)           bunzip2 "$1"   ;;
    *.xz)            unxz "$1"      ;;
    *.rar)           unrar x "$1"   ;;
    *.7z)            7z x "$1"      ;;
    *)               echo "Unknown format: $1" ;;
  esac
}

# Clipboard
if command -v xclip &>/dev/null; then
  alias copy='xclip -selection clipboard'
  alias paste='xclip -selection clipboard -o'
elif command -v xsel &>/dev/null; then
  alias copy='xsel --clipboard --input'
  alias paste='xsel --clipboard --output'
elif command -v wl-copy &>/dev/null; then
  alias copy='wl-copy'
  alias paste='wl-paste'
fi

# tmux shortcuts
alias tns='tmux new-session -s'                  # tns work
alias ta='tmux attach -t'                         # ta work
alias tls='tmux list-sessions'
alias tkill='tmux kill-session -t'               # tkill work
alias treload='tmux source-file ~/.tmux.conf'

# Quick edits
alias zshrc='nvim ~/.zshrc'
alias soz='source ~/.zshrc && echo ".zshrc reloaded"'
alias vimrc='nvim ~/.config/nvim/init.lua'
alias tmuxconf='nvim ~/.tmux.conf'
alias hosts='sudo nvim /etc/hosts'
alias crontab_edit='EDITOR=nvim crontab -e'

# Misc productivity
alias now='date +"%T"'
alias today='date +"%Y-%m-%d"'
alias week='date +%V'
alias cal='cal -3'                               # show 3 months
alias h='history | tail -50'
alias hg='history | grep'                        # hg docker
alias reload='exec zsh'
alias serve='python3 -m http.server 8000'        # quick HTTP server here
alias json='python3 -m json.tool'                # prettify JSON: cat f.json | json
alias urlencode='python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip()))"'
alias urldecode='python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))"'
alias genpass='openssl rand -base64 24'          # generate secure password
alias sha='shasum -a 256'                        # quick checksum
alias timer='echo "Timer started. Press ctrl+c to stop." && date && time cat'
# Count files/dirs in current directory
alias countf='find . -maxdepth 1 -type f | wc -l'
alias countd='find . -maxdepth 1 -type d | wc -l'

# Audio
alias volfix="$HOME/dotfiles/scripts/bin/volfix"

#  STRING OPERATION UTILITIES
#  All tools accept:  tool [file]   OR   echo "text" | tool

alias cc='charcount'     # character count
alias ww='wordcount'     # word count (wc is taken)
alias sc='sentcount'     # sentence count
alias pc='paracount'     # paragraph count
alias rone='replaceone'  # replace first occurrence
alias rall='replaceall'  # replace all occurrences

# Combined text stats - all in one
textstats() {
  local input
  input=$([ -n "${1:-}" ] && cat "$1" || cat)
  echo -e "\033[1m\033[0;36m-- Text Statistics --\033[0m"
  echo "$input" | charcount
  echo ""
  echo "$input" | wordcount
  echo ""
  echo "$input" | sentcount
  echo ""
  echo "$input" | paracount
}

#  Powerlevel10k

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

#  Tip of the Day  (source last, after p10k, so it prints below the prompt)

[[ -f "$HOME/dotfiles/zsh/tips.zsh" ]] && source "$HOME/dotfiles/zsh/tips.zsh" && show_tip
ZSHRC

success ".zshrc written."

# tips.zsh : Tip of the Day engine
cat > "$DOTFILES/zsh/tips.zsh" <<'TIPS'
#  Tip of the Day - sourced at shell start via .zshrc
#  Run anytime:  tip


_TIPS=(
  # -- fzf --
  "fzf: Press \033[1mCtrl+T\033[0m to fuzzy-search files in any directory and paste the path."
  "fzf: Press \033[1mCtrl+R\033[0m to fuzzy-search your shell history - way faster than scrolling."
  "fzf: Press \033[1mAlt+C\033[0m to fuzzy-jump into any subdirectory instantly."
  "fzf: Use \033[1mCtrl+/\033[0m to toggle the bat preview pane while searching files."
  "fzf: Pipe to fzf and select multiple items with \033[1mTab\033[0m:  ls | fzf -m"
  "fzf: Kill a process interactively:  kill \$(ps aux | fzf | awk '{print \$2}')"

  # -- zoxide --
  "zoxide: Just type \033[1mcd project\033[0m - zoxide jumps to the most frecent match, no full path needed."
  "zoxide: Use \033[1mzi\033[0m for an interactive fzf-powered directory picker from your history."
  "zoxide: \033[1mzoxide query -l\033[0m lists all directories in your jump database by score."
  "zoxide: Run \033[1mzoxide add .\033[0m to manually add the current dir to your jump database."

  # -- tmux --
  "tmux: \033[1mCtrl+A |\033[0m splits the pane vertically,  \033[1mCtrl+A -\033[0m splits it horizontally."
  "tmux: \033[1mCtrl+A h/j/k/l\033[0m navigates between panes vim-style."
  "tmux: \033[1mCtrl+A r\033[0m reloads your tmux config without restarting."
  "tmux: Use \033[1mCtrl+A [\033[0m to enter copy mode, then vim keys to scroll and select."
  "tmux: \033[1mtns work\033[0m creates a new named session. \033[1mta work\033[0m re-attaches to it later."
  "tmux: \033[1mCtrl+A d\033[0m detaches from a session - it keeps running in the background."
  "tmux: \033[1mtls\033[0m lists all running sessions. Never lose work again."
  "tmux: Mouse mode is on - you can click panes and scroll with the trackpad."

  # -- git --
  "git: \033[1mglog\033[0m shows a beautiful graph of your entire branch history."
  "git: \033[1mgundo\033[0m (git reset --soft HEAD~1) undoes the last commit but keeps your changes staged."
  "git: \033[1mgstash\033[0m saves dirty work, \033[1mgpop\033[0m brings it back - great for switching branches mid-task."
  "git: \033[1mglast\033[0m shows a summary of what changed in the most recent commit."
  "git: \033[1mlg\033[0m opens lazygit - a full TUI git client. Faster than typing git commands."
  "git: \033[1mgdiff\033[0m shows a compact stat of what files changed and by how much."
  "git: Use \033[1mgit commit --amend --no-edit\033[0m to add a forgotten file to the last commit."
  "git: \033[1mgit bisect\033[0m binary-searches your history to find which commit introduced a bug."

  # -- neovim / nvchad --
  "nvim: Press \033[1mSpace\033[0m to open NVChad's command palette (which-key menu)."
  "nvim: \033[1m<Space>ff\033[0m opens the Telescope file finder. \033[1m<Space>fw\033[0m searches text in project."
  "nvim: \033[1mCtrl+n\033[0m opens NvimTree file explorer. Press \033[1ma\033[0m to create a new file."
  "nvim: \033[1m<Space>th\033[0m lets you switch themes live - NVChad ships with dozens."
  "nvim: In normal mode, \033[1mciw\033[0m deletes the current word and drops you into insert mode."
  "nvim: \033[1m<Space>ch\033[0m toggles line comment on the current line or visual selection."
  "nvim: \033[1mgg=G\033[0m auto-indents the entire file according to the language's rules."
  "nvim: Use \033[1m:s/old/new/g\033[0m to find-and-replace on the current line; \033[1m:%s/old/new/g\033[0m for the whole file."
  "nvim: \033[1mCtrl+o\033[0m jumps back to where you were - great after following a definition."

  # -- python --
  "uv: \033[1muvsync\033[0m creates a venv, activates it, and installs all deps from pyproject.toml - one command."
  "uv: \033[1muv run script.py\033[0m runs a script in an isolated env without manually activating anything."
  "uv: \033[1muv add requests\033[0m adds a package and updates pyproject.toml - no manual pip install."
  "uv: \033[1muv python install 3.12\033[0m installs a new Python version. \033[1muv python list\033[0m shows all available."
  "uv: \033[1muvfreeze\033[0m dumps your current env to requirements.txt in one shot."

  # -- rust / cargo --
  "rust: \033[1mcargo check\033[0m is much faster than \033[1mcargo build\033[0m - use it during development to catch errors."
  "rust: \033[1mcargo clippy\033[0m is a linter that catches common mistakes and suggests idiomatic code."
  "rust: \033[1mcargo doc --open\033[0m builds and opens docs for all your dependencies in the browser."
  "rust: \033[1mcargo add serde\033[0m adds a crate directly from the CLI - no need to edit Cargo.toml manually."

  # -- nvm / node --
  "nvm: \033[1mnvm ls\033[0m shows all installed Node versions. \033[1mnvm use 20\033[0m switches to Node 20."
  "nvm: \033[1mnvm install --lts\033[0m always installs the latest Long Term Support version."
  "nvm: Create a \033[1m.nvmrc\033[0m file in a project with just '20' and nvm will auto-switch when you enter it."

  # -- bat --
  "bat: \033[1mb file\033[0m shows files with syntax highlighting, line numbers, and git change markers."
  "bat: The \033[1m-h\033[0m and \033[1m--help\033[0m global aliases pipe any command's help text through bat for coloured output."
  "bat: \033[1mbat --list-themes\033[0m shows all available themes - you can change BAT_THEME in .zshrc."

  # -- string tools --
  "strings: \033[1mcc\033[0m counts characters,  \033[1mww\033[0m counts words,  \033[1msc\033[0m counts sentences - all support stdin or a file."
  "strings: \033[1mrone 'old' 'new' file.txt\033[0m replaces only the FIRST occurrence. \033[1mrall\033[0m replaces ALL."
  "strings: \033[1mtextstats essay.txt\033[0m shows a complete breakdown: chars, words, sentences, paragraphs."
  "strings: Pipe into string tools:  \033[1mecho 'Hello world.' | sc\033[0m  - works with any text source."

  # -- productivity --
  "productivity: \033[1mextract archive.tar.gz\033[0m handles any archive format - tar, zip, gz, bz2, xz, rar, 7z."
  "productivity: \033[1mtrash file\033[0m moves files to ~/.trash instead of deleting permanently. \033[1mtrashempty\033[0m clears it."
  "productivity: \033[1mserve\033[0m starts a Python HTTP server on port 8000 in the current directory."
  "productivity: \033[1mgenpass\033[0m generates a cryptographically secure random password via openssl."
  "productivity: \033[1mhg docker\033[0m searches your shell history for any command containing 'docker'."
  "productivity: \033[1mduh\033[0m shows disk usage for each item in the current directory, sorted by size."
  "productivity: \033[1mjson\033[0m (pipe to it) pretty-prints any JSON:  curl api.example.com | json"
  "productivity: \033[1murlencode\033[0m and \033[1murldecode\033[0m work from stdin - great for working with URLs in scripts."
  "productivity: \033[1mzshrcs\033[0m reloads your .zshrc without opening a new shell."
  "productivity: \033[1mbw\033[0m (bandwhich) shows live per-process network bandwidth - run with sudo."
  "productivity: \033[1mlargest\033[0m lists the 20 biggest files in the current directory tree."
  "productivity: \033[1mcountf\033[0m counts files,  \033[1mcountd\033[0m counts directories in the current folder."

  # -- shell tricks --
  "shell: \033[1m!!\033[0m repeats the last command.  \033[1msudo !!\033[0m re-runs it with sudo - classic."
  "shell: \033[1mCtrl+Z\033[0m suspends a running process. \033[1mfg\033[0m brings it back. \033[1mbg\033[0m runs it in background."
  "shell: \033[1mCtrl+W\033[0m deletes the previous word.  \033[1mCtrl+U\033[0m clears the entire line."
  "shell: \033[1mCtrl+A\033[0m jumps to start of line.  \033[1mCtrl+E\033[0m jumps to end."
  "shell: \033[1mAlt+.\033[0m pastes the last argument of the previous command - very handy."
  "shell: Append \033[1m2>&1 | tee output.log\033[0m to any command to see output AND save it to a file."
  "shell: \033[1mcd -\033[0m (or just type the alias \033[1m-\033[0m) jumps back to the previous directory."
  "shell: Use \033[1m{old,new}\033[0m brace expansion to rename:  \033[1mmv file.{txt,md}\033[0m renames file.txt : file.md"
)

show_tip() {
  local CYAN='\033[0;36m'
  local YELLOW='\033[1;33m'
  local BOLD='\033[1m'
  local DIM='\033[2m'
  local NC='\033[0m'

  local count="${#_TIPS[@]}"
  local idx=$(( RANDOM % count ))
  local tip="${_TIPS[$idx]}"

  # Extract category (text before first colon)
  local category="${tip%%:*}"
  local body="${tip#*: }"

  printf "\n${DIM}--------------------------------------------------${NC}\n"
  printf "${DIM}${NC} ${CYAN}${BOLD}💡 Tip${NC} ${DIM}[${category}]${NC}\n"
  printf "${DIM}${NC}\n"
  # Word-wrap body at ~60 chars
  echo -e "${DIM}${NC}  ${YELLOW}${body}${NC}" | fold -s -w 62 | while IFS= read -r line; do
    printf "${DIM}${NC}  %b\n" "$line"
  done
  printf "${DIM}${NC}\n"
  printf "${DIM}${NC}  ${DIM}Run 'tip' for another tip anytime.${NC}\n"
  printf "${DIM}--------------------------------------------------${NC}\n\n"
}

# 'tip' command - show a fresh random tip anytime
alias tip='show_tip'
TIPS
success "tips.zsh written ($(grep -c '  "' "$DOTFILES/zsh/tips.zsh") tips across fzf, tmux, git, nvim, uv, rust, shell tricks & more)."

# .tmux.conf
cat > "$DOTFILES/tmux/.tmux.conf" <<'TMUX'
# Prefix
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# General
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -g history-limit 50000
set -g mouse on
set -sg escape-time 10
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g status-interval 5
set -g focus-events on

# Key Bindings
bind r source-file ~/.tmux.conf \; display "Reloaded!"
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
unbind '"'
unbind %

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Status Bar
set -g status-position bottom
set -g status-style bg='#1e1e2e',fg='#cdd6f4'
set -g status-left-length 30
set -g status-right-length 60
set -g status-left '#[fg=#89b4fa,bold] #S #[default]'
set -g status-right '#[fg=#a6e3a1] %H:%M #[fg=#89dceb] %d-%b-%Y '
setw -g window-status-current-style fg='#f38ba8',bold
set -g pane-border-style fg='#45475a'
set -g pane-active-border-style fg='#89b4fa'

# Copy Mode
setw -g mode-keys vi
bind Enter copy-mode
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
TMUX
success ".tmux.conf written."

# .gitconfig
cat > "$DOTFILES/git/.gitconfig" <<'GITCONFIG'
[core]
  editor = nvim
  pager = bat
  autocrlf = input
[init]
  defaultBranch = main
[pull]
  rebase = false
[push]
  autoSetupRemote = true
[diff]
  colorMoved = default
[merge]
  conflictstyle = diff3
[alias]
  s    = status
  a    = add
  c    = commit
  p    = push
  l    = pull
  lg   = log --oneline --graph --decorate --all
  undo = reset HEAD~1 --mixed
  wip  = commit -am "WIP"
GITCONFIG
success ".gitconfig written."

# README
cat > "$DOTFILES/README.md" <<'README'
# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

```
dotfiles/
├── zsh/             : ~/.zshrc
├── tmux/            : ~/.tmux.conf
├── git/             : ~/.gitconfig
├── nvim/            : ~/.config/nvim/
└── scripts/bin/     : personal scripts (on PATH)
    └── volfix       : restart PipeWire / PulseAudio
```

## Apply

```bash
cd ~/dotfiles
mv ~/.zshrc ~/.zshrc.bak && mv ~/.tmux.conf ~/.tmux.conf.bak
stow zsh tmux git nvim
```

## Alias Quick Reference

------------------------------------------------------------------
| Alias         | What it does                                   |
|---------------|------------------------------------------------|
| `stfu`        | Shutdown immediately (`sudo shutdown -h now`)  |
| `fkof`        | Reboot immediately (`sudo reboot`)             |
| `ff`          | fastfetch system info                          |
| `volfix`      | Restart PipeWire / PulseAudio                  |
| `update`      | Distro-aware system upgrade                    |
| `psg <name>`  | Search running processes                       |
| `pskill <nm>` | Kill process by name                           |
| `psport <p>`  | Show what's on a port                          |
| `portpid <p>` | Get PID listening on port                      |
| `deldok`      | Remove all Docker containers + images          |
| `dok`         | Add user to docker group                       |
| `so`          | source .venv/bin/activate                      |
| `uvsync`      | uv venv + activate + sync                      |
| `f`           | fzf file picker with bat preview               |
| `b`           | bat / batcat                                   |
| `lg`          | lazygit                                        |
| `ai`          | Gemini CLI via npx                             |
| `pddl`        | Fast-Downward PDDL planner                     |
| `plan`        | planutils Docker container                     |
------------------------------------------------------------------
README

# Symlink Configs
header "Linking Configs"

# .zshrc - back up OMZ default, link ours
if [ ! -f "$HOME/.zshrc" ] || grep -q "# Path to your oh-my-zsh installation" "$HOME/.zshrc" 2>/dev/null; then
  [ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%s)"
  ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
  success ".zshrc : ~/dotfiles/zsh/.zshrc"
else
  skip ".zshrc (already customised - merge ~/dotfiles/zsh/.zshrc manually)"
fi

# .tmux.conf
if [ ! -f "$HOME/.tmux.conf" ]; then
  ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
  success ".tmux.conf symlinked."
else
  skip ".tmux.conf (exists - merge ~/dotfiles/tmux/.tmux.conf manually)"
fi

# .gitconfig - preserve existing identity
if [ ! -f "$HOME/.gitconfig" ]; then
  ln -sf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
  success ".gitconfig symlinked."
else
  skip ".gitconfig (exists - merge ~/dotfiles/git/.gitconfig manually)"
fi

# Final Summary
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  ✓  All done!${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Shell${NC}       Zsh + Oh My Zsh + Powerlevel10k"
echo -e "  ${CYAN}Fonts${NC}       JetBrainsMono Nerd Font  ·  MesloLGS NF"
echo -e "  ${CYAN}Editors${NC}     Neovim + NVChad  ·  VS Code"
echo -e "  ${CYAN}CLI${NC}         fzf · rg · bat · tmux · btop · htop · zoxide"
echo -e "  ${CYAN}Runtimes${NC}    uv (Python)  ·  nvm+Node LTS  ·  rustup  ·  Temurin JDK 21"
echo -e "  ${CYAN}C/C++${NC}       gcc · g++ · clang · cmake · make"
echo -e "  ${CYAN}Dotfiles${NC}    ~/dotfiles  (stow-managed)"
echo ""
echo -e "  ${BOLD}${YELLOW}String tools (all work on file or stdin):${NC}"
printf "   %-20s %s\n" "cc  [file|stdin]"    "--> character count"
printf "   %-20s %s\n" "ww  [file|stdin]"    "--> word count (total / unique / avg)"
printf "   %-20s %s\n" "sc  [file|stdin]"    "--> sentence count"
printf "   %-20s %s\n" "pc  [file|stdin]"    "--> paragraph count"
printf "   %-20s %s\n" "rone old new file"   "--> replace FIRST occurrence"
printf "   %-20s %s\n" "rall old new file"   "--> replace ALL occurrences"
printf "   %-20s %s\n" "textstats [file]"    "--> full combined stats"
echo ""
echo -e "  ${BOLD}${YELLOW}Productivity aliases (highlights):${NC}"
printf "   %-18s %s\n" "stfu"             "--> shutdown now"
printf "   %-18s %s\n" "fkof"             "--> reboot now"
printf "   %-18s %s\n" "ff"               "--> fastfetch"
printf "   %-18s %s\n" "bw"               "--> bandwhich live network monitor"
printf "   %-18s %s\n" "volfix"           "--> fix audio (PipeWire/PulseAudio)"
printf "   %-18s %s\n" "extract <file>"   "--> extract any archive format"
printf "   %-18s %s\n" "trash <file>"     "--> safe delete to ~/.trash"
printf "   %-18s %s\n" "serve"            "--> HTTP server on :8000 here"
printf "   %-18s %s\n" "genpass"          "--> secure random password"
printf "   %-18s %s\n" "duh"              "--> disk usage sorted by size"
printf "   %-18s %s\n" "hg <word>"        "--> grep command history"
printf "   %-18s %s\n" "json"             "--> prettify JSON from stdin"
printf "   %-18s %s\n" "zshrcs"           "--> reload .zshrc live"
printf "   %-18s %s\n" "tip"              "--> random shell/tool tip"
echo ""
echo -e "  ${BOLD}${CYAN}Remaining steps (after shell loads):${NC}"
echo -e "   1. ${BOLD}p10k configure${NC}         - Powerlevel10k setup wizard"
echo -e "   2. ${BOLD}nvim${NC}                   - auto-install NVChad plugins on first launch"
echo -e "   3. Set terminal font:  ${BOLD}JetBrainsMono Nerd Font${NC}  or  ${BOLD}MesloLGS NF${NC}"
echo -e "   4. Add git identity:   ${BOLD}~/.gitconfig${NC}  (user.name + user.email)"
echo ""

# Hand off to Zsh
# Export everything the new shell needs so it inherits a sane environment,
# then replace the current bash process with a fresh login zsh session.
# This is why aliases and tools are immediately available after install.

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/dotfiles/scripts/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"

ZSH_BIN="$(command -v zsh 2>/dev/null || true)"

if [ -n "$ZSH_BIN" ]; then
  echo -e "${BOLD}${GREEN}  Launching Zsh - your new shell is ready. Enjoy!${NC}"
  echo ""
  # -l = login shell so /etc/zsh/zprofile and ~/.zprofile are sourced
  # This makes all aliases, tools, and the tip-of-the-day available immediately
  exec "$ZSH_BIN" -l
else
  warn "zsh binary not found on PATH - run 'exec zsh -l' manually after install."
fi
