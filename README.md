# Moonlight CLI

Command-line toolkit for installing Moonlight, provisioning Java 25, and creating or running Spring Boot projects from the starter kit.

| Repository | Role |
|------------|------|
| [java-sdk](https://github.com/moonlight-architecture/java-sdk) | Spring Boot dispatch library (`com.jet.moonlight:jet`) |
| [java-starter-kit](https://github.com/moonlight-architecture/java-starter-kit) | Application template used by `moonlight new` |
| [setup-script](https://github.com/moonlight-architecture/setup-script) | This CLI |

**Supported platforms:** macOS, Linux, and Windows (Git Bash or WSL).

## Install

### macOS and Linux (Homebrew)

The formula is `moonlight-cli`. Homebrew already publishes a `moonlight` cask for the [game streaming client](https://moonlight-stream.org/); do not install that by mistake.

```bash
brew tap moonlight-architecture/moonlight https://github.com/moonlight-architecture/setup-script
brew trust --formula moonlight-architecture/moonlight/moonlight-cli
brew install --formula moonlight-architecture/moonlight/moonlight-cli
```

```bash
brew upgrade moonlight-cli
brew uninstall moonlight-cli
```

If `brew install moonlight` already installed the streaming app:

```bash
brew uninstall --cask moonlight
```

### Windows

Install [Git for Windows](https://git-scm.com/download/win), then in **Git Bash**:

```bash
curl -fsSL https://raw.githubusercontent.com/moonlight-architecture/setup-script/main/install.sh | bash
```

The installer writes `~/.moonlight/moonlight.sh`, a `moonlight` command for Git Bash, and `moonlight.cmd` for Command Prompt and PowerShell. Add `%USERPROFILE%\.local\bin` to your user PATH if `moonlight` is not found outside Git Bash.

WSL follows the Linux instructions (Homebrew optional).

### Any Unix shell (no Homebrew)

```bash
curl -fsSL https://raw.githubusercontent.com/moonlight-architecture/setup-script/main/install.sh | bash
```

`moonlight setup` installs Java 25 when it is missing: Homebrew `openjdk@25` on macOS/Linux, winget/Scoop/Chocolatey on Windows when available, otherwise Eclipse Temurin.

## Commands

```bash
moonlight setup              # detect and install Java 25+
moonlight new <name> [tag]   # create a project from java-starter-kit
moonlight run [env]          # from an app root: ensure the database, then start the server
moonlight dev | uat | prod   # same as run with that profile
moonlight check              # print the latest template tag
moonlight update             # brew upgrade, or refresh a curl install
moonlight version
moonlight uninstall
```

With no arguments, `moonlight` starts the application when the current directory is a Moonlight project root. The profile defaults to `spring.profiles.active` (usually `dev`).

Creating a database does not stop the script. After `CREATE DATABASE` it continues and starts the server.

```bash
moonlight new billing-service
cd billing-service
moonlight run
moonlight run uat
```
