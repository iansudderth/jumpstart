#!/bin/bash

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Chezmoi configuration
CHEZMOI_REPO="https://github.com/iansudderth/dotfiles.git"

# Package arrays
CORE_PACKAGES=(
  'build-essential'
  'curl'
  'git'
  'wget'
)

EXTRA_PACKAGES=(
  'awesome-fonts'
  'bash-completion'
  'difftastic'
  'discord'
  'git-delta'
  'gparted'
  'just'
  'neovim'
  'python3-pip'
  'ripgrep'
  'starship'
  'thefuck'
  'zsh'
)

UBUNTU_PACKAGES=(
  'atuin'
  'bat'
  'brave-browser'
  'bun'
  'docker.io'
  'eza'
  'firefox'
  'fzf'
  'gh'
  'golang-go'
  'helix'
  'jq'
  'kitty'
  'lazydocker'
  'lua5.1'
  'micro'
  'nodejs'
  'npm'
  'python3'
  'tailscale'
  'vlc'
  'zoxide'
  'zsh'
)

PPA_REPOS=(
  'ppa:git-core/ppa'
  'ppa:neovim-ppa/unstable'
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

  log_info "Starting Ubuntu package installation..."

  check_system

  # this block pulls in the function declarations and inslines them with the sudo block
  sudo bash -c "$(
    declare -p RED GREEN YELLOW BLUE NC CORE_PACKAGES EXTRA_PACKAGES UBUNTU_PACKAGES PPA_REPOS
    declare -f echo_red echo_green echo_yellow echo_blue
    declare -f log_info log_success log_warning
    declare -f package_exists install_with_apt add_ppa_repos
    declare -f install_dependencies install_from_core install_from_extra install_from_ubuntu
  )
  log_info \"Running privileged package installs...\"
  add_ppa_repos
  install_dependencies
  install_from_core
  install_from_extra
  install_from_ubuntu
  log_success \"Privileged package installs complete!\"
  "

  install_ohmyzsh
  install_zsh_autosuggestions
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
  dpkg -l | grep -q "^ii  $1"
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
  if ! grep -qi "ubuntu" /etc/os-release; then
    log_error "This script is designed for Ubuntu"
    exit 1
  fi
  log_success "System check passed"
}

add_ppa_repos() {
  log_info "Adding PPA repositories..."

  for repo in "${PPA_REPOS[@]}"; do
    if grep -q "^deb.*$repo" /etc/apt/sources.list.d/* 2>/dev/null; then
      log_warning "PPA $repo is already added, skipping"
    else
      log_info "Adding PPA: $repo"
      add-apt-repository -y "$repo"
    fi
  done

  apt-get update
  log_success "PPA repositories added"
}

install_dependencies() {
  log_info "Checking dependencies..."

  local deps_to_install=()

  if ! package_exists git; then
    deps_to_install+=("git")
  fi

  if ! package_exists build-essential; then
    deps_to_install+=("build-essential")
  fi

  if ! command -v curl &>/dev/null; then
    deps_to_install+=("curl")
  fi

  if [ ${#deps_to_install[@]} -gt 0 ]; then
    log_info "Installing dependencies: ${deps_to_install[*]}"
    apt-get install -y "${deps_to_install[@]}"
    log_success "Dependencies installed"
  else
    log_info "All dependencies already installed"
  fi
}

# ============================================================================
# Package installation
# ============================================================================

install_from_core() {
  log_info "Installing core packages..."
  for package in "${CORE_PACKAGES[@]}"; do
    install_with_apt "$package"
  done
}

install_from_extra() {
  log_info "Installing extra packages..."
  for package in "${EXTRA_PACKAGES[@]}"; do
    install_with_apt "$package"
  done
}

install_from_ubuntu() {
  log_info "Installing packages from Ubuntu repositories..."
  for package in "${UBUNTU_PACKAGES[@]}"; do
    install_with_apt "$package"
  done
}

# ============================================================================
# Custom installations
# ============================================================================

install_ohmyzsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log_warning "Oh My Zsh is already installed, skipping"
    return 0
  fi

  log_info "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  log_success "Oh My Zsh installed successfully"
}

install_zsh_autosuggestions() {
  local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

  if [ -d "$plugin_dir" ]; then
    log_warning "zsh-autosuggestions is already installed, skipping"
    return 0
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_warning "Oh My Zsh is not installed, skipping zsh-autosuggestions installation"
    return 0
  fi

  log_info "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
  log_success "zsh-autosuggestions installed successfully"
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

