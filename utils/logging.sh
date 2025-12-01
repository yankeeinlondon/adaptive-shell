#!/usr/bin/env bash

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

# shellcheck source="../color.sh"
source "${UTILS}/color.sh"

# log
#
# Logs the parameters passed to STDERR.
#
# - always includes a RESET at the end of line
function log() {
    local -r reset="${RESET:-$'\033[0m'}"

    printf "%b\\n" "${*}${reset}" >&2
}
# logc <content> <content> <...>
#
# Logs all passed parameters to STDERR.
#   - unlike `log` function this will run the
#   - parameters through `colorize()` to that
#   the caller doesn't need to bother with the
function logc() {
    local -r reset="${RESET:-$'\033[0m'}"
    local -r colors_missing=$(colors_not_setup)
    local content

    # Check if colors are not set up and set them up if needed
    if [[ "$colors_missing" == "0" ]]; then
        setup_colors
        content="$(colorize "${*}")"
        printf "%b\\n" "${content}${reset}" >&2
        remove_colors
    else
        content="$(colorize "${*}")"
        printf "%b\\n" "${content}${reset}" >&2
    fi
}

# stdout <content>
#
# Logs to **stdout** and will also identify color template codes
# and use them in the output.
function stdout() {
    # Check if colors are not set up and set them up if needed
    if [[ "$colors_missing" == "0" ]]; then
        setup_colors
        content="$(colorize "${*}")"
        printf "%b\\n" "${content}${reset}"
        remove_colors
    else
        content="$(colorize "${*}")"
        printf "%b\\n" "${content}${reset}"
    fi
}

function panic() {
    local -r msg="${1:?no message passed to error()!}"
    local -ri code=$(( "${2:-1}" ))
    local -r fn="${3:-${FUNCNAME[1]}}" || echo "unknown"

    log "\n  [${RED}x${RESET}] ${BOLD}ERROR ${DIM}${RED}$code${RESET}${BOLD} →${RESET} ${msg}"
    log ""
    for i in "${!BASH_SOURCE[@]}"; do
        if ! contains "errors.sh" "${BASH_SOURCE[$i]}"; then
            log "    - ${FUNCNAME[$i]}() ${ITALIC}${DIM}at line${RESET} ${BASH_LINENO[$i-1]} ${ITALIC}${DIM}in${RESET} $(error_path "${BASH_SOURCE[$i]}")"
        fi
    done
    log ""
    exit $code
}

# debug <fn> <msg> <...>
#
# Logs to STDERR when the DEBUG env variable is set
# and not equal to "false".
function debug() {
    if [ -z "${DEBUG:-}" ] || [[ "${DEBUG:-}" == "" ]]; then
        return 0
    else
        if (( $# > 1 )); then
            local fn="$1"

            shift
            local regex=""
            local lower_fn=""
            lower_fn=$(echo "$fn" | tr '[:upper:]' '[:lower:]')
            regex="(.*[^a-z]+|^)$lower_fn($|[^a-z]+.*)"

            if [[ "${DEBUG}" == "true" || "${DEBUG}" =~ $regex ]]; then
                log "       ${GREEN}◦${RESET} ${BOLD}${fn}()${RESET} → ${*}"
            fi
        else
            log "       ${GREEN}DEBUG: ${RESET} → ${*}"
        fi
    fi
}

# error <msg>
#
# sends a formatted error message to STDERR
function error() {
    local -r msg="${1:?no message passed to error()!}"
    local -ri code=$(( "${2:-1}" ))
    local -r fn="${3:-${FUNCNAME[1]}}"

    log "\n  [${RED}x${RESET}] ${BOLD}ERROR ${DIM}${RED}$code${RESET}${BOLD} →${RESET} ${msg}" && return $code
}
