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
        local name="${paths[i]:-unknown}"
        local dup="${paths[i+1]:-unknown}"
        local path="${paths[i+2]:-unknown}"
        if [[ "${dup}" == "true" ]]; then
            log "- ${BOLD}${GREEN}${name}${RESET} ${ITALIC}as${RESET} ${BLUE}${path}${RESET}"
        else
            log "- ${BOLD}${GREEN}${name}${RESET} ${ITALIC}as${RESET} ${BLUE}${path}${RESET}"
        fi
    done
}

# set_aliases()
#
# Sets up command aliases and PATH variables based on detected tools
# and directories. This function centralizes path-related logic that
# was previously inline in adaptive.sh.
function set_aliases() {
    # Set up PATH variables for common directories
    if dir_exists "${HOME}/.bun"; then
        # shellcheck disable=SC1091
        [ -s "${HOME}/.bun/_bun" ] && (is_zsh && source "${HOME}/.bun/_bun" || true)
        export PATH="${PATH}:${HOME}/.bun/bin"
    fi

    if dir_exists "${HOME}/.local/bin"; then
        export PATH="${PATH}:${HOME}/.local/bin"
    fi

    if dir_exists "${HOME}/bin"; then
        export PATH="${PATH}:${HOME}/bin"
    fi

    # Set up command aliases based on available tools
    if has_command "kubectl"; then
        alias k='kubectl'
    fi

    if has_command "nvim"; then
        alias v='nvim'
    fi

    if has_command "lazygit"; then
        alias lg='lazygit'
    fi

    if has_command "htop"; then
        alias top='htop'
    fi

    if has_command "python3"; then
        alias python='python3'
        alias pip='pip3'
    fi

    # Set up file listing aliases (eza preferred over exa)
    if has_command "eza"; then 
        alias ls='eza --icons=always --hyperlink'
        alias la='eza -a --icons=always --hyperlink'
        alias ll='eza -lhga --git  --hyperlink --group'
        alias ld='eza -lDga --git  --hyperlink'
        alias lt='eza -lTL 3 --icons=always  --hyperlink'
    elif has_command "exa"; then
        alias ls='exa -a '
        alias ll='exa -lhga --git '
        alias ld='exa -lDga --git '
        alias lt='exa -lTL 3 '
    fi

    # Set up cat replacement (batcat preferred over bat)
    if has_command "batcat"; then
        alias cat="batcat"
    elif has_command "bat"; then
        alias cat="bat"
    fi

    # Set up apt replacement if nala is available
    if has_command "nala"; then
        alias apt="nala"
    fi

    # Set up Android SDK environment
    if dir_exists "${HOME}/Library/Android/sdk"; then
        export ANDROID_HOME="${HOME}/Library/Android/sdk"
        # shellcheck disable=SC2155
        export NDK_HOME="${ANDROID_HOME}/nd/$(ls -1 "${ANDROID_HOME}/ndk")"
    fi

    # Handle neovim build logic for older Debian versions
    if is_linux && is_debian && [[ "$(os_version)" != "13" ]]; then
        if ! has_command "nvim"; then
            log "${BOLD}${YELLOW}nvim${RESET} is not installed and this version of Debian OS is"
            log "way behind on neovim versions!"
            log ""
            log "Would you like to build from source?"
            if confirm "build from source"; then
                "${HOME}/.config/sh/build.sh" "neovim"
            else
                log "Ok. Version 13 onward of Debian should be fine"
                log ""
            fi
        fi
    fi
}

# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_paths
    remove_colors
fi
