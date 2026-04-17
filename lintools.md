---
layout: default
title: Linux Tools
description: "Linux development environment setup scripts and tools maintained by Subhajit Paul."
image: "/assets/linux-tools-bg.jpg"
---

I maintain a collection of scripts to automate common development tasks. All scripts are designed to be run directly via `curl` — no cloning required.

---

## Linux Setup Script (`setup.sh`)

Comprehensive post-install script for **Debian**, **Arch**, and **Fedora**-based systems. Automates the installation of my entire workflow:

- **Shell**: Zsh + Oh My Zsh + Powerlevel10k + productivity plugins
- **CLI Tools**: fzf, ripgrep, bat, tmux, zoxide, btop
- **Editors**: Neovim (NVChad) + VS Code
- **Runtimes**: Python (uv), Node.js (nvm), Rust (optional), Java 21
- **Fonts**: JetBrainsMono Nerd Font, MesloLGS NF

```bash
curl -fsSL https://subhajit-paul.github.io/setup.sh | bash
```

---

## Disposable Containers

Spin up a clean, isolated development shell in seconds. Each container creates a non-root user (`devuser` / `devpass`) with passwordless sudo.

### Debian (`debian.up`)

Debian Trixie with `python3`, `build-essential`, `curl`, `vim`.

```bash
curl -fsSL https://subhajit-paul.github.io/debian.up | sh
```

### Arch Linux (`arch.up`)

Arch Linux with `base-devel`, `python`, `git`, `vim`, `curl`.

```bash
curl -fsSL https://subhajit-paul.github.io/arch.up | sh
```

### Fedora (`fedora.up`)

Fedora with `python3`, `gcc`, `git`, `vim`, `curl` via dnf.

```bash
curl -fsSL https://subhajit-paul.github.io/fedora.up | sh
```

> Requires Docker. Containers are ephemeral (`--rm`) — nothing persists after exit.

---

## Python Project Scaffolding (`pyinit`)

Scaffold a modern Python project in seconds. Creates a `src/` layout, `pyproject.toml` (uv/hatchling), tests, `.gitignore`, `.env.example`, and initialises a git repo. Runs `uv sync` automatically if `uv` is installed.

```bash
# Interactive — prompts for project name
curl -fsSL https://subhajit-paul.github.io/pyinit | bash

# Non-interactive
curl -fsSL https://subhajit-paul.github.io/pyinit | bash -s -- myproject

# Specify Python version
curl -fsSL https://subhajit-paul.github.io/pyinit | bash -s -- myproject 3.12
```

**What gets created:**
```
myproject/
├── src/myproject/__init__.py
├── tests/test_myproject.py
├── pyproject.toml        ← deps, ruff, mypy, pytest config
├── .gitignore
├── .env.example
├── .python-version
└── README.md
```

---

## System Cleanup (`cleanup.sh`)

Cross-distro cache and junk cleaner. Frees space from package manager caches, pip/uv/cargo/npm caches, browser caches, old `/tmp` files, journal logs, and Docker artefacts. Shows disk usage before and after, asks confirmation before destructive steps.

```bash
curl -fsSL https://subhajit-paul.github.io/cleanup.sh | bash
```

**Cleans (with confirmation where needed):**
- `apt` / `pacman` / `dnf` package caches
- `pip`, `uv`, `cargo`, `npm`, `yarn`, `pnpm` caches
- Browser caches (Chrome, Brave, Firefox)
- `/tmp` files older than 3 days
- systemd journal (vacuum to 7 days)
- Docker dangling containers, images, networks

---

## System Report (`sysreport`)

Read-only system health snapshot — no root required for most data. Useful for a quick diagnosis before debugging or after a fresh install.

```bash
curl -fsSL https://subhajit-paul.github.io/sysreport | bash
```

**Covers:**
- OS, kernel, uptime, hostname
- CPU model, core count, 1-second usage sample, load averages, temperature
- RAM and swap usage (with high-usage warnings)
- Disk usage per mount point (flags ≥ 85%)
- Network interfaces and external IP
- Listening TCP ports
- Top processes by CPU and memory
- Failed systemd services
- Recent kernel/system errors (last 24h)
- Docker containers and disk usage

---

## Local AI Stack (`mlstack.up`)

