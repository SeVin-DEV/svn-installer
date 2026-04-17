#!/usr/bin/env bash
set -e

# =========================
# CONFIG
# =========================
REPO_URL="https://github.com/SeVin-DEV/kayden.git"
PROJECT_DIR="kayden"

REQUIREMENTS_FILE="requirements.txt"

# =========================
# HELPERS
# =========================
log() {
  echo -e "\033[1;32m[SETUP]\033[0m $1"
}

warn() {
  echo -e "\033[1;33m[WARN]\033[0m $1"
}

error() {
  echo -e "\033[1;31m[ERROR]\033[0m $1"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# =========================
# OS DETECTION
# =========================
OS_TYPE="unknown"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS_TYPE="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS_TYPE="mac"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  OS_TYPE="windows"
fi

log "Detected OS: $OS_TYPE"

# =========================
# INSTALL SYSTEM DEPENDENCIES
# =========================
install_system_deps_linux() {
  log "Installing system dependencies (Linux)..."

  sudo apt-get update -y

  sudo apt-get install -y \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-venv \
    build-essential
}

install_system_deps_mac() {
  log "Installing system dependencies (macOS)..."

  if ! command_exists brew; then
    error "Homebrew not found. Install it first: https://brew.sh"
  fi

  brew install git curl wget python
}

install_gh_cli() {
  log "Checking GitHub CLI..."

  if command_exists gh; then
    log "GitHub CLI already installed."
    return
  fi

  log "Installing GitHub CLI..."

  if [[ "$OS_TYPE" == "linux" ]]; then
    sudo apt-get install -y gh || {
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
      sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt update -y
      sudo apt install -y gh
    }
  elif [[ "$OS_TYPE" == "mac" ]]; then
    brew install gh
  else
    error "Unsupported OS for automatic gh install"
  fi
}

# =========================
# GITHUB AUTH
# =========================
github_login() {
  log "Starting GitHub authentication..."

  gh auth status >/dev/null 2>&1 && {
    log "Already authenticated with GitHub."
    return
  }

  gh auth login --web || {
    error "GitHub authentication failed."
  }
}

# =========================
# CLONE REPO
# =========================
clone_repo() {
  if [ -d "$PROJECT_DIR" ]; then
    log "Repo already exists, skipping clone."
    return
  fi

  log "Cloning repository..."
  gh repo clone SeVin-DEV/kayden "$PROJECT_DIR" || {
    error "Failed to clone repo."
  }
}

# =========================
# GIT CONFIG
# =========================
setup_git_config() {
  log "Configuring git..."

  read -p "Enter Git user.name: " git_name
  read -p "Enter Git user.email: " git_email

  git config --global user.name "$git_name"
  git config --global user.email "$git_email"

  log "Git configured."
}

# =========================
# PYTHON DEPENDENCIES
# =========================
install_python_deps() {
  log "Installing Python dependencies..."

  if [ ! -f "$PROJECT_DIR/$REQUIREMENTS_FILE" ]; then
    warn "No requirements.txt found."
    return
  fi

  python3 -m pip install --upgrade pip
  python3 -m pip install -r "$PROJECT_DIR/$REQUIREMENTS_FILE"
}

# =========================
# MAIN FLOW
# =========================
main() {
  log "Starting setup wizard..."

  if [[ "$OS_TYPE" == "linux" ]]; then
    install_system_deps_linux
  elif [[ "$OS_TYPE" == "mac" ]]; then
    install_system_deps_mac
  else
    error "Unsupported OS"
  fi

  install_gh_cli
  github_login
  setup_git_config
  clone_repo
  install_python_deps

  log "Setup complete. System is ready."
}

main