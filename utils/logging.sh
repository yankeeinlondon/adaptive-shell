#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__LOGGING_SH_LOADED:-}" ]] && declare -f "log" > /dev/null && return
__LOGGING_SH_LOADED=1

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



# log
#
# Logs the parameters passed to STDERR.
#
# - always includes a RESET at the end of line
function log() {
    local reset="${RESET:-}"
    [[ -z "$reset" ]] && reset=$'\033[0m'

    printf "%b\\n" "${*}${reset}" >&2
}
# logc <content> <content> <...>
#
# Logs all passed parameters to STDERR.
#   - unlike `log` function this will run the
#   - parameters through `colorize()` to that
#   the caller doesn't need to bother with the
function logc() {
    # shellcheck source="../color.sh"
    source "${UTILS}/color.sh"

    local -r colors_missing=$(colors_not_setup)
    local content

    # Check if colors are not set up and set them up if needed
    if [[ "$colors_missing" == "0" ]]; then
        setup_colors
    fi

    local reset="${RESET:-}"
    [[ -z "$reset" ]] && reset=$'\033[0m'

    content="$(colorize "${*}")"
    printf "%b\\n" "${content}${reset}" >&2

    if [[ "$colors_missing" == "0" ]]; then
        remove_colors
    fi
}

# hr()
#
# Creates a horizontal rule across width of the console
function hr() {
    # shellcheck source="./detection.sh"
    source "${UTILS}/detection.sh"
    
}

# stdout <content>
#
# Logs to **stdout** and will also identify color template codes
# and use them in the output.
function stdout() {
    local -r colors_missing=$(colors_not_setup)
    local content

    # shellcheck source="../color.sh"
    source "${UTILS}/color.sh"

    # Check if colors are not set up and set them up if needed
    if [[ "$colors_missing" == "0" ]]; then
        setup_colors
    fi

    local reset="${RESET:-}"
    [[ -z "$reset" ]] && reset=$'\033[0m'

    content="$(colorize "${*}")"
    printf "%b\\n" "${content}${reset}"

    if [[ "$colors_missing" == "0" ]]; then
        remove_colors
    fi
}

function panic() {
    local -r msg="${1:?no message passed to error()!}"
    local -ri code=$(( "${2:-1}" ))
    local -r fn="${3:-${FUNCNAME[1]}}" || echo "unknown"

    # shellcheck source="../color.sh"
    source "${UTILS}/color.sh"

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
                logc "       {{GREEN}}◦{{RESET}} {{BOLD}}${fn}(){{RESET}} → ${*}"
            fi
        else
            logc "       {{GREEN}}DEBUG: {{RESET}} → ${*}"
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

    # shellcheck source="../color.sh"
    source "${UTILS}/color.sh"

    logc "\n  [{{RED}}x{{RESET}}] {{BOLD}}ERROR {{DIM}}{{RED}}${code}{{RESET}}{{BOLD}} →{{RESET}} ${msg}" && return $code
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
