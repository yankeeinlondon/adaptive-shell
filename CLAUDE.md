# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of shared shell scripts that provide utilities for system configuration, environment setup, and shell enhancements across macOS and Linux (particularly Debian) systems. The scripts are designed to be sourced from `~/.config/sh/`.

## Core Architecture

### Script Dependencies

The scripts follow a hierarchical dependency structure:

- **color.sh**: Base color definitions - no dependencies
- **typeof.sh**: Type checking utilities - no dependencies
- **os.sh**: OS detection - imports color.sh
- **utils.sh**: Core utilities - imports color.sh, os.sh, typeof.sh
- **adaptive.sh**: Main entry point - orchestrates loading of other scripts based on detected environment and is intended to be _sourced_ from a user's `.bashrc`, `.zshrc`, etc.

### Key Modules

- **adaptive.sh**: Main initialization script that sources other modules and sets up completions
- **utils.sh**: Extensive utility functions for file operations, string manipulation, system detection
- **aliases.sh**: Dynamic alias generation based on available commands (kubectl, nvim, lazygit, eza/exa)
- **initialize.sh**: System initialization for Debian systems (package installation, tool setup)
- **proxmox.sh**: Proxmox VE API integration utilities
- **build.sh**: Source compilation scripts (e.g., neovim from source)

## Common Development Commands

```bash
# Source the adaptive configuration
source ~/.config/sh/adaptive.sh

# Run the alias reporter to see configured aliases
./aliases.sh

# Initialize a Debian system with standard tools
./initialize.sh

# Build neovim from source
./build.sh neovim
```

## Code Conventions

### Function Patterns

- Functions use lowercase with underscores: `function_name()`
- Local variables declared with `local -r` for readonly or `local` for mutable
- Error handling via `panic()` for fatal errors, `error()` for recoverable ones
- Debug output via `debug "function_name" "message"` pattern
- Return values: 0 for success/true, 1 for failure/false

### Variable Conventions

- Script directory references: `SCRIPT_DIR="${HOME}/.config/sh"`
- Color variables from color.sh: `${BOLD}`, `${RESET}`, `${RED}`, etc.
- Use `has_command` to check for command availability before use
- Use utility functions like `is_empty`, `not_empty`, `contains`, `starts_with` for string operations

### Shell Compatibility

- Scripts target bash but include compatibility checks for zsh/fish
- Use `get_shell()` to detect current shell
- Shell-specific operations wrapped in conditionals (`is_bash()`, `is_zsh()`, `is_fish()`)
