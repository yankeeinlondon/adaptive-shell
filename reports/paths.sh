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
source "${ROOT}/color.sh"
# shellcheck source="../utils.sh"
source "${ROOT}/utils.sh"

# has_path()
#
# checks whether the passed in path already exists in $PATH
# variable
function has_path() {
    local -r find="${1:?no path passed into has_path()!}"

    if contains "${find}" "${PATH:- }"; then
        echo "true"
        return 0
    else
        echo "false"
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
    
    # Add real paths
    if dir_exists "${HOME}/bin"; then
        paths+=("User Binaries" "$(has_path "${HOME}/bin")" "${HOME}/bin")
    fi

    if dir_exists "${HOME}/.cargo/bin"; then
        paths+=("Cargo" "$(has_path "${HOME}/.cargo/bin")" "${HOME}/.cargo/bin")
    fi

    if dir_exists "${HOME}/.atuin/bin"; then
        paths+=("Atuin" "$(has_path "${HOME}/.atuin/bin")" "${HOME}/.atuin/bin")
    fi


    if dir_exists "${HOME}/.bun"; then
        if has_path "${HOME}/.bun/bin" >/dev/null; then
            paths+=("Bun" "true" "${HOME}/.bun/bin")
        else
            paths+=("Bun" "false" "${HOME}/.bun/bin")
        fi
    fi


    if dir_exists "${HOME}/.local/bin"; then
        if has_path "${HOME}/.local/bin" >/dev/null; then
            paths+=("Local Binaries" "true" "${HOME}/.local/bin")
        else
            paths+=("Local Binaries" "false" "${HOME}/.local/bin")
        fi
    fi

    if dir_exists "${HOME}/.opencode"; then
        if has_path "${HOME}/.opencode/bin" >/dev/null; then
            paths+=("Opencode AI" "true" "${HOME}/.opencode/bin")
        else
            paths+=("Opencode AI" "false" "${HOME}/.opencode/bin")
        fi
    fi
    
    local IFS='|'
    echo "${paths[*]}"
}


# report_paths()
#
# Reports all paths which should be added to PATH variable during the
# initialization of the user's shell.
function report_paths() {
    setup_colors
    
    local paths_output
    paths_output=$(paths_for_env 2>/dev/null || true)

    if [[ -z "${paths_output}" ]]; then
        log "none"
        return 0
    fi

    # Convert pipe-separated output to array using bash 3.x compatible method
    local IFS='|'
    # shellcheck disable=SC2206
    local -a paths=( ${paths_output} )

    

    for ((i = 0; i < ${#paths[@]}; i += 3)); do
        local name="${paths[i]:-unknown}"
        local dup="${paths[i+1]:-unknown}"
        local path="${paths[i+2]:-unknown}"
        if [[ "${dup}" == "true" ]]; then
            log "- ${BOLD}${GREEN}${name}${RESET} ${ITALIC}as${RESET} ${BLUE}${path}${RESET}"
        else
            log "- ${BOLD}${GREEN}${name}${RESET} ${ITALIC}as${RESET} ${BLUE}${path}${RESET}${YELLOW}*${RESET}"
        fi
    done
}

# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_paths
    remove_colors
fi
