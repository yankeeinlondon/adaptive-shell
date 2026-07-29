set dotenv-load
set positional-arguments
# set allow-duplicate-recipes
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

bold := '\033[1m'
dim := '\033[2m'
italic := '\033[3m'
reset := '\033[0m'
red := '\033[31m'
green := '\033[32m'
yellow := '\033[33m'
blue := '\033[34m'
magenta := '\033[35m'
cyan := '\033[36m'

default:
    #!/usr/bin/env bash
    set -euo pipefail

    echo
    echo -e "{{ bold }}Adaptive Shell{{ reset }}"
    echo "========================================================"
    echo ""
    just --list | grep -v 'default'
    echo

# run TS test harness over shell scripts
test:
    pnpm test

# commit to git
commit *args="":
    git add . && c compose ~/.claudine/prompts/commit.md -y {{ args }}

# start codex in YOLO mode
codex:
    claudine codex -y

# start claude code in YOLO mode
cc:
    claudine claude -y

# Run `just _colors` if you want to exercise this (it does nothing).
_colors:
    @: {{ bold }} {{ italic }} {{ reset }} {{ red }} {{ green }} {{ yellow }} {{ blue }} {{ magenta }} {{ cyan }} {{ dim }} >/dev/null || true
