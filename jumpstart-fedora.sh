#!/bin/bash

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Chezmoi configuration
CHEZMOI_REPO="https://github.com/iansudderth/dotfiles.git"

# Packages from official Fedora repos
DNF_PACKAGES=(
  'bash-completion'
  'bat'
  'cargo'
  'curl'
  'discord'
  'eza'
  'firefox'
  'fzf'
  'git'
  'git-delta'
  'gparted'
  'golang'
  'helix'
  'jq'
  'kitty'
  'lua'
  'neovim'
  'nodejs'
  'npm'
  'python3'
  'python3-pip'
  'ripgrep'
  'rust'
  'starship'
  'util-linux-user'
  'vlc'
  'zoxide'
  'zsh'
)

# Packages to install via COPR (Fedora's community repos)
COPR_REPOS=(
  'atim/lazygit'
  'atim/lazydocker'
)

# Packages to install via cargo (Rust)
CARGO_PACKAGES=(
  'atuin'
  'difftastic'
  'just'
  'yazi-fm'
  'yazi-cli'
  'zellij'
)

# Packages to install via go
GO_PACKAGES=(
  'github.com/derailed/k9s@latest'
)

# Flatpak packages
FLATPAK_PACKAGES=(
  'com.jetbrains.Toolbox'
)

# RPM Fusion packages
RPMFUSION_PACKAGES=(
  'ffmpeg'
  'ffmpeg-libs'
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

  log_info "Starting Fedora package installation..."

  check_system

  # this block pulls in the function declarations and inlines them with the sudo block
  sudo bash -c "$(
    declare -p RED GREEN YELLOW BLUE NC DNF_PACKAGES COPR_REPOS RPMFUSION_PACKAGES
    declare -f echo_red echo_green echo_yellow echo_blue
    declare -f log_info log_success log_warning log_error
    declare -f package_exists install_with_dnf
    declare -f update_system install_dependencies enable_rpmfusion add_copr_repos install_from_dnf install_from_rpmfusion
  )
  log_info \"Running privileged package installs...\"
  update_system
  install_dependencies
  enable_rpmfusion
  add_copr_repos
  install_from_dnf
  install_from_rpmfusion
  log_success \"Privileged package installs complete!\"
  "

  install_flatpak_packages
  install_third_party_repos
  install_manual_packages
  install_pyenv
  install_go_packages
  install_cargo_packages
  install_nerd_fonts
  install_zsh_plugins
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
  rpm -q "$1" &>/dev/null
}

install_with_dnf() {
  local package="$1"

  if package_exists "$package"; then
    log_warning "$package is already installed, skipping"
    return 0
  fi

  log_info "Installing $package..."
  dnf install -y "$package"
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
  if ! grep -qi "fedora" /etc/os-release; then
    log_error "This script is designed for Fedora"
    exit 1
  fi
  log_success "System check passed"
}

update_system() {
  log_info "Updating system..."
  dnf upgrade -y
  log_success "System updated"
}

install_dependencies() {
  log_info "Installing base dependencies..."
  
  local deps=(
    'curl'
    'wget'
    'git'
    'dnf-plugins-core'
    '@development-tools'
    'openssl-devel'
    'bzip2-devel'
    'libffi-devel'
    'zlib-devel'
    'readline-devel'
    'sqlite-devel'
    'xz-devel'
  )

  for dep in "${deps[@]}"; do
    if [[ "$dep" == @* ]] || ! package_exists "$dep"; then
      dnf install -y "$dep"
    fi
  done

  log_success "Dependencies installed"
}

enable_rpmfusion() {
  log_info "Enabling RPM Fusion repositories..."
  
  if ! dnf repolist | grep -q rpmfusion; then
    dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    log_success "RPM Fusion enabled"
  else
    log_info "RPM Fusion already enabled"
  fi
}

add_copr_repos() {
  log_info "Adding COPR repositories..."

  for repo in "${COPR_REPOS[@]}"; do
    log_info "Enabling COPR repo: $repo"
    dnf copr enable -y "$repo"
  done

  # Install packages from COPR
  dnf install -y lazygit lazydocker

  log_success "COPR repositories added"
}

install_third_party_repos() {
  log_info "Installing third-party repositories..."

  # GitHub CLI
  if ! command -v gh &>/dev/null; then
    log_info "Adding GitHub CLI repository..."
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh
  fi

  # Brave Browser
  if ! command -v brave-browser &>/dev/null; then
    log_info "Adding Brave Browser repository..."
    sudo dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    sudo dnf install -y brave-browser
  fi

  # Tailscale
  if ! command -v tailscale &>/dev/null; then
    log_info "Adding Tailscale repository..."
    sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
    sudo dnf install -y tailscale
  fi

  # Docker
  if ! command -v docker &>/dev/null; then
    log_info "Adding Docker repository..."
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  log_success "Third-party repositories installed"
}

# ============================================================================
# Package installation
# ============================================================================

install_from_dnf() {
  log_info "Installing packages from DNF repositories..."
  for package in "${DNF_PACKAGES[@]}"; do
    install_with_dnf "$package"
  done
}

install_from_rpmfusion() {
  log_info "Installing packages from RPM Fusion..."
  for package in "${RPMFUSION_PACKAGES[@]}"; do
    install_with_dnf "$package"
  done
}

install_flatpak_packages() {
  log_info "Installing Flatpak packages..."
  
  if ! flatpak remote-list | grep -q "flathub"; then
    log_info "Adding Flathub repository..."
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

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
    sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
    sudo sh -c 'echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo'
    sudo dnf install -y 1password
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
    'Geist'
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
