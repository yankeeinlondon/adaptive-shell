#!/usr/bin/env bash

# Error Handling Utilities



# error_handler()
#
# Handles error when they are caught
function error_handler() {
    local -r exit_code="${?:-1}"
    local -r _line_number="${1:-}"
    local -r command="${2:-}"

    # shellcheck disable=SC2016
    if is_bound command && [[ "$command" != 'return $code' ]]; then
        log "  [${RED}x${RESET}] ${BOLD}ERROR ${DIM}${RED}$exit_code${RESET}${BOLD} → ${command}${RESET} "
    fi
    log ""

    for i in "${!BASH_SOURCE[@]}"; do
        if ! contains "errors.sh" "${BASH_SOURCE[$i]:-unknown}"; then
            log "    - ${FUNCNAME[$i]:-unknown}() ${ITALIC}${DIM}at line${RESET} ${BASH_LINENO[$i-1]:-unknown} ${ITALIC}${DIM}in${RESET} $(error_path "${BASH_SOURCE[$i]:-unknown}")"
        fi
    done
    log ""
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
