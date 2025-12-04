#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__CLI_SH_LOADED:-}" ]] && declare -f "cli_json" > /dev/null && return
__CLI_SH_LOADED=1

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

# cli_json() -> boolean
#
# returns true/false based on whether the `--json`
# flag was found in the arguments passed in.
function cli_json() {
    local arg
    for arg in "${@}"; do
        if [[ "$arg" == "--json" ]]; then
            return 0
        fi
    done
    return 1
}

# cli_verbose(params) -> boolean
#
# returns true/false based on whether the `--verbose` or `-v`
# flags were found in the arguments passed in.
function cli_verbose() {
    local arg
    for arg in "${@}"; do
        if [[ "$arg" == "--verbose" ]] || [[ "$arg" == "-v" ]]; then
            return 0
        fi
    done
    return 1
}

# cli_force() -> boolean
#
# returns true/false based on whether the `--force`
# flag was found in the arguments passed in.
function cli_force() {
    local arg
    for arg in "${@}"; do
        if [[ "$arg" == "--force" ]]; then
            return 0
        fi
    done
    return 1
}

# has_cli_switch <args_array_name> <switch>
#
# Returns true/false based on whether the specified switch
# was found in the arguments array passed by reference.
#
# This function takes an array of arguments by reference (not value)
# to efficiently check for the presence of a specific CLI switch.
#
# Example:
#   args=("--verbose" "file.txt" "--force")
#   if has_cli_switch args "--verbose"; then
#       echo "Verbose mode enabled"
#   fi
function has_cli_switch() {
    local var_name="$1"
    local switch="$2"

    # Validate we got both parameters
    if [[ -z "$var_name" ]] || [[ -z "$switch" ]]; then
        return 1
    fi

    # Check if it's a declared array variable (including readonly arrays with -ar)
    # Note: bash uses 'declare -a', zsh uses 'typeset -a'
    if ! declare -p "$var_name" 2>/dev/null | grep -qE '(declare|typeset).*-a'; then
        return 1
    fi

    # Use eval for Bash 3.x compatibility (avoid local -n nameref)
    local arg
    eval 'for arg in "${'"$var_name"'[@]}"; do
        if [[ "$arg" == "'"$switch"'" ]]; then
            return 0
        fi
    done'

    return 1
}

# non_switch_params()
#
# strips out all CLI switch/flags (e.g., '--${string}' or '-${string}')
# from the a set of arguments leaving only the non-switch based params.
#
# - takes either an array of arguments, or
#   a reference to an array of arguments
# - if a reference is passed in then the array
#   will be mutated in place
# - if arguments are passed by value then
#   the updated array will be returned.
function non_switch_params() {
    local -a result=()
    local arg

    # Check if single argument is a variable name (for pass-by-reference)
    if [[ $# -eq 1 ]] && [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        local var_name="$1"
        # Check if it's a declared array variable
        if declare -p "$var_name" 2>/dev/null | grep -q 'declare -a'; then
            # Use eval for Bash 3.x compatibility (avoid local -n nameref)
            eval 'for arg in "${'"$var_name"'[@]}"; do
                if [[ ! "$arg" =~ ^- ]]; then
                    result+=("$arg")
                fi
            done'
            # Reassign the filtered array using eval
            eval "$var_name"'=("${result[@]}")'
            return 0
        fi
    fi

    # Pass-by-value: iterate through all arguments
    for arg in "${@}"; do
        if [[ ! "$arg" =~ ^- ]]; then
            result+=("$arg")
        fi
    done

    # Output newline-separated values
    local item
    for item in "${result[@]}"; do
        printf '%s\n' "$item"
    done
    return 0
}

# switch_params()
#
# Strips out all parameters which are NOT CLI switch/flags
# (e.g., '--${string}' or '-${string}').
#
# - takes either an array of arguments, or
#   a reference to an array of arguments
# - if a reference is passed in then the array
#   will be mutated in place
# - if arguments are passed by value then
#   the updated array will be returned.
function switch_params() {
    local -a result=()
    local arg

    # Check if single argument is a variable name (for pass-by-reference)
    if [[ $# -eq 1 ]] && [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        local var_name="$1"
        # Check if it's a declared array variable
        if declare -p "$var_name" 2>/dev/null | grep -q 'declare -a'; then
            # Use eval for Bash 3.x compatibility (avoid local -n nameref)
            eval 'for arg in "${'"$var_name"'[@]}"; do
                if [[ "$arg" =~ ^- ]]; then
                    result+=("$arg")
                fi
            done'
            # Reassign the filtered array using eval
            eval "$var_name"'=("${result[@]}")'
            return 0
        fi
    fi

    # Pass-by-value: iterate through all arguments
    for arg in "${@}"; do
        if [[ "$arg" =~ ^- ]]; then
            result+=("$arg")
        fi
    done

    # Output newline-separated values
    local item
    for item in "${result[@]}"; do
        printf '%s\n' "$item"
    done
    return 0
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
