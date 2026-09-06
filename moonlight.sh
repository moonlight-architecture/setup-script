#!/usr/bin/env bash
set -Eeuo pipefail

#######################################
# Moonlight CLI v0.0.3
# moonlight-architecture/setup-script
#######################################

VERSION="0.0.3"
TEMPLATE_URL="https://github.com/moonlight-architecture/java-starter-kit.git"
RAW_SCRIPT_URL="https://raw.githubusercontent.com/moonlight-architecture/setup-script/main/moonlight.sh"
BASE_GROUP_PATH="com/servicecops"
MOONLIGHT_HOME="$HOME/.moonlight"
REQUIRED_JAVA_MAJOR=25
KNOWN_ENVS="dev uat prod"

COMMAND="${1:-}"
ARG2="${2:-}"
ARG3="${3:-}"

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

os_family() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) echo macos ;;
    Linux)  echo linux ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *)
      if [[ -n "${WINDIR:-}" || "${OS:-}" == "Windows_NT" ]]; then
        echo windows
      else
        echo unknown
      fi
      ;;
  esac
}

is_windows() { [[ "$(os_family)" == windows ]]; }
is_macos()   { [[ "$(os_family)" == macos ]]; }

detect_sed() {
  if is_macos; then
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
  elif [[ -f "$HOME/.bash_profile" ]] && is_windows; then
    echo "$HOME/.bash_profile"
  else
    echo "$HOME/.bashrc"
  fi
}

java_executable() {
  local home="$1"
  if [[ -n "$home" && -x "$home/bin/java" ]]; then
    echo "$home/bin/java"
    return 0
  fi
  if [[ -n "$home" && -x "$home/bin/java.exe" ]]; then
    echo "$home/bin/java.exe"
    return 0
  fi
  return 1
}

launch_intellij() {
  local project="$1"
  [[ -d "$project" ]] || die "Project directory not found: $project"
  log "Opening IntelliJ IDEA at $project"

  if command -v idea >/dev/null 2>&1; then
    idea "$project"
    return 0
  fi
  if command -v idea64 >/dev/null 2>&1; then
    idea64 "$project"
    return 0
  fi
  if is_macos; then
    open -na "IntelliJ IDEA.app" --args "$project" \
      || open -a "IntelliJ IDEA" "$project" \
      || warn "IntelliJ IDEA was not found."
    return 0
  fi
  if is_windows; then
    local idea_exe
    idea_exe="$(ls /c/Program\ Files/JetBrains/*/bin/idea64.exe 2>/dev/null | head -n 1 || true)"
    if [[ -n "$idea_exe" ]]; then
      "$idea_exe" "$project"
      return 0
    fi
  fi
  warn "Could not find IntelliJ IDEA. Open this folder from the IDE: $project"
}

launch_vscode() {
  local project="$1"
  [[ -d "$project" ]] || die "Project directory not found: $project"
  log "Opening VS Code at $project"
  if command -v code >/dev/null 2>&1; then
    code "$project"
  else
    warn "Could not find the 'code' command on PATH. Open this folder from VS Code: $project"
  fi
}

write_windows_launcher() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<'EOF'
@echo off
setlocal
set "SCRIPT=%USERPROFILE%\.moonlight\moonlight.sh"
where bash >nul 2>&1 && bash "%SCRIPT%" %* && exit /b %ERRORLEVEL%
if exist "%ProgramFiles%\Git\bin\bash.exe" (
  "%ProgramFiles%\Git\bin\bash.exe" "%SCRIPT%" %*
  exit /b %ERRORLEVEL%
)
echo Moonlight requires Git Bash. Install Git for Windows: https://git-scm.com/download/win
exit /b 1
EOF
}

script_path() {
  local p="$0"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p"
  elif command -v readlink >/dev/null 2>&1; then
    readlink -f "$p" 2>/dev/null || echo "$p"
  else
    echo "$p"
  fi
}

