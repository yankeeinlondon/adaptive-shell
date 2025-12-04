#!/usr/bin/env bash

# Source guard - prevents re-execution when sourced multiple times
[[ -n "${__EMPTY_SH_LOADED:-}" ]] && declare -f "is_empty" > /dev/null && return
__EMPTY_SH_LOADED=1

# not_empty() <test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is NOT empty and 1 when it is.
function not_empty() {
    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "not_empty(${1})" "was empty, returning 1/false"
        return 1
    else
        debug "not_empty(${1})" "was indeed not empty, returning 0/true"
        return 0
    fi
}


# is_empty_string() <test | ref:test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is empty and 1 when it is NOT.
function is_empty_string() {

    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "is_empty(${1})" "was empty, returning 0/true"
        return 0
    else
        debug "is_empty(${1}))" "was NOT empty, returning 1/false"
        return 1
    fi
}


# is_empty() <test | ref:test>
#
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is empty and 1 when it is NOT.
#
# Simplified version that works without typeof/errors dependencies
function is_empty() {
    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        return 0
    else
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
