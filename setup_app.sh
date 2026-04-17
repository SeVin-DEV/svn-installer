#!/usr/bin/env bash
set -e

############################################
# LOAD ENV
############################################

if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ Missing .env file"
  exit 1
fi

############################################
# OS DETECTION
############################################

OS_TYPE="unknown"

UNAME_OUT="$(uname -s)"

case "$UNAME_OUT" in
  Linux*)
    OS_TYPE="linux"
    ;;
  Darwin*)
    OS_TYPE="mac"
    ;;
  CYGWIN*|MINGW*|MSYS*)
    OS_TYPE="windows"
    ;;
esac

# Termux detection
if [ -n "$PREFIX" ] && [ -d "/data/data/com.termux" ]; then
  OS_TYPE="termux"
fi

# iSH (iOS Alpine shell)
if [ -f "/usr/bin/ish" ] || [ -n "$ISH" ]; then
  OS_TYPE="ish"
fi

echo "🧠 Detected OS: $OS_TYPE"

############################################
# PACKAGE INSTALL HELPERS
############################################

install_linux() {
  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y git curl python3 python3-pip
  elif command -v apk >/dev/null 2>&1; then
    apk add git curl python3 py3-pip
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git curl python3 python3-pip
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy git curl python python-pip
  else
    echo "❌ Unsupported Linux package manager"
    exit 1
  fi
}

install_mac() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew required on macOS"
    exit 1
  fi
  brew install git curl python
}

install_termux() {
  pkg update -y
  pkg install -y git curl python
}

install_ish() {
  apk add git curl python3 py3-pip
}

install_windows() {
  echo "⚠️ Windows detected (assumes Git Bash / WSL)"
  echo "Please ensure git, python3, and pip are installed manually."
}

############################################
# RUN DEP INSTALL
############################################

echo "📦 Checking base dependencies..."

if ! command -v git >/dev/null 2>&1; then
  echo "Installing git..."
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python3 missing, installing..."
fi

case "$OS_TYPE" in
  linux) install_linux ;;
  mac) install_mac ;;
  termux) install_termux ;;
  ish) install_ish ;;
  windows) install_windows ;;
esac

############################################
# GITHUB AUTH (GH CLI)
############################################

if command -v gh >/dev/null 2>&1; then
  echo "🔐 GitHub CLI detected"
else
  echo "📦 Installing GitHub CLI..."
  if [ "$OS_TYPE" = "linux" ]; then
    type apt >/dev/null 2>&1 && sudo apt install -y gh || true
    type dnf >/dev/null 2>&1 && sudo dnf install -y gh || true
  elif [ "$OS_TYPE" = "mac" ]; then
    brew install gh
  fi
fi

echo "🔑 Running GitHub login..."
gh auth login || true

############################################
# CLONE REPO
############################################

TARGET_DIR="${TARGET_DIR:-Kayden}"

if [ -d "$TARGET_DIR" ]; then
  echo "⚠️ Directory exists, skipping clone"
else
  echo "📥 Cloning repo..."
  gh repo clone "$REPO_OWNER/$REPO_NAME" "$TARGET_DIR" || \
  git clone "$GITHUB_REPO_URL" "$TARGET_DIR"
fi

cd "$TARGET_DIR"

############################################
# GIT CONFIG
############################################

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

echo "✅ Git configured"

############################################
# PYTHON DEPENDENCIES
############################################

if [ -f "requirements.txt" ]; then
  echo "📦 Installing Python dependencies..."
  python3 -m pip install --upgrade pip
  pip install -r requirements.txt
else
  echo "⚠️ No requirements.txt found"
fi

############################################
# DONE
############################################

echo "🚀 Setup complete. System ready."