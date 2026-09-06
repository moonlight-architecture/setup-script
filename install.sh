#!/usr/bin/env bash
set -Eeuo pipefail

#######################################
# Moonlight CLI Installer
# Prefers Homebrew; falls back to ~/.local/bin
# moonlight-architecture/setup-script
#######################################

MOONLIGHT_HOME="$HOME/.moonlight"
MOONLIGHT_SCRIPT="$MOONLIGHT_HOME/moonlight.sh"
RAW_URL="https://raw.githubusercontent.com/moonlight-architecture/setup-script/main/moonlight.sh"
LOCAL_BIN="$HOME/.local/bin"
TAP="moonlight-architecture/moonlight"
TAP_URL="https://github.com/moonlight-architecture/setup-script"
FORMULA="moonlight-architecture/moonlight/moonlight-cli"

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

brew_has_moonlight() {
  command -v brew >/dev/null 2>&1 || return 1
  brew list --formula moonlight-cli >/dev/null 2>&1 \
    || brew list --formula "$FORMULA" >/dev/null 2>&1
}

install_via_brew() {
  log "Installing via Homebrew..."
  brew tap "$TAP" "$TAP_URL"
  brew trust --formula "$FORMULA" || true
  brew install --formula "$FORMULA"
  done_log "Installed $(command -v moonlight)"
  moonlight setup || warn "Environment setup skipped. Run: moonlight setup"
}

upgrade_via_brew() {
  log "Moonlight CLI is already installed with Homebrew."
  log "Upgrading..."
  brew upgrade moonlight-cli \
    || brew upgrade "$FORMULA" \
    || warn "Already up to date (or upgrade failed)."
  moonlight setup || true
}

install_via_curl() {
  check_dependencies

  mkdir -p "$MOONLIGHT_HOME"
  local tmp_file
  tmp_file="$(mktemp)"

  log "Installing to $MOONLIGHT_SCRIPT..."
  curl -fSL# "$RAW_URL" -o "$tmp_file" || die "Download failed."
  chmod +x "$tmp_file"
  mv "$tmp_file" "$MOONLIGHT_SCRIPT"

  mkdir -p "$LOCAL_BIN"
  rm -f "$LOCAL_BIN/moonlight"
  ln -s "$MOONLIGHT_SCRIPT" "$LOCAL_BIN/moonlight"
  done_log "Symlinked to $LOCAL_BIN/moonlight"

  local profile
  profile="$(detect_profile)"
  touch "$profile"
  if ! grep -q "export PATH=.*$LOCAL_BIN" "$profile"; then
    log "Adding $LOCAL_BIN to PATH in $profile"
    echo -e "\n# Moonlight CLI\nexport PATH=\"$LOCAL_BIN:\$PATH\"" >> "$profile"
  fi

  "$MOONLIGHT_SCRIPT" setup || warn "Environment setup skipped. Run: moonlight setup"
  echo -e "Restart your shell, or run: ${BOLD}hash -r && export PATH=\"$LOCAL_BIN:\$PATH\"${RESET}"
}

main() {
  echo -e "${BOLD}Moonlight CLI Installer${RESET}"
  echo "------------------------------------------------"

  if brew_has_moonlight; then
    upgrade_via_brew
    done_log "Done."
    exit 0
  fi

  if command -v moonlight >/dev/null 2>&1; then
    log "Moonlight is already installed."
    log "Running 'moonlight update'..."
    echo "------------------------------------------------"
    moonlight update
    exit 0
  fi

  if command -v brew >/dev/null 2>&1; then
    install_via_brew
    done_log "Done. Homebrew put moonlight on your PATH."
    exit 0
  fi

  warn "Homebrew not found. Installing to ~/.local/bin instead."
  echo "  Standard install: brew tap $TAP $TAP_URL && brew trust --formula $FORMULA && brew install --formula $FORMULA"
  echo "------------------------------------------------"
  install_via_curl
  done_log "Installation complete."
}

main
