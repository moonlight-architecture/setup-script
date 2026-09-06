#!/usr/bin/env bash
set -Eeuo pipefail

#######################################
# Moonlight CLI Installer (Smart Check)
# moonlight-architecture/setup-script
#######################################

MOONLIGHT_HOME="$HOME/.moonlight"
MOONLIGHT_SCRIPT="$MOONLIGHT_HOME/moonlight.sh"
RAW_URL="https://raw.githubusercontent.com/moonlight-architecture/setup-script/main/moonlight.sh"
LOCAL_BIN="$HOME/.local/bin"

RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[32m'
BLUE='\033[34m'
YELLOW='\033[33m'

log()  { echo -e "${BLUE}🌕${RESET} ${BOLD}$*${RESET}"; }
done_log() { echo -e "${GREEN}✅${RESET} ${BOLD}$*${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $*${RESET}"; }
die()  { echo -e "❌ $*" >&2; exit 1; }

check_dependencies() {
  for cmd in curl git; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required."
  done
}

detect_profile() {
  [[ "${SHELL:-}" == *zsh* ]] && echo "$HOME/.zshrc" || echo "$HOME/.bashrc"
}

main() {
  clear
  echo -e "${BOLD}Moonlight CLI Installer${RESET}"
  echo "------------------------------------------------"

  # 1. Check if Moonlight is already installed
  if command -v moonlight >/dev/null 2>&1; then
    log "Moonlight is already installed!"
    log "Running 'moonlight update' for you instead..."
    echo "------------------------------------------------"
    moonlight update
    exit 0
  fi

  # 2. Proceed with Fresh Installation
  check_dependencies

  mkdir -p "$MOONLIGHT_HOME"
  local tmp_file=$(mktemp)

  log "Installing fresh version..."
  log "Downloading Moonlight CLI..."
  curl -fSL# "$RAW_URL" -o "$tmp_file" || die "Download failed."
  chmod +x "$tmp_file"
  mv "$tmp_file" "$MOONLIGHT_SCRIPT"

  # Setup Symlink
  mkdir -p "$LOCAL_BIN"
  rm -f "$LOCAL_BIN/moonlight"
  ln -s "$MOONLIGHT_SCRIPT" "$LOCAL_BIN/moonlight"
  done_log "Symlinked to $LOCAL_BIN/moonlight"

  # Ensure PATH
  local profile=$(detect_profile)
  touch "$profile"
  if ! grep -q "export PATH=.*$LOCAL_BIN" "$profile"; then
    log "Adding $LOCAL_BIN to PATH in $profile"
    echo -e "\n# Moonlight CLI\nexport PATH=\"$LOCAL_BIN:\$PATH\"" >> "$profile"
  fi

  done_log "Installation complete! 🚀"
  log "Restarting shell to activate..."

  hash -r 2>/dev/null || true
  exec "$SHELL" -l
}

main
