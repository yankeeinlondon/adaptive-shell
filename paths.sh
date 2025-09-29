#!/usr/bin/env bash

# Only enable strict mode when script is executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ensure DEBUG is set to avoid unbound variable errors
    DEBUG="${DEBUG:-}"
fi

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
        if has_path "${HOME}/bin" >/dev/null; then
            paths+=("User Binaries" "true" "${HOME}/bin")
        else
            paths+=("User Binaries" "false" "${HOME}/bin")
        fi
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
        local name="${paths[i]}"
        local dup="${paths[i+1]}"
        local path="${paths[i+2]}"
        if [[ "${dup}" == "true" ]]; then
            log "- ${BOLD}${GREEN}${name}${RESET} ${ITALIC}as${RESET} ${BLUE}${path}${RESET}"
        else
            log "- ${BOLD}${GREEN}${name}${RESET} ${ITALIC}as${RESET} ${BLUE}${path}${RESET}"
        fi
    done
}

# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_paths
    remove_colors
fi
