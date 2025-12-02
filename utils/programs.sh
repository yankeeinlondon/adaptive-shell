#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__PROGRAMS_SH_LOADED:-}" ]] && return
__PROGRAMS_SH_LOADED=1

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

# editors
#
# Lists out all known editor programs which were
# found in the executable path
function editors() {
    EDITORS=()
    if has_command "nvim"; then
        EDITORS+=("nvim")
    fi
    if has_command "vim"; then
        EDITORS+=("vim")
    fi
    if has_command "vi"; then
        EDITORS+=("vi")
    fi

    if has_command "code"; then
        EDITORS+=("code")
    fi
    if has_command "zed"; then
        EDITORS+=("zed")
    fi
    if has_command "emacs"; then
        EDITORS+=("emacs")
    fi
    if has_command "brackets"; then
        EDITORS+=("brackets")
    fi
    if has_command "subl"; then
        EDITORS+=("subl")
    fi
    if has_command "atom"; then
        EDITORS+=("atom")
    fi
    if has_command "micro"; then
        EDITORS+=("micro")
    fi
    if has_command "nano"; then
        EDITORS+=("nano")
    fi
    if has_command "mate"; then
        EDITORS+=("mate")
    fi
    if has_command "idea"; then
        EDITORS+=("idea")
    fi
    if has_command "webstorm"; then
        EDITORS+=("webstorm")
    fi
    if has_command "rubymine"; then
        EDITORS+=("rubymine")
    fi
    if has_command "pycharm"; then
        EDITORS+=("pycharm")
    fi
    if has_command "goland"; then
        EDITORS+=("goland")
    fi
    if has_command "phpstorm"; then
        EDITORS+=("phpstorm")
    fi
    if has_command "rider"; then
        EDITORS+=("rider")
    fi

    logc "{{BOLD}}Editors:{{RESET}}   ${EDITORS[*]}"
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
