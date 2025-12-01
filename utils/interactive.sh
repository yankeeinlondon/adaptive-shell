#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__INTERACTIVE_SH_LOADED:-}" ]] && return
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
# Asks the user to confirm yes or no and returns TRUE when they answer yes
function confirm() {
    local -r question="${1:?confirm() missing question}"
    local -r default="${2:-y}"
    local response

    # shellcheck source="./text.sh"
    source "${UTILS}/text.sh"

    # Display prompt with printf to avoid zsh/bash compatibility issues
    if [[ $(lc "$default") == "y" ]]; then
        printf "%s (Y/n) " "$question"
    else
        printf "%s (y/N) " "$question"
    fi

    # Read input without -p (compatible with all shells)
    read -r response

    # Rest of the logic remains the same...
    if [[ $(lc "$default") == "y" ]]; then
        [[ $(lc "$response") =~ ^n(no)?$ ]] && return 1 || return 0
    else
        [[ $(lc "$response") =~ ^y(es)?$ ]] && return 0 || return 1
    fi
}
