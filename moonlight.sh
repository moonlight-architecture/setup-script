#!/usr/bin/env bash
set -Eeuo pipefail

#######################################
# Moonlight CLI v0.0.1
# moonlight-architecture/setup-script
#######################################

VERSION="0.0.1"
TEMPLATE_URL="https://github.com/moonlight-architecture/java-starter-kit.git"
RAW_SCRIPT_URL="https://raw.githubusercontent.com/moonlight-architecture/setup-script/main/moonlight.sh"
BASE_GROUP_PATH="com/servicecops"
MOONLIGHT_HOME="$HOME/.moonlight"

COMMAND="${1:-help}"
APP_NAME="${2:-}"
TAG_VERSION="${3:-}"

# Colors and Styling
BOLD='\033[1m'
BLUE='\033[34m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

#######################################
# Utilities
#######################################

log()      { echo -e "${BLUE}🌕${RESET} $*"; }
done_log() { echo -e "${GREEN}✅${RESET} $*"; }
warn()     { echo -e "${YELLOW}⚠️  $*${RESET}"; }
die()      { echo -e "${RED}❌ $*${RESET}" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed."
}

detect_sed() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INPLACE=(-i '')
  else
    SED_INPLACE=(-i)
  fi
}

safe_sed() {
  local search="$1"
  local replace="$2"
  local file="$3"
  sed "${SED_INPLACE[@]}" "s$(printf '\001')$search$(printf '\001')$replace$(printf '\001')g" "$file"
}

detect_profile() {
  if [[ "${SHELL:-}" == *zsh* ]]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.bashrc"
  fi
}

#######################################
# HELP
#######################################

cmd_help() {
  echo -e "${BOLD}🌕 Moonlight CLI v$VERSION${RESET}"
  echo -e "Moonlight Spring Boot project toolkit"
  echo -e ""
  echo -e "${BOLD}Usage:${RESET}"
  echo -e "  moonlight <command> [options]"
  echo -e ""
  echo -e "${BOLD}Core Commands:${RESET}"
  echo -e "  ${BLUE}new${RESET} <name> [tag]      Create a new project from template"
  echo -e "  ${BLUE}check${RESET}                 Show latest available template tag"
  echo -e "  ${BLUE}update${RESET} | -u           Update Moonlight CLI to latest version"
  echo -e "  ${BLUE}version${RESET} | -v          Show installed CLI version"
  echo -e "  ${BLUE}uninstall${RESET}             Remove Moonlight CLI"
  echo -e "  ${BLUE}help${RESET} | -h             Show this help message"
  echo -e ""
  echo -e "${BOLD}Examples:${RESET}"
  echo -e "  moonlight new billing-service"
}

#######################################
# NEW PROJECT
#######################################

cmd_new() {
  require_cmd git
  require_cmd curl
  detect_sed

  [[ -n "$APP_NAME" ]] || die "Usage: moonlight new <project-name> [tag]"
  [[ ! -d "$APP_NAME" ]] || die "Directory '$APP_NAME' already exists."

  local PACKAGE_NAME
  PACKAGE_NAME="$(echo "$APP_NAME" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')"

  log "Fetching latest template tag..."
  local LATEST_TAG
  LATEST_TAG="$(git ls-remote --tags --sort="v:refname" "$TEMPLATE_URL" \
    | grep -v '\^{}' | awk -F/ '{print $3}' | tail -n 1 || true)"

  local TARGET_TAG="${TAG_VERSION:-${LATEST_TAG:-main}}"
  log "Using template tag: ${BOLD}$TARGET_TAG${RESET}"

  # Database Setup
  local DB_NAME DB_USER DB_PASS
  echo -e "\n${BOLD}📦 Database Configuration${RESET}"
  while true; do
    echo -ne "  ${BLUE}➜${RESET} Database Name [$APP_NAME]: "
    read -r DB_NAME
    DB_NAME="${DB_NAME:-$APP_NAME}"
    [[ "$DB_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && break
    warn "  Invalid database name. Use alphanumeric/underscores only."
  done

  echo -ne "  ${BLUE}➜${RESET} Database Username [postgres]: "
  read -r DB_USER
  DB_USER="${DB_USER:-postgres}"

  echo -ne "  ${BLUE}➜${RESET} Database Password (hidden): "
  read -rs DB_PASS
  echo -e "\n"

  if command -v psql >/dev/null 2>&1; then
    log "Checking PostgreSQL..."
    if ! PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -lqt 2>/dev/null \
      | cut -d\| -f1 | grep -qw "$DB_NAME"; then
      log "Creating database '$DB_NAME'..."
      PGPASSWORD="$DB_PASS" createdb -h localhost -U "$DB_USER" "$DB_NAME" \
        || warn "Database creation failed. You may need to create it manually."
    else
      log "Database '$DB_NAME' already exists."
    fi
  fi

  log "Cloning template..."
  git clone --depth 1 --branch "$TARGET_TAG" "$TEMPLATE_URL" "$APP_NAME" \
    || die "Clone failed. Verify GitHub access to moonlight-architecture/java-starter-kit."

  cd "$APP_NAME"

  safe_sed "<artifactId>project</artifactId>" "<artifactId>$APP_NAME</artifactId>" pom.xml
  safe_sed "<name>project</name>" "<name>$APP_NAME</name>" pom.xml

  local DEV_PROPS="src/main/resources/application-dev.properties"
  if [[ -f "$DEV_PROPS" ]]; then
    log "Configuring application-dev.properties..."
    safe_sed "{database_name}" "$DB_NAME" "$DEV_PROPS"
    safe_sed "{username}" "$DB_USER" "$DEV_PROPS"
    safe_sed "{password}" "$DB_PASS" "$DEV_PROPS"
  else
    warn "application-dev.properties not found. Skipping DB injection."
  fi

  for dir in src/main/java src/test/java; do
    local SRC="$dir/$BASE_GROUP_PATH/project"
    local DST="$dir/$BASE_GROUP_PATH/$PACKAGE_NAME"
    if [[ -d "$SRC" ]]; then
      mkdir -p "$DST"
      [ "$(ls -A "$SRC")" ] && cp -R "$SRC/"* "$DST/"
      rm -rf "$SRC"
    fi
  done

  find . -type f -name "*.java" \
    -exec sed "${SED_INPLACE[@]}" \
    "s/com.servicecops.project/com.servicecops.$PACKAGE_NAME/g" {} +

  log "Resetting Git history..."
  rm -rf .git
  git init -b main
  git add .
  git commit -m "Initial commit from Moonlight"

  # IDE Prompt
  echo -e "\n${BOLD}${GREEN}✨ Project '$APP_NAME' created successfully!${RESET}"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "  ${BLUE}1)${RESET} Open in ${BOLD}IntelliJ IDEA${RESET}"
  echo -e "  ${BLUE}2)${RESET} Open in ${BOLD}VS Code${RESET}"
  echo -e "  ${BLUE}3)${RESET} Stay in Terminal"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  echo -ne "  ${BLUE}➜${RESET} Select an option [3]: "
  read -r IDE_CHOICE

  case "${IDE_CHOICE:-3}" in
    1)
      log "Launching IntelliJ IDEA..."
      if command -v idea &>/dev/null; then
        idea .
      elif [[ "$OSTYPE" == "darwin"* ]]; then
        open -a "IntelliJ IDEA" . || warn "IntelliJ IDEA not found in Applications."
      else
        warn "Could not find 'idea' command in PATH."
      fi
      ;;
    2)
      log "Launching VS Code..."
      if command -v code &>/dev/null; then
        code .
      else
        warn "Could not find 'code' command in PATH."
      fi
      ;;
    *)
      log "Happy coding! Navigate to your project: ${BOLD}cd $APP_NAME${RESET}"
      ;;
  esac
}