One command to spin up a complete local LLM development environment: **Ollama** (model server) + **Open WebUI** (ChatGPT-like interface), with optional **ChromaDB** for RAG. Automatically enables NVIDIA GPU passthrough when detected. Data persists across restarts in `~/.mlstack/`.

```bash
# Basic — CPU or GPU (auto-detected)
curl -fsSL https://subhajit-paul.github.io/mlstack.up | bash

# Pre-pull a model and start
curl -fsSL https://subhajit-paul.github.io/mlstack.up | bash -s -- --model llama3.2

# Include ChromaDB for RAG workflows
curl -fsSL https://subhajit-paul.github.io/mlstack.up | bash -s -- --model llama3.2 --chroma

# Manage the stack
curl -fsSL https://subhajit-paul.github.io/mlstack.up | bash -s -- --status
curl -fsSL https://subhajit-paul.github.io/mlstack.up | bash -s -- --logs
curl -fsSL https://subhajit-paul.github.io/mlstack.up | bash -s -- --down
```

**Services:** Open WebUI at `:3000` · Ollama API at `:11434` · ChromaDB at `:8001` (optional)

> Requires Docker and Docker Compose.

---

## Git Security Audit (`gitaudit`)

Scans a git repo for accidentally committed secrets, large tracked files, `.gitignore` gaps, and unencrypted key files. Checks both the working tree **and full git history**. Exits non-zero if critical findings are found — useful in CI.

```bash
# Audit current directory
curl -fsSL https://subhajit-paul.github.io/gitaudit | bash

# Audit a specific path
curl -fsSL https://subhajit-paul.github.io/gitaudit | bash -s -- /path/to/repo

# Skip history scan (faster)
curl -fsSL https://subhajit-paul.github.io/gitaudit | bash -s -- --no-history
```

**Detects:** AWS keys · GitHub PATs · OpenAI/Anthropic/HuggingFace tokens · Stripe keys · Slack webhooks · private PEM keys · database URLs with credentials · generic API key assignments

---

## Server Hardening (`serveinit`)

Hardens a fresh VPS in one command: firewall, fail2ban, SSH hardening, automatic security updates, and sysctl network tweaks. Safe — checks for SSH keys before disabling password auth to prevent lockout.

```bash
# Basic hardening
curl -fsSL https://subhajit-paul.github.io/serveinit | bash

# Custom SSH port + create deploy user
curl -fsSL https://subhajit-paul.github.io/serveinit | bash -s -- --user deploy --ssh-port 2222
```

**Applies:** UFW/firewalld · fail2ban (3 failures → 24h ban) · SSH hardening (no root, max 3 auth attempts) · unattended-upgrades / dnf-automatic · sysctl (SYN cookies, no IP forwarding, rp_filter)

> Must run as root. Supports Debian/Ubuntu and Fedora/RHEL.

---

## Dotfiles Deployment (`dotdeploy`)

Deploy dotfiles from any git repo to the current machine using GNU Stow. Backs up existing files before linking. Falls back to manual symlinking if Stow is absent.

```bash
# From GitHub username (clones user/dotfiles)
curl -fsSL https://subhajit-paul.github.io/dotdeploy | bash -s -- Subhajit-Paul

# From a specific repo (user/repo or full URL)
curl -fsSL https://subhajit-paul.github.io/dotdeploy | bash -s -- user/dotfiles

# Preview without making changes
curl -fsSL https://subhajit-paul.github.io/dotdeploy | bash -s -- Subhajit-Paul --dry-run

# Custom target directory
curl -fsSL https://subhajit-paul.github.io/dotdeploy | bash -s -- Subhajit-Paul --dir ~/.config/dotfiles
```

---

## Benchmark (`bench`)

Fast, dependency-free benchmark using only coreutils, `dd`, and `python3`. Scores results against baselines with clear ratings.

```bash
curl -fsSL https://subhajit-paul.github.io/bench | bash

# Skip slow tests
curl -fsSL https://subhajit-paul.github.io/bench | bash -s -- --no-disk
curl -fsSL https://subhajit-paul.github.io/bench | bash -s -- --no-net
```

**Tests:** CPU single-core SHA-256 throughput · CPU multi-core · Memory sequential bandwidth · Disk sequential read/write · DNS + HTTPS latency

---

*Always review scripts from the internet before piping them to bash.*
