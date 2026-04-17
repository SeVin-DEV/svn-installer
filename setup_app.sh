#!/usr/bin/env bash
set -e

echo "[BOOTSTRAP] Starting universal installer..."

# =========================================================
# LOAD .ENV
# =========================================================
if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "[ERROR] Missing .env file"
  exit 1
fi

REPO_OWNER="${REPO_OWNER:-}"
REPO_NAME="${REPO_NAME:-}"
TARGET_DIR="${TARGET_DIR:-./project}"

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
  echo "[ERROR] REPO_OWNER or REPO_NAME not set in .env"
  exit 1
fi

REPO_FULL="$REPO_OWNER/$REPO_NAME"

# =========================================================
# ENV DETECTION
# =========================================================
detect_env() {

  OS="$(uname -s)"
  KERNEL="$(uname -r 2>/dev/null || echo "")"

  # macOS
  if [[ "$OS" == "Darwin" ]]; then
    echo "mac"
    return
  fi

  # WSL
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
    return
  fi

  # Termux
  if [ -d "/data/data/com.termux" ]; then
    echo "termux"
    return
  fi

  # iSH (Alpine iOS shell)
  if grep -qi alpine /etc/os-release 2>/dev/null && [[ "$KERNEL" == *"iSH"* || -f "/etc/alpine-release" ]]; then
    echo "ish"
    return
  fi

  # Linux distros
  if [ -f /etc/os-release ]; then
    . /etc/os-release

    case "$ID" in
      ubuntu) echo "ubuntu" ;;
      debian) echo "debian" ;;
      arch) echo "arch" ;;
      manjaro) echo "arch" ;;
      fedora) echo "fedora" ;;
      centos) echo "centos" ;;
      rhel) echo "rhel" ;;
      almalinux) echo "alma" ;;
      alpine) echo "alpine" ;;
      *) echo "unknown" ;;
    esac
    return
  fi

  echo "unknown"
}

ENV=$(detect_env)
echo "[BOOTSTRAP] Detected environment: $ENV"

# =========================================================
# PACKAGE INSTALLER ROUTER
# =========================================================
install_packages() {
  PKGS="$@"

  case "$ENV" in

    mac)
      brew install $PKGS
      ;;

    ubuntu|debian|wsl)
      sudo apt-get update -y
      sudo apt-get install -y $PKGS
      ;;

    fedora|rhel|alma)
      sudo dnf install -y $PKGS
      ;;

    arch)
      sudo pacman -Sy --noconfirm $PKGS
      ;;

    alpine|ish)
      apk add --no-cache $PKGS
      ;;

    termux)
      pkg update -y
      pkg install -y $PKGS
      ;;

    *)
      echo "[ERROR] Unsupported environment: $ENV"
      exit 1
      ;;
  esac
}

# =========================================================
# SYSTEM DEPENDENCIES
# =========================================================
install_system_deps() {
  echo "[BOOTSTRAP] Installing system dependencies..."

  install_packages git curl wget python3 python3-pip
}

# =========================================================
# GH CLI
# =========================================================
ensure_gh() {

  if command -v gh >/dev/null 2>&1; then
    echo "[BOOTSTRAP] GitHub CLI already installed"
    return
  fi

  echo "[BOOTSTRAP] Installing GitHub CLI..."

  case "$ENV" in

    ubuntu|debian|wsl)
      sudo apt-get install -y gh || {
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli.gpg
        echo "deb [arch=$(dpkg --print-architecture)] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
        sudo apt update -y
        sudo apt install -y gh
      }
      ;;

    fedora|rhel|alma)
      sudo dnf install -y gh
      ;;

    arch)
      sudo pacman -Sy --noconfirm github-cli
      ;;

    mac)
      brew install gh
      ;;

    alpine|ish|termux)
      echo "[BOOTSTRAP] gh not supported reliably here — using git fallback only"
      ;;
  esac
}

# =========================================================
# AUTH
# =========================================================
ensure_auth() {
  if command -v gh >/dev/null 2>&1; then
    gh auth status >/dev/null 2>&1 || {
      echo "[BOOTSTRAP] Running GitHub login..."
      gh auth login --web
    }
  else
    echo "[BOOTSTRAP] Skipping gh auth (not available)"
  fi
}

# =========================================================
# CLONE REPO (HYBRID)
# =========================================================
clone_repo() {

  if [ -d "$TARGET_DIR" ]; then
    echo "[BOOTSTRAP] Target directory already exists"
    return
  fi

  echo "[BOOTSTRAP] Cloning repo: $REPO_FULL"

  if command -v gh >/dev/null 2>&1; then
    gh repo clone "$REPO_FULL" "$TARGET_DIR"
  else
    git clone "https://github.com/$REPO_FULL.git" "$TARGET_DIR"
  fi
}

# =========================================================
# PYTHON DEPS
# =========================================================
install_python_deps() {

  if [ -f "$TARGET_DIR/requirements.txt" ]; then
    echo "[BOOTSTRAP] Installing Python dependencies..."
    python3 -m pip install --upgrade pip
    python3 -m pip install -r "$TARGET_DIR/requirements.txt"
  else
    echo "[BOOTSTRAP] No requirements.txt found"
  fi
}

# =========================================================
# GIT CONFIG
# =========================================================
setup_git() {

  if [ ! -z "$GIT_USER_NAME" ]; then
    git config --global user.name "$GIT_USER_NAME"
  fi

  if [ ! -z "$GIT_USER_EMAIL" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
  fi
}

# =========================================================
# MAIN
# =========================================================
main() {

  install_system_deps
  ensure_gh
  ensure_auth
  setup_git
  clone_repo
  install_python_deps

  echo "[BOOTSTRAP] INSTALL COMPLETE"
}

main