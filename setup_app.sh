#!/usr/bin/env bash

set -e

########################################
# LOAD INSTALLER ENV (.env)
########################################

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
  echo "[ERROR] Missing .env file for setup_app.sh"
  echo "Create it and add GitHub credentials + repo info."
  exit 1
fi

# shellcheck disable=SC2046
export $(grep -v '^#' "$ENV_FILE" | xargs)

########################################
# REQUIRED ENV VARS
########################################

: "${GITHUB_REPO_URL:?Missing GITHUB_REPO_URL in .env}"
: "${TARGET_DIR:?Missing TARGET_DIR in .env}"
: "${GIT_USER_NAME:?Missing GIT_USER_NAME in .env}"
: "${GIT_USER_EMAIL:?Missing GIT_USER_EMAIL in .env}"

########################################
# DETECT OS
########################################

detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      echo "$ID"
    else
      echo "linux-unknown"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

OS_TYPE=$(detect_os)
echo "[BOOTSTRAP] Detected OS: $OS_TYPE"

########################################
# INSTALL SYSTEM DEPENDENCIES
########################################

if [ ! -f "requirements.txt" ]; then
  echo "[ERROR] requirements.txt not found"
  exit 1
fi

install_linux() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    while read -r pkg; do
      sudo apt-get install -y "$pkg"
    done < requirements.txt

  elif command -v dnf >/dev/null 2>&1; then
    while read -r pkg; do
      sudo dnf install -y "$pkg"
    done < requirements.txt

  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm
    while read -r pkg; do
      sudo pacman -S --noconfirm "$pkg"
    done < requirements.txt

  else
    echo "[ERROR] No supported package manager found."
    exit 1
  fi
}

install_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "[BOOTSTRAP] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  while read -r pkg; do
    brew install "$pkg" || true
  done < requirements.txt
}

echo "[BOOTSTRAP] Installing dependencies..."

case "$OS_TYPE" in
  ubuntu|debian) install_linux ;;
  fedora) install_linux ;;
  arch) install_linux ;;
  macos) install_macos ;;
  *) echo "[WARN] Unknown OS, skipping dependency install" ;;
esac

########################################
# CLONE OR UPDATE REPO
########################################

if [ -d "$TARGET_DIR/.git" ]; then
  echo "[BOOTSTRAP] Repo exists, pulling latest..."
  cd "$TARGET_DIR"
  git pull origin main || true
  cd ..
else
  echo "[BOOTSTRAP] Cloning repo..."
  git clone "$GITHUB_REPO_URL" "$TARGET_DIR"
fi

########################################
# CONFIGURE GIT
########################################

cd "$TARGET_DIR"

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"
git config pull.rebase true
git config core.autocrlf input

cd ..

########################################
# DONE
########################################

echo "[BOOTSTRAP] Setup complete."
echo "Target: $TARGET_DIR"