is_brew_install() {
  local p
  p="$(script_path)"
  case "$p" in
    */Cellar/moonlight-cli/*) return 0 ;;
  esac
  if command -v brew >/dev/null 2>&1; then
    brew list --formula moonlight-cli >/dev/null 2>&1 && return 0
  fi
  return 1
}

brew_upgrade_moonlight() {
  brew upgrade moonlight-cli \
    || brew upgrade moonlight-architecture/moonlight/moonlight-cli \
    || die "Homebrew upgrade failed. Try: brew upgrade moonlight-cli"
}

is_moonlight_app() {
  local dir="${1:-.}"
  [[ -f "$dir/pom.xml" ]] || return 1
  [[ -f "$dir/src/main/resources/application.properties" ]] || return 1
  grep -q 'com.jet.moonlight' "$dir/pom.xml" 2>/dev/null
}

list_envs() {
  local dir="${1:-.}"
  local f
  for f in "$dir"/src/main/resources/application-*.properties; do
    [[ -f "$f" ]] || continue
    basename "$f" | sed 's/^application-//;s/\.properties$//'
  done
}

is_known_env() {
  local name="$1"
  local env
  for env in $KNOWN_ENVS; do
    [[ "$env" == "$name" ]] && return 0
  done
  if is_moonlight_app; then
    for env in $(list_envs); do
      [[ "$env" == "$name" ]] && return 0
    done
  fi
  return 1
}

default_env() {
  local props="src/main/resources/application.properties"
  local active
  if [[ -f "$props" ]]; then
    active="$(get_prop "$props" "spring.profiles.active" || true)"
    if [[ -n "$active" ]]; then
      echo "$active"
      return 0
    fi
  fi
  echo "dev"
}

resolve_env() {
  local requested="${1:-}"
  if [[ -n "$requested" ]]; then
    echo "$requested"
    return 0
  fi
  default_env
}

props_for_env() {
  echo "src/main/resources/application-${1}.properties"
}

get_prop() {
  local file="$1"
  local key="$2"
  local line=""
  [[ -f "$file" ]] || return 1
  line="$(grep -E "^${key}=" "$file" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1
  echo "${line#${key}=}"
}

set_prop() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp found=0
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp)"
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "${key}="* ]]; then
        printf '%s=%s\n' "$key" "$value"
        found=1
      else
        printf '%s\n' "$line"
      fi
    done < "$file" > "$tmp"
    [[ "$found" -eq 1 ]] || printf '%s=%s\n' "$key" "$value" >> "$tmp"
    mv "$tmp" "$file"
  else
    printf '%s=%s\n' "$key" "$value" > "$file"
    rm -f "$tmp"
  fi
}

has_placeholder() {
  local value="${1:-}"
  [[ "$value" == *"{database_name}"* || "$value" == *"{username}"* || "$value" == *"{password}"* ]]
}

#######################################
# Java 25
#######################################

java_major() {
  local bin="$1"
  "$bin" -version 2>&1 | awk -F'[\"._]' '/version/ { print ($2=="1" ? $3 : $2); exit }'
}

java_major_ok() {
  local bin="$1"
  local major
  [[ -x "$bin" ]] || return 1
  major="$(java_major "$bin" || true)"
  [[ -n "${major:-}" && "$major" -ge "$REQUIRED_JAVA_MAJOR" ]]
}

java_home_ok() {
  local home="$1"
  local bin
  bin="$(java_executable "$home" || true)"
  [[ -n "$bin" ]] && java_major_ok "$bin"
}

java_home_from_bin() {
  local bin="$1"
  local resolved
  if is_macos && [[ -x /usr/libexec/java_home ]]; then
    /usr/libexec/java_home 2>/dev/null && return 0
  fi
  if command -v realpath >/dev/null 2>&1; then
    resolved="$(realpath "$bin")"
  elif command -v readlink >/dev/null 2>&1; then
    resolved="$(readlink -f "$bin" 2>/dev/null || echo "$bin")"
  else
    resolved="$bin"
  fi
  (cd "$(dirname "$resolved")/.." && pwd)
}

adoptium_os_arch() {
  case "$(os_family)" in
    macos)   echo -n "mac" ;;
    linux)   echo -n "linux" ;;
    windows) echo -n "windows" ;;
    *)       die "Unsupported OS. Install Java ${REQUIRED_JAVA_MAJOR}+ and re-run moonlight setup." ;;
  esac
  echo -n "/"
  case "$(uname -m)" in
    arm64|aarch64) echo "aarch64" ;;
    x86_64|amd64)  echo "x64" ;;
    *)             die "Unsupported architecture: $(uname -m). Install Java ${REQUIRED_JAVA_MAJOR}+ manually." ;;
  esac
}

find_java_home() {
  local candidate java_bin brew_prefix formula

  if [[ -n "${JAVA_HOME:-}" ]] && java_home_ok "$JAVA_HOME"; then
    echo "$JAVA_HOME"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    brew_prefix="$(brew --prefix 2>/dev/null || true)"
    for formula in "openjdk@${REQUIRED_JAVA_MAJOR}" "temurin@${REQUIRED_JAVA_MAJOR}" openjdk; do
      candidate="${brew_prefix}/opt/${formula}/libexec/openjdk.jdk/Contents/Home"
      if java_home_ok "$candidate"; then
        echo "$candidate"
        return 0
      fi
      candidate="${brew_prefix}/opt/${formula}"
      if java_home_ok "$candidate"; then
        echo "$candidate"
        return 0
      fi
    done
  fi

  if is_macos && [[ -x /usr/libexec/java_home ]]; then
    candidate="$(/usr/libexec/java_home -v "$REQUIRED_JAVA_MAJOR" 2>/dev/null || true)"
    if java_home_ok "$candidate"; then
      echo "$candidate"
      return 0
    fi
  fi

  if command -v java >/dev/null 2>&1; then
    java_bin="$(command -v java)"
    if java_major_ok "$java_bin"; then
      java_home_from_bin "$java_bin"
      return 0
    fi
  fi

  if java_home_ok "$MOONLIGHT_HOME/jdk/current"; then
    echo "$MOONLIGHT_HOME/jdk/current"
    return 0
  fi
  if [[ -f "$MOONLIGHT_HOME/jdk/current.path" ]]; then
    candidate="$(tr -d '\r' < "$MOONLIGHT_HOME/jdk/current.path")"
    if java_home_ok "$candidate"; then
      echo "$candidate"
      return 0
    fi
  fi

  if is_windows; then
    for candidate in \
      /c/Program\ Files/Eclipse\ Adoptium/jdk-"${REQUIRED_JAVA_MAJOR}"* \
      /c/Program\ Files/Java/jdk-"${REQUIRED_JAVA_MAJOR}"* \
      /c/Program\ Files/Microsoft/jdk-"${REQUIRED_JAVA_MAJOR}"* \
      "$HOME/scoop/apps/temurin${REQUIRED_JAVA_MAJOR}-jdk/current" \
      "$HOME/scoop/apps/openjdk/current"
    do
      if java_home_ok "$candidate"; then
        echo "$candidate"
        return 0
      fi
    done
  fi

  for candidate in /usr/lib/jvm/java-"${REQUIRED_JAVA_MAJOR}"-openjdk* \
                   /usr/lib/jvm/java-"${REQUIRED_JAVA_MAJOR}"-temurin* \
                   /usr/lib/jvm/temurin-"${REQUIRED_JAVA_MAJOR}"*; do
    if java_home_ok "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

persist_java_home() {
  local home="$1"
  local profile
  profile="$(detect_profile)"
  touch "$profile"
  if grep -q '# Moonlight Java' "$profile" 2>/dev/null; then
    return 0
  fi
  log "Adding JAVA_HOME to $profile"
  cat >> "$profile" <<EOF

# Moonlight Java
export JAVA_HOME="$home"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
}

activate_java() {
  local home="$1"
  local bin
  export JAVA_HOME="$home"
  export PATH="$JAVA_HOME/bin:$PATH"
  bin="$(java_executable "$home" || true)"
  [[ -n "$bin" ]] || return 0
}

link_jdk_current() {
  local home="$1"
  mkdir -p "$MOONLIGHT_HOME/jdk"
  rm -rf "$MOONLIGHT_HOME/jdk/current"
  if ln -sfn "$home" "$MOONLIGHT_HOME/jdk/current" 2>/dev/null; then
    return 0
  fi
  # Git Bash on Windows may not allow symlinks without Developer Mode.
  printf '%s\n' "$home" > "$MOONLIGHT_HOME/jdk/current.path"
}

install_java_via_brew() {
  local home
  command -v brew >/dev/null 2>&1 || return 1
  log "Installing openjdk@${REQUIRED_JAVA_MAJOR} with Homebrew..."
  brew install "openjdk@${REQUIRED_JAVA_MAJOR}" || return 1
  home="$(find_java_home)" || return 1
  activate_java "$home"
  done_log "Java ${REQUIRED_JAVA_MAJOR} available via Homebrew ($home)"
  return 0
}

install_java_via_windows_pkg() {
  local home
  is_windows || return 1
  if command -v winget >/dev/null 2>&1; then
    log "Installing Eclipse Temurin ${REQUIRED_JAVA_MAJOR} with winget..."
    winget install --id "EclipseAdoptium.Temurin.${REQUIRED_JAVA_MAJOR}.JDK" -e \
      --accept-package-agreements --accept-source-agreements || return 1
  elif command -v scoop >/dev/null 2>&1; then
    log "Installing Temurin ${REQUIRED_JAVA_MAJOR} with Scoop..."
    scoop install "temurin${REQUIRED_JAVA_MAJOR}-jdk" || return 1
  elif command -v choco >/dev/null 2>&1; then
    log "Installing Temurin ${REQUIRED_JAVA_MAJOR} with Chocolatey..."
    choco install "temurin${REQUIRED_JAVA_MAJOR}" -y || return 1
  else
    return 1
  fi
  home="$(find_java_home)" || return 1
  activate_java "$home"
  done_log "Java ${REQUIRED_JAVA_MAJOR} available ($home)"
  return 0
}

install_java() {
  local os_arch os arch url tmp work extracted home java_bin

  if install_java_via_brew; then
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    warn "Homebrew Java install did not succeed. Falling back to Temurin..."
  fi
  if install_java_via_windows_pkg; then
    return 0
  fi

  require_cmd curl
  os_arch="$(adoptium_os_arch)"
  os="${os_arch%/*}"
  arch="${os_arch#*/}"
  url="https://api.adoptium.net/v3/binary/latest/${REQUIRED_JAVA_MAJOR}/ga/${os}/${arch}/jdk/hotspot/normal/eclipse?project=jdk"

  tmp="$(mktemp)"
  work="$(mktemp -d)"
  trap 'rm -f "$tmp"; rm -rf "$work"' RETURN

  log "Installing Eclipse Temurin ${REQUIRED_JAVA_MAJOR} (${os}/${arch})..."
  curl -fSL --progress-bar "$url" -o "$tmp" || die "Failed to download Java ${REQUIRED_JAVA_MAJOR}."

  mkdir -p "$MOONLIGHT_HOME/jdk"
  if is_windows; then
    require_cmd unzip
    unzip -q "$tmp" -d "$work"
    extracted="$(find "$work" -type f \( -path '*/bin/java' -o -path '*/bin/java.exe' \) | head -n 1 || true)"
  else
    require_cmd tar
    tar -xf "$tmp" -C "$work"
    extracted="$(find "$work" -type f -path '*/bin/java' | head -n 1 || true)"
  fi
  [[ -n "$extracted" ]] || die "Downloaded Java archive did not contain a JDK."
  extracted="$(cd "$(dirname "$extracted")/.." && pwd)"

  home="$MOONLIGHT_HOME/jdk/$(basename "$extracted")"
  rm -rf "$home"
  mkdir -p "$MOONLIGHT_HOME/jdk"
  mv "$extracted" "$home"
  link_jdk_current "$home"

  if is_macos; then
    xattr -dr com.apple.quarantine "$home" 2>/dev/null || true
  fi

  java_home_ok "$home" || die "Java install failed."
  persist_java_home "$home"
  if is_windows; then
    write_windows_launcher "$HOME/.local/bin/moonlight.cmd"
  fi
  done_log "Java ${REQUIRED_JAVA_MAJOR} installed at $home"
}

