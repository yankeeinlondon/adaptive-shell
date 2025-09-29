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

    if dir_exists "${HOME}/bin"; then
        paths+=(
            [name]: "User Binaries"
            [duplicate]: "$(has_path "${HOME}/.local/bin")"
            [path]: "${HOME}/bin"
        )
            
    fi

    if dir_exists "${HOME}/.bun"; then
        # shellcheck disable=SC1091
        [ -s "${HOME}/.bun/_bun" ] && source "${HOME}/.bun/_bun"
        
        paths+=(
            [name]: "Bun"
            [duplicate]: "$(has_path "${HOME}/.bun/_bun")"
            [path]: "${HOME}/.bin"
        )
    fi

    if dir_exists "${HOME}/.local/bin"; then
        paths+=(
            [name]: ".local binaries"
            [duplicate]: "$(has_path "${HOME}/.local/bin")"
            [path]: "${HOME}/.local/bin")
    fi

    if has_command "opencode" || has_dir "${HOME}/.opencode/bin"; then
        paths+=(
            [name]: "Opencode AI"
            [duplicate]: "$(has_path "${HOME}/.opencode/bin")"
            [path]: "${HOME}/.opencode/bin"
        )        
    fi

    echo "${paths[@]}"
}

# report_paths()
#
# Reports all paths which should be added to PATH variable during the
# initialization of the user's shell.
function report_paths() {
    setup_colors
    
    # Consume the flattened numeric array produced by aliases_for_env()
    local -r raw_output="$(paths_for_env)"

    if [[ -z "${raw_output}" ]]; then
        log "none"
        remove_colors
        return 0
    fi

    # Break entries onto their own lines to parse each alias grouping safely
    local formatted
    formatted="$(printf '%s\n' "${raw_output}" | sed -e 's/ \[name\]:/\n[name]:/g')"

    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue

        local name_part="${line%% \[short\]: *}"
        local short_part="${line#*\[short\]: }"

        # Skip malformed rows that do not contain both pieces
        if [[ "${short_part}" == "${line}" ]]; then
            continue
        fi

        local name="${name_part#\[name\]: }"
        local short="${short_part}"

        [[ -z "${name}" || -z "${short}" ]] && continue


        log "- ${BOLD}${GREEN}${short}${RESET} ${ITALIC}maps to${RESET} ${BLUE}${name}${RESET}"
    done <<< "${formatted}"
}
