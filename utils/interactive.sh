#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__INTERACTIVE_SH_LOADED:-}" ]] && declare -f "confirm" > /dev/null && return
__INTERACTIVE_SH_LOADED=1

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
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

# shellcheck source="./logging.sh"
source "${UTILS}/logging.sh"

# confirm(question, [default])
#
# Asks the user to confirm yes or no and returns TRUE when they answer yes.
#
# When there is no terminal to ask (non-interactive shell, cron, an
# editor capturing the environment) this answers NO without blocking
# rather than waiting forever on a prompt nobody can see.
function confirm() {
    local -r question="${1:?confirm() missing question}"
    local -r default="${2:-y}"
    local response

    # shellcheck source="./text.sh"
    source "${UTILS}/text.sh"

    # The prompt goes to STDERR, never STDOUT. Callers are routinely
    # reached from inside a command substitution -- e.g. `eval "$(tool
    # init bash)"` hitting a wrapper function -- where STDOUT is
    # captured and eval'd. On STDOUT the question is invisible and the
    # shell appears to hang, then "Install now? (Y/n)" gets eval'd as
    # shell code.
    if [[ $(lc "$default") == "y" ]]; then
        printf "%s (Y/n) " "$question" >&2
    else
        printf "%s (y/N) " "$question" >&2
    fi

    # Read input without -p (compatible with all shells). Read stdin
    # first -- that is the terminal during shell startup, and a piped
    # answer when scripted. Only when stdin is closed or at EOF do we
    # reach for the controlling terminal, and if that is unavailable
    # too we answer NO rather than block forever on a question nobody
    # can answer. Never fall through to the default here: a silent
    # "yes" would install software unattended.
    if ! read -r response 2> /dev/null; then
        if ! { [[ -r /dev/tty ]] && read -r response < /dev/tty; } 2> /dev/null; then
            printf "\n" >&2
            log "- no terminal available to answer; assuming ${BOLD}no${RESET}"
            return 1
        fi
    fi

    # Rest of the logic remains the same...
    if [[ $(lc "$default") == "y" ]]; then
        [[ $(lc "$response") =~ ^n(no)?$ ]] && return 1 || return 0
    else
        [[ $(lc "$response") =~ ^y(es)?$ ]] && return 0 || return 1
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
