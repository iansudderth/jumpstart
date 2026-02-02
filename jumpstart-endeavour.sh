#!/bin/bash

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Chezmoi configuration
CHEZMOI_REPO="https://github.com/iansudderth/dotfiles.git"

# Package arrays
AUR_PACKAGES=(
  '1password'
  'brave-bin'
  'bun-bin'
  'cromite-bin'
  'jetbrains-toolbox'
  'opencode'
  'perplexity'
  'volta'
)

OFFICIAL_PACKAGES=(
  'atuin'
  'awesome-terminal-fonts'
  'base-devel'
  'bash-completion'
  'bat'
  'chezmoi'
  'difftastic'
  'discord'
  'docker'
  'docker-compose'
  'eza'
  'firefox'
  'fzf'
  'git'
  'git-delta'
  'github-cli'
  'go'
  'gparted'
  'helix'
  'jq'
  'just'
  'k9s'
  'kitty'
  'lazygit'
  'lazydocker'
  'lua'
  'micro'
  'neovim'
  'nodejs'
  'npm'
  'oh-my-zsh-git'
  'ollama'
  'otf-droid-nerd'
  'otf-geist-mono-nerd'
  'pyenv'
  'python'
  'ripgrep'
  'rust'
  'starship'
  'tailscale'
  'thefuck'
  'ttf-jetbrains-mono-nerd'
  'ttf-profont-nerd'
  'ttf-roboto-mono-nerd'
  'ttf-ubuntu-mono-nerd'
  'ttf-ubuntu-nerd'
  'vlc'
  'yazi'
  'zellij'
  'zoxide'
  'zsh'
  'zsh-autocomplete'
  'zsh-autosuggestions'
  'zsh-completions'
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

  log_info "Starting EndeavorOS package installation..."

  check_system

  # this block pulls in the function declarations and inlines them with the sudo block
  sudo bash -c "$(
    declare -p RED GREEN YELLOW BLUE NC OFFICIAL_PACKAGES
    declare -f echo_red echo_green echo_yellow echo_blue
    declare -f log_info log_success log_warning log_error
    declare -f package_exists install_with_pacman
    declare -f install_dependencies update_system install_from_official
  )
  log_info \"Running privileged package installs...\"
  update_system
  install_dependencies
  install_from_official
  log_success \"Privileged package installs complete!\"
  "

  install_from_aur
  enable_services
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
  pacman -Q "$1" &>/dev/null
}

install_with_pacman() {
  local package="$1"

  if package_exists "$package"; then
    log_warning "$package is already installed, skipping"
    return 0
  fi

  log_info "Installing $package..."
  pacman -S --noconfirm "$package"
  log_success "$package installed"
}

install_with_yay() {
  local package="$1"

  if package_exists "$package"; then
    log_warning "$package is already installed, skipping"
    return 0
  fi

  log_info "Installing $package from AUR..."
  yay -S --noconfirm "$package"
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
  if ! grep -qi "endeavour\|arch" /etc/os-release; then
    log_error "This script is designed for EndeavorOS/Arch"
    exit 1
  fi
  if ! command -v yay &>/dev/null; then
    log_error "yay is not installed. EndeavorOS should have yay pre-installed."
    exit 1
  fi
  log_success "System check passed"
}

update_system() {
  log_info "Updating system..."
  pacman -Syu --noconfirm
  log_success "System updated"
}

install_dependencies() {
  log_info "Checking dependencies..."

  local deps_to_install=()

  if ! package_exists git; then
    deps_to_install+=("git")
  fi

  if ! package_exists base-devel; then
    deps_to_install+=("base-devel")
  fi

  if [ ${#deps_to_install[@]} -gt 0 ]; then
    log_info "Installing dependencies: ${deps_to_install[*]}"
    pacman -S --noconfirm "${deps_to_install[@]}"
    log_success "Dependencies installed"
  else
    log_info "All dependencies already installed"
  fi
}

# ============================================================================
# Package installation
# ============================================================================

install_from_official() {
  log_info "Installing packages from official repositories..."
  for package in "${OFFICIAL_PACKAGES[@]}"; do
    install_with_pacman "$package"
  done
}

install_from_aur() {
  log_info "Installing packages from AUR..."
  for package in "${AUR_PACKAGES[@]}"; do
    install_with_yay "$package"
  done
}

# ============================================================================
# Service management
# ============================================================================

enable_services() {
  log_info "Enabling services..."

  # Enable Docker
  if systemctl list-unit-files | grep -q docker.service; then
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
    sudo usermod -aG docker "$USER"
    log_success "Docker service enabled"
  fi

  # Enable Tailscale
  if systemctl list-unit-files | grep -q tailscaled.service; then
    sudo systemctl enable tailscaled.service
    sudo systemctl start tailscaled.service
    log_success "Tailscale service enabled"
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