ensure_java() {
  local home bin
  if home="$(find_java_home)"; then
    activate_java "$home"
    bin="$(java_executable "$JAVA_HOME")"
    log "Using Java $(java_major "$bin") ($JAVA_HOME)"
    return 0
  fi

  warn "Java ${REQUIRED_JAVA_MAJOR}+ was not found."
  install_java
  home="$(find_java_home)" || die "Java ${REQUIRED_JAVA_MAJOR} is still missing after install."
  activate_java "$home"
  bin="$(java_executable "$JAVA_HOME")"
  log "Using Java $(java_major "$bin") ($JAVA_HOME)"
}

cmd_setup() {
  require_cmd curl
  require_cmd git
  ensure_java
  if is_windows; then
    write_windows_launcher "$HOME/.local/bin/moonlight.cmd"
  fi
  if command -v psql >/dev/null 2>&1; then
    done_log "PostgreSQL client found."
  elif command -v brew >/dev/null 2>&1; then
    warn "psql not found. Install a client with: brew install libpq && brew link --force libpq"
  elif is_windows; then
    warn "psql not found. Install PostgreSQL, or add its bin directory to PATH."
  else
    warn "psql not found. Install PostgreSQL to create databases from the CLI."
  fi
  done_log "Environment is ready (Java ${REQUIRED_JAVA_MAJOR}+)."
}

