#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__WEZTERM_SH_LOADED:-}" ]] && return
__WEZTERM_SH_LOADED=1

if [ -z "${ADAPTIVE_SHELL}" ] || [[ "${ADAPTIVE_SHELL}" == "" ]]; then
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "${UTILS}" == *"/utils" ]];then
        ROOT="${UTILS%"/utils"}"
    else
        ROOT="$UTILS"
    fi
else
    ROOT="${ADAPTIVE_SHELL}"
    UTILS="${ROOT}/utils"
fi

# shellcheck source="../utils.sh"
source "${ROOT}/utils.sh"

# Wezterm Aliases
function name() {
  local -r name="${1:-$(pwd)}"

  if [[ "${name}" == "$(pwd)" ]]; then
    if file_exists "${PWD}/.name"; then
        local -r dir_name="$(get_file "${PWD}/.name")"
        wezterm cli set-tab-title "${dir_name}"
    elif [[ "${name}" == "${HOME}" ]]; then 
        wezterm cli set-tab-title " 🛖 "
    else
        wezterm cli set-tab-title "${name}"
    fi
  else
    wezterm cli set-tab-title "${name}"
  fi
}

function left() {
    local percent="50"

    if is_numeric "$1"; then
        percent="$1"
        shift
    fi

    local -ra params=("$@")

    debug "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) pane ${WEZTERM_PANE}"
    wezterm cli split-pane --left --percent "${percent}" -- "${params[@]}"
}

function right() {
    local percent="50"

    if is_numeric "$1"; then
        percent="$1"
        shift
    fi

    local -ra params=("$@")

    debug "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) pane ${WEZTERM_PANE}"
    wezterm cli split-pane --right --percent "${percent}" -- "${params[@]}"
}

function below() {
    local percent="50"

    if is_numeric "$1"; then
        percent="$1"
        shift
    fi

    local -ra params=("$@")

    debug "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) pane ${WEZTERM_PANE}"
    wezterm cli split-pane --bottom --percent "${percent}" -- "${params[@]}"
}

function above()  {
    local percent="50"

    if is_numeric "$1"; then
        percent="$1"
        shift
    fi

    local -ra params=("$@")


    debug "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) pane ${WEZTERM_PANE}"
    wezterm cli split-pane --top --percent "${percent}" -- "${params[@]}"
}

# CLI invocation handler - allows running script directly with a function name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set up paths for sourcing dependencies
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${UTILS%"/utils"}"

    cmd="${1:-}"
    shift 2>/dev/null || true

    if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
        script_name="$(basename "${BASH_SOURCE[0]}")"
        echo "Usage: $script_name <function> [args...]"
        echo ""
        echo "Available functions:"
        # List all functions that don't start with _
        declare -F | awk '{print $3}' | grep -v '^_' | sort | sed 's/^/  /'
        exit 0
    fi

    # Check if function exists and call it
    if declare -f "$cmd" > /dev/null 2>&1; then
        "$cmd" "$@"
    else
        echo "Error: Unknown function '$cmd'" >&2
        echo "Run '$(basename "${BASH_SOURCE[0]}") --help' for available functions" >&2
        exit 1
    fi
fi

