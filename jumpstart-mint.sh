#!/bin/bash

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Chezmoi configuration
CHEZMOI_REPO="https://github.com/iansudderth/dotfiles.git"

# Packages requiring manual installation
MANUAL_PACKAGES=(
  '1password'
  'volta'
  'bun'
  'ollama'
)

# Packages available via APT repositories
APT_PACKAGES=(
  'awesome-terminal-fonts'
  'bash-completion'
  'bat'
  'curl'
  'discord'
  'docker.io'
  'docker-compose'
  'eza'
  'firefox'
  'fzf'
  'git'
  'gparted'
  'helix'
  'jq'
  'kitty'
  'lua5.4'
  'neovim'
  'nodejs'
  'npm'
  'python3'
  'python3-pip'
  'ripgrep'
  'rust-all'
  'vlc'
  'zsh'
)

# Packages to install via cargo (Rust)
CARGO_PACKAGES=(
  'atuin'
  'difftastic'
  'git-delta'
  'just'
  'starship'
  'yazi-fm'
  'yazi-cli'
  'zellij'
  'zoxide'
)

# Packages to install via go
GO_PACKAGES=(
  'github.com/jesseduffield/lazygit@latest'
  'github.com/jesseduffield/lazydocker@latest'
  'github.com/derailed/k9s@latest'
)

# PPAs to add
declare -A PPAS=(
  ['github-cli']='ppa:github-cli/ppa'
  ['brave-browser']='ppa:brave/stable'
)

# Flatpak packages
FLATPAK_PACKAGES=(
  'com.jetbrains.Toolbox'
)

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Main
# ============================================================================

main() {

  log_info "Starting Linux Mint package installation..."

  check_system

  # this block pulls in the function declarations and inlines them with the sudo block
  sudo bash -c "$(
    declare -p RED GREEN YELLOW BLUE NC APT_PACKAGES PPAS
    declare -f echo_red echo_green echo_yellow echo_blue
    declare -f log_info log_success log_warning log_error
    declare -f package_exists install_with_apt
    declare -f update_repos add_ppas install_dependencies install_from_apt
  )
  log_info \"Running privileged package installs...\"
  update_repos
  install_dependencies
  add_ppas
  install_from_apt
  log_success \"Privileged package installs complete!\"
  "

  install_flatpak_packages
  install_pyenv
  install_go_packages
  install_cargo_packages
  install_manual_packages
  install_nerd_fonts
  install_zsh_plugins
  sync_chezmoi

  log_success "Package installation complete!"
  log_info "Please log out and log back in for all changes to take effect."
}

# ============================================================================
# Color utilities
# ============================================================================

echo_red() {
  echo -e "${RED}$1${NC}"
}

echo_green() {
  echo -e "${GREEN}$1${NC}"
}

echo_yellow() {
  echo -e "${YELLOW}$1${NC}"
}

echo_blue() {
  echo -e "${BLUE}$1${NC}"
}

# ============================================================================
# Logging
# ============================================================================

log_info() {
  echo_blue "[INFO] $1"
}

log_success() {
  echo_green "[SUCCESS] $1"
}

log_error() {
  echo_red "[ERROR] $1" >&2
}

log_warning() {
  echo_yellow "[WARNING] $1"
}

# ============================================================================
# Package utilities
# ============================================================================

