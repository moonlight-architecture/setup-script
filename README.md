# Moonlight setup script

CLI for installing Moonlight and creating Java projects from the starter kit.

**Remote:** https://github.com/moonlight-architecture/setup-script

| Repo | Role |
|------|------|
| [java-sdk](https://github.com/moonlight-architecture/java-sdk) | Spring Boot dispatch library (`com.jet.moonlight:jet`) |
| [java-starter-kit](https://github.com/moonlight-architecture/java-starter-kit) | App template cloned by `moonlight new` |
| [setup-script](https://github.com/moonlight-architecture/setup-script) | This CLI (`install.sh`, `moonlight.sh`) |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/moonlight-architecture/setup-script/main/install.sh | bash
```

The installer writes `~/.moonlight/moonlight.sh` and symlinks `~/.local/bin/moonlight`.

## Commands

```bash
moonlight new <name> [tag]   # clone java-starter-kit (latest tag, or main)
moonlight check              # print latest template tag
moonlight update             # refresh this CLI from GitHub
moonlight version
moonlight uninstall
```

Example:

```bash
moonlight new billing-service
```
