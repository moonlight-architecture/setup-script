# Moonlight setup script

CLI for installing Moonlight, provisioning Java 25, and creating or running Java projects from the starter kit.

**Remote:** https://github.com/moonlight-architecture/setup-script

| Repo | Role |
|------|------|
| [java-sdk](https://github.com/moonlight-architecture/java-sdk) | Spring Boot dispatch library (`com.jet.moonlight:jet`) |
| [java-starter-kit](https://github.com/moonlight-architecture/java-starter-kit) | App template cloned by `moonlight new` |
| [setup-script](https://github.com/moonlight-architecture/setup-script) | This CLI (`install.sh`, `moonlight.sh`, Homebrew formula) |

## Install

Homebrew is the standard path (macOS and Linuxbrew). The formula is **`moonlight-cli`** — Homebrew already has a `moonlight` cask (game streaming). The command you run is still `moonlight`.

Homebrew 6+ ignores untrusted taps, so trust the formula before installing:

```bash
brew tap moonlight-architecture/moonlight https://github.com/moonlight-architecture/setup-script
brew trust --formula moonlight-architecture/moonlight/moonlight-cli
brew install --formula moonlight-architecture/moonlight/moonlight-cli
```

That installs `moonlight` into the Homebrew prefix and pulls in `openjdk@25`.

```bash
brew upgrade moonlight-cli
brew uninstall moonlight-cli
```

Do **not** run `brew install moonlight` — that installs the [Moonlight streaming app](https://moonlight-stream.org/) cask.

If you already did that:

```bash
brew uninstall --cask moonlight
```

Without Homebrew:

```bash
curl -fsSL https://raw.githubusercontent.com/moonlight-architecture/setup-script/main/install.sh | bash
```

`install.sh` uses Homebrew when `brew` is on `PATH`, and otherwise writes `~/.moonlight/moonlight.sh` plus a `~/.local/bin/moonlight` symlink.

### Local tap (development)

`brew tap … /path/to/setup-script` **clones git**. Uncommitted files (including `Formula/`) are invisible to Homebrew. Commit first, then tap:

```bash
git add Formula LICENSE README.md install.sh moonlight.sh
git commit -m "Add Homebrew moonlight-cli formula"

brew untap moonlight-architecture/moonlight
brew tap moonlight-architecture/moonlight /path/to/setup-script
brew trust --formula moonlight-architecture/moonlight/moonlight-cli
brew install --formula moonlight-architecture/moonlight/moonlight-cli
```

## Commands

```bash
moonlight setup              # detect / install Java 25+
moonlight new <name> [tag]   # clone java-starter-kit (latest tag, or main)
moonlight run [env]          # from an app root: ensure DB, then start Spring Boot
moonlight dev | uat | prod   # same as run with that profile
moonlight check              # print latest template tag
moonlight update             # brew upgrade moonlight-cli, or refresh a curl install
moonlight version
moonlight uninstall          # brew uninstall moonlight-cli, or remove a curl install
```

With no arguments, `moonlight` starts the app when the current directory is a Moonlight project root. The profile defaults to `spring.profiles.active` in `application.properties` (usually `dev`).

Creating a database does not stop the script — after `CREATE DATABASE` it continues and runs the server.

Examples:

```bash
moonlight new billing-service
cd billing-service
moonlight run
moonlight run uat
moonlight prod
```