#######################################
# Database
#######################################

prompt_db_values() {
  local default_name="${1:-app}"
  local default_user="${2:-postgres}"
  local name user pass

  echo -e "\n${BOLD}📦 Database Configuration${RESET}"
  while true; do
    echo -ne "  ${BLUE}➜${RESET} Database Name [$default_name]: "
    read -r name
    name="${name:-$default_name}"
    [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && break
    warn "  Invalid database name. Use alphanumeric/underscores only."
  done

  echo -ne "  ${BLUE}➜${RESET} Database Username [$default_user]: "
  read -r user
  user="${user:-$default_user}"

  echo -ne "  ${BLUE}➜${RESET} Database Password (hidden): "
  read -rs pass
  echo -e "\n"

  DB_NAME="$name"
  DB_USER="$user"
  DB_PASS="$pass"
}

write_db_props() {
  local file="$1"
  local name="$2"
  local user="$3"
  local pass="$4"
  local url="jdbc:postgresql://localhost:5432/${name}"
  local shared="src/main/resources/application.properties"
  set_prop "$file" "spring.datasource.url" "$url"
  set_prop "$file" "spring.datasource.username" "$user"
  set_prop "$file" "spring.datasource.password" "$pass"
  set_prop "$file" "spring.datasource.driver-class-name" "org.postgresql.Driver"
  # Spring Boot 4 can bind DataSource before profile files load. Keep defaults here too.
  if [[ -f "$shared" && "$file" != "$shared" ]]; then
    set_prop "$shared" "spring.datasource.url" "$url"
    set_prop "$shared" "spring.datasource.username" "$user"
    set_prop "$shared" "spring.datasource.password" "$pass"
    set_prop "$shared" "spring.datasource.driver-class-name" "org.postgresql.Driver"
  fi
}

jdbc_host() {
  local url="$1"
  local rest hostport
  rest="${url#*://}"
  hostport="${rest%%/*}"
  echo "${hostport%%:*}"
}

jdbc_db() {
  local url="$1"
  local rest path
  rest="${url#*://}"
  path="${rest#*/}"
  echo "${path%%[?]*}"
}

postgres_reachable() {
  local host="$1"
  local user="$2"
  local pass="$3"
  PGCONNECT_TIMEOUT=5 PGPASSWORD="$pass" \
    psql -h "$host" -U "$user" -d postgres -c '\q' >/dev/null 2>&1
}

db_exists() {
  local host="$1"
  local user="$2"
  local pass="$3"
  local name="$4"
  PGCONNECT_TIMEOUT=5 PGPASSWORD="$pass" \
    psql -h "$host" -U "$user" -d postgres -tAc \
    "SELECT 1 FROM pg_database WHERE datname='${name}'" 2>/dev/null | grep -q 1
}

create_database() {
  local host="$1"
  local user="$2"
  local pass="$3"
  local name="$4"

  if ! command -v psql >/dev/null 2>&1; then
    warn "psql not found. Create database '$name' manually, then re-run."
    return 0
  fi

  if ! postgres_reachable "$host" "$user" "$pass"; then
    warn "PostgreSQL is not reachable at ${host}. Start it, then re-run if the server cannot connect."
    return 0
  fi

  if db_exists "$host" "$user" "$pass" "$name"; then
    log "Database '$name' already exists."
    return 0
  fi

  log "Creating database '$name'..."
  if PGCONNECT_TIMEOUT=5 PGPASSWORD="$pass" \
      psql -h "$host" -U "$user" -d postgres -v ON_ERROR_STOP=1 \
      -c "CREATE DATABASE ${name};" >/dev/null; then
    done_log "Database '$name' created."
  else
    warn "Database creation failed. You may need to create '$name' manually."
  fi
  return 0
}

ensure_db_for_env() {
  local env="$1"
  local props url user pass name host

  props="$(props_for_env "$env")"
  if [[ ! -f "$props" ]]; then
    warn "No $props — writing one from prompts."
    prompt_db_values "$(basename "$(pwd)")" "postgres"
    write_db_props "$props" "$DB_NAME" "$DB_USER" "$DB_PASS"
    create_database "localhost" "$DB_USER" "$DB_PASS" "$DB_NAME"
    return 0
  fi

  url="$(get_prop "$props" "spring.datasource.url" || true)"
  user="$(get_prop "$props" "spring.datasource.username" || true)"
  pass="$(get_prop "$props" "spring.datasource.password" || true)"

  if [[ -z "$url" ]] || has_placeholder "$url" || has_placeholder "$user" || has_placeholder "$pass"; then
    prompt_db_values "$(basename "$(pwd)")" "${user:-postgres}"
    write_db_props "$props" "$DB_NAME" "$DB_USER" "$DB_PASS"
    url="$(get_prop "$props" "spring.datasource.url")"
    user="$DB_USER"
    pass="$DB_PASS"
  fi

  name="$(jdbc_db "$url")"
  host="$(jdbc_host "$url")"
  [[ -n "$name" ]] || die "Could not read database name from $props"
  [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || die "Invalid database name in $props: $name"
  create_database "${host:-localhost}" "${user:-postgres}" "${pass:-}" "$name"
}

#######################################
# Run server
#######################################

run_server() {
  local env="$1"
  local runner

  if [[ -x ./mvnw ]]; then
    runner=(./mvnw)
  elif command -v mvn >/dev/null 2>&1; then
    runner=(mvn)
  else
    die "Maven not found. The starter kit should include ./mvnw."
  fi

  log "Starting server with profile ${BOLD}${env}${RESET}..."
  exec "${runner[@]}" spring-boot:run "-Dspring-boot.run.profiles=${env}"
}

cmd_run() {
  local env
  is_moonlight_app || die "Not a Moonlight app root. Run this from the project directory, or use: moonlight new <name>"
  ensure_java
  env="$(resolve_env "${1:-}")"
  if [[ ! -f "$(props_for_env "$env")" ]]; then
    warn "Profile '$env' has no application-${env}.properties yet."
  fi
  ensure_db_for_env "$env"
  run_server "$env"
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
  echo -e "  ${BLUE}setup${RESET}                 Detect and install Java ${REQUIRED_JAVA_MAJOR}+"
  echo -e "  ${BLUE}new${RESET} <name> [tag]      Create a new project from the starter kit"
  echo -e "  ${BLUE}run${RESET} [env]             Run the app from the project root (default: spring.profiles.active)"
  echo -e "  ${BLUE}dev${RESET} | ${BLUE}uat${RESET} | ${BLUE}prod${RESET}      Shortcuts for ${BLUE}run${RESET} with that profile"
  echo -e "  ${BLUE}check${RESET}                 Show latest available template tag"
  echo -e "  ${BLUE}update${RESET} | -u           brew upgrade, or refresh a curl install"
  echo -e "  ${BLUE}version${RESET} | -v          Show installed CLI version"
  echo -e "  ${BLUE}uninstall${RESET}             brew uninstall, or remove a curl install"
  echo -e "  ${BLUE}help${RESET} | -h             Show this help message"
  echo -e ""
  echo -e "${BOLD}Examples:${RESET}"
  echo -e "  moonlight new billing-service"
  echo -e "  moonlight run"
  echo -e "  moonlight run uat"
  echo -e "  moonlight prod"
  echo -e ""
  echo -e "With no arguments, ${BOLD}moonlight${RESET} runs the app when you are in a project root."
}

#######################################
# NEW PROJECT
#######################################

cmd_new() {
  local APP_NAME="$ARG2"
  local TAG_VERSION="$ARG3"
  local PACKAGE_NAME LATEST_TAG TARGET_TAG DEV_PROPS IDE_CHOICE

  require_cmd git
  require_cmd curl
  detect_sed
  ensure_java

  [[ -n "$APP_NAME" ]] || die "Usage: moonlight new <project-name> [tag]"
  [[ ! -d "$APP_NAME" ]] || die "Directory '$APP_NAME' already exists."

  PACKAGE_NAME="$(echo "$APP_NAME" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')"

  log "Fetching latest template tag..."
  LATEST_TAG="$(git ls-remote --tags --sort="v:refname" "$TEMPLATE_URL" \
    | grep -v '\^{}' | awk -F/ '{print $3}' | tail -n 1 || true)"

  TARGET_TAG="${TAG_VERSION:-${LATEST_TAG:-main}}"
  log "Using template tag: ${BOLD}$TARGET_TAG${RESET}"

  prompt_db_values "$APP_NAME" "postgres"

  log "Cloning template..."
  git clone --depth 1 --branch "$TARGET_TAG" "$TEMPLATE_URL" "$APP_NAME" \
    || die "Clone failed. Verify GitHub access to moonlight-architecture/java-starter-kit."

  cd "$APP_NAME"

  safe_sed "<artifactId>project</artifactId>" "<artifactId>$APP_NAME</artifactId>" pom.xml
  safe_sed "<name>project</name>" "<name>$APP_NAME</name>" pom.xml

  DEV_PROPS="src/main/resources/application-dev.properties"
  log "Configuring application-dev.properties..."
  write_db_props "$DEV_PROPS" "$DB_NAME" "$DB_USER" "$DB_PASS"

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

  create_database "localhost" "$DB_USER" "$DB_PASS" "$DB_NAME"

  echo -e "\n${BOLD}${GREEN}✨ Project '$APP_NAME' created successfully!${RESET}"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "  ${BLUE}1)${RESET} Open in ${BOLD}IntelliJ IDEA${RESET}"
  echo -e "  ${BLUE}2)${RESET} Open in ${BOLD}VS Code${RESET}"
  echo -e "  ${BLUE}3)${RESET} Run the server now (${BOLD}dev${RESET})"
  echo -e "  ${BLUE}4)${RESET} Stay in Terminal"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "  Later: ${BOLD}cd $APP_NAME && moonlight run [dev|uat|prod]${RESET}"
  echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  echo -ne "  ${BLUE}➜${RESET} Select an option [4]: "
  read -r IDE_CHOICE

  case "${IDE_CHOICE:-4}" in
    1)
      launch_intellij "$(pwd -P)"
      ;;
    2)
      launch_vscode "$(pwd -P)"
      ;;
    3)
      cmd_run "dev"
      ;;
    *)
      log "Happy coding! Navigate to your project: ${BOLD}cd $APP_NAME${RESET}"
      log "Then run: ${BOLD}moonlight run${RESET}  (or ${BOLD}moonlight uat${RESET} / ${BOLD}moonlight prod${RESET})"
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
  if is_brew_install; then
    require_cmd brew
    log "Homebrew install detected. Running brew upgrade..."
    brew_upgrade_moonlight
    done_log "Homebrew package updated."
    return 0
  fi

  require_cmd curl
  local TMP REMOTE_VERSION
  TMP="$(mktemp)"

  log "Checking for updates..."
  curl -fsSL "$RAW_SCRIPT_URL" -o "$TMP" || die "Failed to fetch update."

  REMOTE_VERSION="$(grep '^VERSION=' "$TMP" | cut -d'"' -f2)"

  if [[ "$REMOTE_VERSION" != "$VERSION" ]]; then
    chmod +x "$TMP"
    mv "$TMP" "$0"
    log "Updated to v$REMOTE_VERSION"
    exec "$SHELL" -l
  else
    rm -f "$TMP"
    log "Already on latest version (v$VERSION)."
  fi
}

