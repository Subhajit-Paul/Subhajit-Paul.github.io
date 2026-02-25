---
layout: default
title: Linux Tools
description: "Linux development environment setup scripts and tools maintained by Subhajit Paul."
image: "/assets/linux-tools-bg.jpg"
---

I maintain a few scripts to automate the setup of my development environments. These are designed to be run on fresh Linux installations or via Docker.

## Linux Setup Script (`setup.sh`)

This is my comprehensive post-install script for **Debian**, **Arch**, and **Fedora**-based systems. It automates the installation of my entire workflow, including:

- **Shell**: Zsh with Oh My Zsh, Powerlevel10k, and productivity plugins.
- **CLI Tools**: fzf, ripgrep, bat, tmux, zoxide, and btop.
- **Editors**: Neovim (pre-configured with NVChad) and VS Code.
- **Runtimes**: Python (via uv), Node.js (via nvm), Rust, and Java 21.
- **Fonts**: JetBrainsMono Nerd Font and MesloLGS NF.

### Quick Install
```bash
curl -fsSL https://subhajit-paul.github.io/setup.sh | bash
```

---

## Disposable Debian Container (`debian.up`)

A lightweight script to spin up a clean **Debian Trixie** development environment using Docker. It sets up a non-root user with `sudo` access and installs essential build tools (`python3`, `build-essential`, `curl`, `vim`) in seconds.

This is my go-to for testing scripts or compiling code in an isolated "sandbox" environment.

### Quick Run
```bash
curl -fsSL https://subhajit-paul.github.io/debian.up | sh
```

---

*Note: Always review scripts from the internet before running them with sudo or piping them to bash.*
