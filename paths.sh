#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source="./color.sh"
source "${SCRIPT_DIR}/color.sh"
# shellcheck source="./utils.sh"
source "${SCRIPT_DIR}/utils.sh"


# has_path()
#
# checks whether the passed in path already exists in $PATH
# variable
function has_path() {
    local -r find="${1:?no path passed into has_path()!}"

    if contains "${find}" "${PATH:- }"; then
        return 0
    else
        return 1
    fi
}

true="0"
false="1"

# paths_for_env()
#
# Gather's the file paths which should be added to the PATH variable
# during the initialization of the user's shell.
#
# - each path will have a "name", "duplicate", and "path" property
# - the "duplicate" property is a boolean flag indicating whether
#   the 
function paths_for_env() {
    local -a paths=()

    # Each path entry is defined as: name duplicate_flag path
    # This pattern is clean, readable, and compatible with bash 3.x+

    if dir_exists "${HOME}/bin"; then
        paths+=("User Binaries" "$(has_path "${HOME}/bin")" "${HOME}/bin")
    fi

    if dir_exists "${HOME}/.bun"; then
        # shellcheck disable=SC1091
        [ -s "${HOME}/.bun/_bun" ] && source "${HOME}/.bun/_bun" >/dev/null 2>&1

        paths+=("Bun" "$(has_path "${HOME}/bin")" "${HOME}/.bun/bin")
    fi

    if dir_exists "${HOME}/.local/bin"; then
        if has_path "${HOME}/.local/bin"; then
            paths+=(".local binaries" "true" "${HOME}/.local/bin")
        else
            paths+=(".local binaries" "false" "${HOME}/.local/bin")
        fi
    fi

    if has_command "opencode" || dir_exists "${HOME}/.opencode/bin"; then
        if has_path "${HOME}/.opencode/bin"; then
            paths+=("Opencode AI" "true" "${HOME}/.opencode/bin")
        else
            paths+=("Opencode AI" "false" "${HOME}/.opencode/bin")
        fi
    fi

    echo "${paths[@]}"
}


# report_paths()
#
# Reports all paths which should be added to PATH variable during the
# initialization of the user's shell.
function report_paths() {
    setup_colors

    local -a paths=( $(paths_for_env) )

    for ((i = 0; i < ${#paths[@]}; i += 3)); do
        local name="${paths[i]}"
        local dup="${paths[i+1]}"
        local short="${paths[i+2]}"
        log "- the alias ${BOLD}${GREEN}${short}${RESET} ${ITALIC}maps to${RESET} ${BLUE}${name}${RESET}"
    done
}

# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_paths
fi
