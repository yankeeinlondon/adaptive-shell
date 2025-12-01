#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__CLI_SH_LOADED:-}" ]] && return
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
            # Use nameref for pass-by-reference
            local -n ref_arr="$var_name"
            for arg in "${ref_arr[@]}"; do
                if [[ ! "$arg" =~ ^- ]]; then
                    result+=("$arg")
                fi
            done
            # Reassign the filtered array
            ref_arr=("${result[@]}")
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
            # Use nameref for pass-by-reference
            local -n ref_arr="$var_name"
            for arg in "${ref_arr[@]}"; do
                if [[ "$arg" =~ ^- ]]; then
                    result+=("$arg")
                fi
            done
            # Reassign the filtered array
            ref_arr=("${result[@]}")
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
