#!/usr/bin/env bash

# Source guard - prevents re-execution when sourced multiple times
[[ -n "${__ERRORS_SH_LOADED:-}" ]] && return
__ERRORS_SH_LOADED=1

# Error Handling Utilities



# error_handler()
#
# Handles error when they are caught
function error_handler() {
    local -r exit_code=$?
    local -r _line_number="${1:-}"
    local -r command="${2:-}"

    # Use color defaults to avoid unbound variable errors
    local -r _red="${RED:-}"
    local -r _reset="${RESET:-}"
    local -r _bold="${BOLD:-}"
    local -r _dim="${DIM:-}"
    local -r _italic="${ITALIC:-}"

    # shellcheck disable=SC2016
    if [[ -n "$command" && "$command" != 'return $code' ]]; then
        printf "%b\\n" "  [${_red}x${_reset}] ${_bold}ERROR ${_dim}${_red}$exit_code${_reset}${_bold} → ${command}${_reset} " >&2
    fi
    printf "\\n" >&2

    if [[ -n ${BASH_SOURCE+_} ]]; then
        local i
        for ((i = 0; i < ${#BASH_SOURCE[@]}; i++)); do
            local source_file="${BASH_SOURCE[$i]:-unknown}"
            # Skip errors.sh itself in stack trace
            if [[ "$source_file" != *"errors.sh"* ]]; then
                printf "%b\\n" "    - ${FUNCNAME[$i]:-unknown}() ${_italic}${_dim}at line${_reset} ${BASH_LINENO[$((i-1))]:-unknown} ${_italic}${_dim}in${_reset} ${source_file}" >&2
            fi
        done
    fi
    printf "\\n" >&2
}


# catch_errors()
#
# Catches all errors found in a script -- including pipeline errors -- and
# sends them to an error handler to report the error.
function catch_errors() {
    set -Eeuo pipefail
    trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

# allow_errors()
#
# Allows for non-zero return-codes to avoid being sent to the error_handler
# and is typically used to temporarily check on an external state from the shell
# where an error might be encountered but which will be handled locally
function allow_errors() {
    set +Eeuo pipefail
    trap - ERR
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
