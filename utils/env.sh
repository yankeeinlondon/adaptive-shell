#!/usr/bin/env bash

# Source guard - prevents re-execution when sourced multiple times
[[ -n "${__ENV_SH_LOADED:-}" ]] && return
__ENV_SH_LOADED=1

# append_to_path <path>
#
# Appends the path passed in to the PATH env variable
# and re-exports PATH
function append_to_path() {
    local -r new="${1:?No path passed into append_to_path()!}"
    local -r current="${PATH:-}"
    local -r newPath="${current};${new}"

    export PATH="${newPath}"
    echo "${newPath}"
}

# has_path()
#
# checks whether the passed in path already exists in $PATH
# variable
function has_path() {
    local -r find="${1:?no path passed into has_path()!}"

    if contains "${find}" "${PATH:- }"; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
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
