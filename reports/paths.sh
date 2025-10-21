#!/usr/bin/env bash

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

# shellcheck source="../utils/color.sh"
source "${UTILS}/color.sh"
# shellcheck source="../utils/logging.sh"
source "${UTILS}/logging.sh"
# shellcheck source="../utils/color.sh"
source "${UTILS}/color.sh"
# shellcheck source="../utils/env.sh"
source "${UTILS}/env.sh"


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

    if dir_exists "/usr/local/bin"; then
        paths+=("/usr/local" "$(has_path "/usr/local/bin")" "/usr/local/bin")
    fi

    if dir_exists "${HOME}/.cargo/bin"; then
        paths+=("Cargo" "$(has_path "${HOME}/.cargo/bin")" "${HOME}/.cargo/bin")
    fi

    if dir_exists "${HOME}/.atuin/bin"; then
        paths+=("Atuin" "$(has_path "${HOME}/.atuin/bin")" "${HOME}/.atuin/bin")
    fi


    if dir_exists "${HOME}/.local/bin"; then
        paths+=(".local" "$(has_path "${HOME}/.local/bin")" "${HOME}/.local/bin")
    fi


    if dir_exists "${HOME}/.bun/bin"; then
        paths+=("Bun" "$(has_path "${HOME}/.bun/bin")" "${HOME}/.bun/bin")
    fi

    if dir_exists "${HOME}/.opencode/bin"; then
        paths+=("Opencode" "$(has_path "${HOME}/.opencode/bin")" "${HOME}/.opencode/bin")
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

    # Enable word splitting for zsh
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        setopt local_options sh_word_split
    fi

    # Process pipe-separated triplets
    local name dup path
    local count=0
    local IFS='|'

    for item in ${paths_output}; do
        case $count in
            0) name="$item"; count=1 ;;
            1) dup="$item"; count=2 ;;
            2)
                path="$item"
                count=0
                if [[ "${dup}" == "true" ]]; then
                    log "- ${BOLD}${GREEN}${name}${RESET} ${ITALIC}as${RESET} ${BLUE}${path}${RESET}"
                else
                    log "- ${BOLD}${GREEN}${name}${RESET} ${ITALIC}as${RESET} ${BLUE}${path}${RESET}${YELLOW}*${RESET}"
                fi
                ;;
        esac
    done
}

# append_to_path()
#
# Appends detected paths to the PATH environment variable.
# Only adds paths that don't already exist in PATH (based on the duplicate flag).
# Preserves existing PATH entries and appends new paths at the end.
function append_to_path() {
    local paths_output
    paths_output=$(paths_for_env 2>/dev/null || true)

    if [[ -z "${paths_output}" ]]; then
        return 0
    fi

    # Enable word splitting for zsh (save and restore option state)
    local zsh_opts_set=0
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        if [[ ! -o sh_word_split ]]; then
            setopt sh_word_split
            zsh_opts_set=1
        fi
    fi

    # Process pipe-separated triplets: name, is_duplicate, path
    local name dup path
    local count=0
    local IFS='|'

    for item in ${paths_output}; do
        case $count in
            0) name="$item"; count=1 ;;
            1) dup="$item"; count=2 ;;
            2)
                path="$item"
                count=0
                # Only append if not already in PATH (dup != "true")
                if [[ "${dup}" !=  "true" ]] && [[ -n "${path}" ]]; then
                    export PATH="${PATH}:${path}"
                fi
                ;;
        esac
    done

    # Restore zsh option state
    if [[ $zsh_opts_set -eq 1 ]]; then
        unsetopt sh_word_split
    fi
}

# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_paths
    remove_colors
fi