package_exists() {
  dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

install_with_apt() {
  local package="$1"

  if package_exists "$package"; then
    log_warning "$package is already installed, skipping"
    return 0
  fi

  log_info "Installing $package..."
  apt-get install -y "$package"
  log_success "$package installed"
}

# ============================================================================
# System setup
# ============================================================================

check_system() {
  log_info "Checking system..."
  if [[ "$EUID" -eq 0 ]]; then
    log_error "Do not run this script as root. Run as a normal user; sudo is used for package installs."
    exit 1
  fi
  if ! grep -qi "mint\|ubuntu" /etc/os-release; then
    log_error "This script is designed for Linux Mint/Ubuntu"
    exit 1
  fi
  log_success "System check passed"
}

update_repos() {
  log_info "Updating package repositories..."
  apt-get update
  log_success "Repositories updated"
}

install_dependencies() {
  log_info "Installing base dependencies..."
  
  local deps=(
    'build-essential'
    'curl'
    'wget'
    'git'
    'software-properties-common'
    'apt-transport-https'
    'ca-certificates'
    'gnupg'
    'lsb-release'
  )

  for dep in "${deps[@]}"; do
    if ! package_exists "$dep"; then
      apt-get install -y "$dep"
    fi
  done

  log_success "Dependencies installed"
}

add_ppas() {
  log_info "Adding PPAs..."

  # Add GitHub CLI PPA
  if [[ -n "${PPAS['github-cli']}" ]]; then
    log_info "Adding GitHub CLI repository..."
    add-apt-repository -y "${PPAS['github-cli']}"
    apt-get install -y gh
  fi

  # Add Brave Browser
  if [[ -n "${PPAS['brave-browser']}" ]]; then
    log_info "Adding Brave Browser repository..."
    curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list
    apt-get update
    apt-get install -y brave-browser
  fi

  # Add Tailscale repository
  log_info "Adding Tailscale repository..."
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
  apt-get update
  apt-get install -y tailscale

  log_success "PPAs added"
}

# ============================================================================
# Package installation
# ============================================================================

install_from_apt() {
  log_info "Installing packages from APT repositories..."
  for package in "${APT_PACKAGES[@]}"; do
    install_with_apt "$package"
  done
}

install_flatpak_packages() {
  log_info "Setting up Flatpak..."
  
  if ! command -v flatpak &>/dev/null; then
    log_info "Installing Flatpak..."
    sudo apt-get install -y flatpak
  fi

  if ! flatpak remote-list | grep -q "flathub"; then
    log_info "Adding Flathub repository..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  log_info "Installing Flatpak packages..."
  for package in "${FLATPAK_PACKAGES[@]}"; do
    if flatpak list | grep -q "$package"; then
      log_warning "$package is already installed, skipping"
    else
      log_info "Installing $package..."
      flatpak install -y flathub "$package"
      log_success "$package installed"
    fi
  done
}

install_pyenv() {
  if [ -d "$HOME/.pyenv" ]; then
    log_info "pyenv is already installed"
    return 0
  fi

  log_info "Installing pyenv..."
  
  # Install pyenv dependencies
  sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
    libffi-dev liblzma-dev

  # Install pyenv
  curl https://pyenv.run | bash

  log_success "pyenv installed successfully"
}

install_go_packages() {
  if ! command -v go &>/dev/null; then
    log_warning "Go is not installed, skipping Go packages"
    return 0
  fi

  log_info "Installing Go packages..."
  for package in "${GO_PACKAGES[@]}"; do
    log_info "Installing $package..."
    go install "$package"
    log_success "$package installed"
  done
}

install_cargo_packages() {
  if ! command -v cargo &>/dev/null; then
    log_warning "Cargo is not installed, skipping Cargo packages"
    return 0
  fi

  log_info "Installing Cargo packages..."
  for package in "${CARGO_PACKAGES[@]}"; do
    if command -v "${package%%@*}" &>/dev/null; then
      log_warning "$package is already installed, skipping"
    else
      log_info "Installing $package..."
      cargo install "$package"
      log_success "$package installed"
    fi
  done
}

install_manual_packages() {
  log_info "Installing manual packages..."

  # 1Password
  if ! command -v 1password &>/dev/null; then
    log_info "Installing 1Password..."
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
      sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
      sudo tee /etc/apt/sources.list.d/1password.list
    sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
      sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
    sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
      sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
    sudo apt-get update
    sudo apt-get install -y 1password
    log_success "1Password installed"
  fi

  # Volta
  if ! command -v volta &>/dev/null; then
    log_info "Installing Volta..."
    curl https://get.volta.sh | bash
    log_success "Volta installed"
  fi

  # Bun
  if ! command -v bun &>/dev/null; then
    log_info "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    log_success "Bun installed"
  fi

  # Ollama
  if ! command -v ollama &>/dev/null; then
    log_info "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    log_success "Ollama installed"
  fi

  # Chezmoi
  if ! command -v chezmoi &>/dev/null; then
    log_info "Installing Chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    log_success "Chezmoi installed"
  fi

  # thefuck
  if ! command -v thefuck &>/dev/null; then
    log_info "Installing thefuck..."
    pip3 install --user thefuck
    log_success "thefuck installed"
  fi

  # oh-my-zsh
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    log_success "oh-my-zsh installed"
  fi

  # micro editor
  if ! command -v micro &>/dev/null; then
    log_info "Installing micro editor..."
    cd /tmp
    curl https://getmic.ro | bash
    sudo mv micro /usr/local/bin/
    log_success "micro installed"
  fi
}

install_nerd_fonts() {
  log_info "Installing Nerd Fonts..."
  
  local fonts_dir="$HOME/.local/share/fonts"
  mkdir -p "$fonts_dir"

  local fonts=(
    'JetBrainsMono'
    'RobotoMono'
    'UbuntuMono'
    'DroidSansMono'
  )

  for font in "${fonts[@]}"; do
    if [ -d "$fonts_dir/$font" ]; then
      log_warning "$font is already installed, skipping"
      continue
    fi

    log_info "Installing $font Nerd Font..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    curl -fLo "$font.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.zip"
    unzip -q "$font.zip" -d "$fonts_dir/$font"
    rm -rf "$temp_dir"
    log_success "$font Nerd Font installed"
  done

  fc-cache -fv
  log_success "Font cache updated"
}

install_zsh_plugins() {
  log_info "Installing ZSH plugins..."

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  # zsh-autosuggestions
  if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
    log_info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    log_success "zsh-autosuggestions installed"
  fi

  # zsh-completions
  if [ ! -d "$zsh_custom/plugins/zsh-completions" ]; then
    log_info "Installing zsh-completions..."
    git clone https://github.com/zsh-users/zsh-completions "$zsh_custom/plugins/zsh-completions"
    log_success "zsh-completions installed"
  fi

  # zsh-autocomplete
  if [ ! -d "$zsh_custom/plugins/zsh-autocomplete" ]; then
    log_info "Installing zsh-autocomplete..."
    git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git "$zsh_custom/plugins/zsh-autocomplete"
    log_success "zsh-autocomplete installed"
  fi
}

# ============================================================================
# Configuration management
# ============================================================================

sync_chezmoi() {
  if [ ${#CHEZMOI_REPO} -eq 0 ]; then
    log_warning "CHEZMOI_REPO not set, skipping chezmoi sync"
    return 0
  fi

  log_info "Syncing chezmoi from repository..."

  if ! command -v chezmoi &>/dev/null; then
    log_error "chezmoi is not installed"
    return 1
  fi

  if chezmoi init --apply "$CHEZMOI_REPO"; then
    log_success "chezmoi synced successfully"
  else
    log_error "Failed to sync chezmoi"
    return 1
  fi
}

# ============================================================================
# Execute
# ============================================================================

main