#######################################
# UNINSTALL
#######################################

cmd_uninstall() {
  local PROFILE CONFIRM RESTART

  if is_brew_install; then
    echo -e "${BOLD}Homebrew install detected.${RESET}"
    echo -e "Remove the CLI with: ${BOLD}brew uninstall moonlight-cli${RESET}"
    echo -e "Remove the tap with:  ${BOLD}brew untap moonlight-architecture/moonlight${RESET}"
    exit 0
  fi

  echo -ne "${YELLOW}➜${RESET} Remove Moonlight CLI? (y/n): "
  read -r CONFIRM
  [[ "$CONFIRM" =~ ^[yY]$ ]] || exit 0

  PROFILE="$(detect_profile)"
  detect_sed

  log "Removing Moonlight files..."

  if [[ -L "$HOME/.local/bin/moonlight" ]] || [[ -f "$HOME/.local/bin/moonlight" ]]; then
    rm -f "$HOME/.local/bin/moonlight"
  fi
  rm -f "$HOME/.local/bin/moonlight.cmd"

  rm -rf "$MOONLIGHT_HOME"

  if [[ -f "$PROFILE" ]]; then
    sed "${SED_INPLACE[@]}" '/Moonlight CLI/d' "$PROFILE"
    sed "${SED_INPLACE[@]}" '/Moonlight Java/d' "$PROFILE"
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

if [[ -z "$COMMAND" ]]; then
  if is_moonlight_app; then
    cmd_run
  else
    cmd_help
  fi
  exit 0
fi

if is_known_env "$COMMAND"; then
  cmd_run "$COMMAND"
  exit 0
fi

case "$COMMAND" in
  setup)      cmd_setup ;;
  new)        cmd_new ;;
  run|start)  cmd_run "$ARG2" ;;
  check)      cmd_check ;;
  update|-u)  cmd_update ;;
  version|-v) echo -e "🌕 Moonlight CLI ${BOLD}v$VERSION${RESET}" ;;
  help|-h)    cmd_help ;;
  uninstall)  cmd_uninstall ;;
  *)          cmd_help ;;
esac
