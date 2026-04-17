#!/usr/bin/env bash
set -e

echo "[KAYDEN INSTALLER] Starting..."

if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "[ERROR] Missing .env"
  exit 1
fi

# If gh exists, use it
if ! command -v gh >/dev/null 2>&1; then
  echo "[KAYDEN INSTALLER] Installing GitHub CLI..."
  # minimal fallback
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli.gpg
fi

# Auth if needed
gh auth status >/dev/null 2>&1 || gh auth login --web

# Clone Kayden
if [ ! -d "$TARGET_DIR" ]; then
  gh repo clone "$REPO_OWNER/$REPO_NAME" "$TARGET_DIR"
fi

# Install dependencies
if [ -f "$TARGET_DIR/requirements.txt" ]; then
  python3 -m pip install -r "$TARGET_DIR/requirements.txt"
fi

echo "[KAYDEN INSTALLER] Complete"