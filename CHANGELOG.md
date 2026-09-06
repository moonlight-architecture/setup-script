# Changelog

## Unreleased

- Homebrew formula uses the SHA-256 of the v0.0.3 tarball. `sha256 :no_check` is rejected by current Homebrew.
- The installer refreshes the tap before `brew install`, and falls back to curl if Homebrew still fails.

## v0.0.3 — 2026-09-07

- Windows support (Git Bash, WSL, and `moonlight.cmd` for Command Prompt / PowerShell)
- Java 25 via winget, Scoop, or Chocolatey when Homebrew is not available
- Open IntelliJ and VS Code with an absolute project path so the IDE does not land in `/tmp`
- Write datasource settings into `application.properties` as well as the active profile file

## v0.0.2 — 2026-09-06

- Detect and install Java 25+ (`moonlight setup`); prefer Homebrew `openjdk@25`
- `moonlight run [env]` from an app root; creating the database no longer exits
- Homebrew formula `moonlight-cli` (the `moonlight` cask is the streaming app)
- MIT license
