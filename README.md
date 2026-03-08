# Open BMAD IDE Scaffolder

[![Open Source Love](https://badges.frapsoft.com/os/v2/open-source.svg?v=103)](https://github.com/ellerbrock/open-source-badges/)
[![Bash Shell](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

A robust, flexible, and open-source command-line tool designed to instantly initialize the **BMAD-METHOD** environment inside any project.

## ✨ Why `bmad-init`?

Setting up a project with BMAD artifacts and tools takes time. You need to verify prerequisites, run `npx` commands, initialize git, configure `.gitignore` files, and make your first commits.

The `bmad-init` CLI turns this entire tedious process into **a single fast, interactive, and customizable command.**

### 💡 Global vs Local Installation

* **Global CLI Usage**: If you only use BMAD via your system terminal, you don't need to install the framework in every project.
* **IDE Agents (Antigravity, Cursor, etc.)**: For AI Agents working within your IDE to function correctly using local commands (e.g., using the `.` prefix), the BMAD framework **must be installed physically inside each workspace/project**.

This Scaffolder is specifically designed to make this per-project local installation effortless for your AI-driven development flow.

---

## 🚀 Installation

Installing the CLI is extremely fast and safe. Simply clone this repository and run the installer script:

```bash
git clone https://github.com/idirnaitali/open-bmad-ide-scaffolder.git
cd open-bmad-ide-scaffolder
chmod +x install.sh
./install.sh
```

> **Note:** The installer will attempt to place the command dynamically in `~/.local/bin` to avoid requiring `sudo`. If this fails or the folder isn't in your `PATH`, it will fall back to using `sudo` to install globally in `/usr/local/bin/`.

---

## 🛠️ Usage

Navigate to any new or existing project where you want to initialize the BMAD environment, and run the command:

### 1. Interactive Mode (Default)

Simply type the command on its own. It will prompt you with choices (falling back to your global defaults) to tailor the installation perfectly for the current project:

```bash
cd /path/to/your/project
bmad-init
```

### 2. Fast-Track Mode (CLI Arguments)

If you know exactly what you want and don't want to answer prompts, `bmad-init` accepts flags to override the behavior instantly:

```bash
# Skip all prompts and just use default settings
bmad-init --yes

# Specify tools and disable git-init automatically
bmad-init --tools roo-cline,cursor --no-git --yes
```

#### Available Options

| Flag | Description |
| ---- | ----------- |
| `-y, --yes` | Skip all prompts and execute directly using defaults. |
| `-t, --tools <tools>` | Comma-separated list of tools to install (e.g. `antigravity`). |
| `--no-git` | Skip Git repository initialization completely. |
| `--no-ignore` | Do not add the newly generated BMAD folders to `.gitignore`. |
| `-h, --help` | Display the helpful manual. |

---

## ⚙️ Global Configuration

You can change what defaults `bmad-init` proposes whenever you use it by tweaking your global config. Use the `config set` subcommand:

```bash
bmad-init config set tools roo-cline
bmad-init config set auto-git Y
bmad-init config set auto-ignore N
```

*(Configurations are saved safely in `~/.bmad-init-rc`).*

---

## 🗑️ Uninstallation

If you wish to remove the tool and its configuration from your machine completely, run:

```bash
./uninstall.sh
```

---

## � Testing

To guarantee that the CLI tools are fully functional and safe across various environments without actually installing anything or performing actual API calls, a test environment script is provided.

Run the test suite safely from the root:

```bash
./test.sh
```

*(This uses `mktemp` to sandbox operations and mocks NPX downloads to test behavior independently).*

---

## �🤝 Contributing

This CLI is fully open source. Feel free to submit an issue, propose new flags, or make a Pull Request!