#######################################
# CHECK
#######################################

cmd_check() {
  require_cmd git
  log "Checking latest template tag..."
  git ls-remote --tags --sort="v:refname" "$TEMPLATE_URL" \
    | grep -v '\^{}' | awk -F/ '{print $3}' | tail -n 1
}

#######################################
# UPDATE
#######################################

cmd_update() {
  require_cmd curl
  local TMP
  TMP="$(mktemp)"

  log "Checking for updates..."
  curl -fsSL "$RAW_SCRIPT_URL" -o "$TMP" || die "Failed to fetch update."

  local REMOTE_VERSION
  REMOTE_VERSION="$(grep '^VERSION=' "$TMP" | cut -d'"' -f2)"

  if [[ "$REMOTE_VERSION" != "$VERSION" ]]; then
    chmod +x "$TMP"
    mv "$TMP" "$0"
    log "Updated to v$REMOTE_VERSION"
    exec "$SHELL" -l
  else
    log "Already on latest version (v$VERSION)."
  fi
}

#######################################
# UNINSTALL
#######################################

cmd_uninstall() {
  echo -ne "${YELLOW}➜${RESET} Remove Moonlight CLI? (y/n): "
  read -r CONFIRM
  [[ "$CONFIRM" =~ ^[yY]$ ]] || exit 0

  local PROFILE
  PROFILE="$(detect_profile)"
  detect_sed

  log "Removing Moonlight files..."

  # 1. Remove binary symlink
  if [[ -L "$HOME/.local/bin/moonlight" ]] || [[ -f "$HOME/.local/bin/moonlight" ]]; then
    rm "$HOME/.local/bin/moonlight"
  fi

  # 2. Remove home directory
  rm -rf "$MOONLIGHT_HOME"

  # 3. Clean Shell Profile
  if [[ -f "$PROFILE" ]]; then
    sed "${SED_INPLACE[@]}" '/moonlight/d' "$PROFILE"
    sed "${SED_INPLACE[@]}" '/.local\/bin/d' "$PROFILE"
  fi

  done_log "Moonlight successfully removed."
  echo -e "Note: To clear the command cache in this window, run: ${BOLD}hash -r${RESET}"

  echo -ne "\n${BOLD}➜${RESET} Restart shell to apply changes? (y/n): "
  read -r RESTART
  if [[ "$RESTART" =~ ^[yY]$ ]]; then
    exec "$SHELL" -l
  fi
}

#######################################
# Dispatcher
#######################################

case "$COMMAND" in
  new)        cmd_new ;;
  check)      cmd_check ;;
  update|-u)  cmd_update ;;
  version|-v) echo -e "🌕 Moonlight CLI ${BOLD}v$VERSION${RESET}" ;;
  help|-h)    cmd_help ;;
  uninstall)  cmd_uninstall ;;
  *)          cmd_help ;;
esac
