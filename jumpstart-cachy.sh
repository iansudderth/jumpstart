#!/bin/bash

set -euo pipefail

SUDO_INSTALL=false
if [[ "${1:-}" == "--sudo-install" ]]; then
  SUDO_INSTALL=true
  shift
fi

# ============================================================================
# Configuration
# ============================================================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Chezmoi configuration
CHEZMOI_REPO="https://github.com/iansudderth/dotfiles.git"

# Package arrays
AUR_PACKAGES=(
  '1password'
  'opencode'
  'perplexity'
  'jetbrains-toolbox'
  'volta'
)

CORE_PACKAGES=(
)

EXTRA_PACKAGES=(
  'awesome-terminal-fonts'
  'bash-completion'
  'chezmoi'
  'difftastic'
  'discord'
  'git-delta'
  'gparted'
  'otf-droid-nerd'
  'otf-geist-mono-nerd'
  'pyenv'
  'rust'
  'starship'
  'thefuck'
  'ttf-jetbrains-mono-nerd'
  'ttf-profont-nerd'
  'ttf-roboto-mono-nerd'
  'ttf-ubuntu-mono-nerd'
  'ttf-ubuntu-nerd'
  'yazi'
  'zsh-autocomplete'
  'zsh-autosuggestions'
  'zsh-completions'
)

CACHY_PACKAGES=(
  'asusctl'
  'atuin'
  'bat'
  'brave-bin'
  'bun-bin'
  'cromite-bin'
  'docker'
  'eza'
  'firefox'
  'fzf'
  'git'
  'github-cli'
  'go'
  'graphene'
  'helix'
  'jq'
  'kitty'
  'lua'
  'micro'
  'neovim'
  'nodejs'
  'oh-my-zsh-git'
  'ollama'
  'python'
  'ripgrep'
  'tailscale'
  'vlc'
  'zellij'
  'zoxide'
  'zsh'
)

# ============================================================================
# Main
# ============================================================================

main() {

  log_info "Starting CachyOS package installation..."

  check_system

  (
    sudo -s
    log_info "Running privileged package installs..."
    install_dependencies
    install_from_core
    install_from_extra
    install_from_cachy
    log_success "Privileged package installs complete!"
  )

  install_yay
  install_from_aur
  sync_chezmoi

  log_success "Package installation complete!"
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
  local repo="$1"
  local package="$2"

  if package_exists "$package"; then
    log_warning "$package is already installed, skipping"
    return 0
  fi

  log_info "Installing $package from $repo..."
  pacman -S --noconfirm "$package"
  log_success "$package installed"
}

install_with_yay() {
  local repo="$1"
  local package="$2"

  if package_exists "$package"; then
    log_warning "$package is already installed, skipping"
    return 0
  fi

  log_info "Installing $package from $repo..."
  yay -S --noconfirm "$package"
  log_success "$package installed"
}

# ============================================================================
# System setup
# ============================================================================

check_system() {
  log_info "Checking system..."
  if [[ "$SUDO_INSTALL" != "true" && "$EUID" -eq 0 ]]; then
    log_error "Do not run this script as root. Run as a normal user; sudo is used for package installs."
    exit 1
  fi
  if ! grep -qi "arch\|cachy" /etc/os-release; then
    log_error "This script is designed for Arch/CachyOS"
    exit 1
  fi
  log_success "System check passed"
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

install_yay() {
  if command -v yay &>/dev/null; then
    log_info "yay is already installed"
    return 0
  fi

  log_info "Installing yay..."

  local temp_dir=$(mktemp -d)
  trap "rm -rf $temp_dir" EXIT

  cd "$temp_dir"
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm

  log_success "yay installed successfully"
}

# ============================================================================
# Package installation
# ============================================================================

install_from_core() {
  log_info "Installing packages from core repo..."
  for package in "${CORE_PACKAGES[@]}"; do
    install_with_pacman "core" "$package"
  done
}

install_from_extra() {
  log_info "Installing packages from extra repo..."
  for package in "${EXTRA_PACKAGES[@]}"; do
    install_with_pacman "extra" "$package"
  done
}

install_from_cachy() {
  log_info "Installing packages from cachy repo..."
  for package in "${CACHY_PACKAGES[@]}"; do
    install_with_pacman "cachy" "$package"
  done
}

install_from_aur() {
  log_info "Installing packages from AUR..."
  for package in "${AUR_PACKAGES[@]}"; do
    install_with_yay "AUR" "$package"
  done
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

  if ! package_exists chezmoi; then
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
