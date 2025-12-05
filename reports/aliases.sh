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

source "${ROOT}/utils.sh"
source "${UTILS}/color.sh"
source "${UTILS}/errors.sh"
allow_errors

function aliases_for_env() {
    local -a aliases=()

    if has_command "kubectl"; then
        aliases+=(
            "k" "kubectl"
        )
    fi

    if has_command "nvim"; then
        aliases+=(
            "v" "nvim"
        )
    fi

    if has_command "lazygit"; then
        aliases+=(
            "lg" "lazygit"
        )
    fi

    if has_command "batcat"; then
        aliases+=(
            "cat" "batcat"
        )
    fi

    if type "bat" &>/dev/null; then
        aliases+=(
            "cat" "bat"
        )
    fi

    if type "nala" &>/dev/null; then
        aliases+=(
            "apt" "nala"
        )
    fi

    if has_command "btop"; then
        aliases+=(
            "top" "btop"
        )
    elif has_command "htop"; then
        aliases+=(
            "top" "htop"
        )
    fi

    if has_command "python3"; then
        aliases+=(
            "python" "python3"
        )
    fi

    if has_command "eza"; then
        aliases+=(
            "ls" "eza --icons=always --hyperlink"
            "la" "eza -a --icons=always --hyperlink"
            "ll" "eza -lhga --git --hyperlink --group"
            "ld" "eza -lDga --git --hyperlink"
            "lt" "eza -lTL 3 --icons=always --hyperlink"
        )
    elif has_command "exa"; then
        aliases+=(
            "ls" "exa --icons"
            "la" "exa --icons -a"
            "ll" "exa -lhga --git"
            "ld" "exa -lDga --git"
            "lt" "exa -lTL 3"
        )
    fi

    local IFS='|'
    local output="${aliases[*]}"

    echo "${output}"
}

# set_aliases
#
# Applies aliases determined by the environment so they're available in the
# current shell session.
function set_aliases() {
    local aliases_output
    aliases_output="$(aliases_for_env)"

    if [[ -z "${aliases_output}" ]]; then
        return 0
    fi

    # Enable word splitting for zsh
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        setopt local_options sh_word_split
    fi

    # Convert pipe-separated string to items
    local short target
    local toggle=0
    local IFS='|'

    for item in ${aliases_output}; do
        if [[ $toggle -eq 0 ]]; then
            short="$item"
            toggle=1
        else
            target="$item"
            toggle=0
            if [[ -n "${short}" && -n "${target}" ]]; then
                builtin alias "${short}=${target}"
            fi
        fi
    done
}

# report_aliases
#
# Reports to screen the aliases which have been setup for the
# the system based on detected features.
function report_aliases() {
    setup_colors

    local aliases_output
    aliases_output=$(aliases_for_env)

    if [[ -z "${aliases_output}" ]]; then
        log "none"
        return 0
    fi

    # Enable word splitting for zsh
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        setopt local_options sh_word_split
    fi

    # Process pipe-separated pairs
    local short name
    local toggle=0
    local IFS='|'

    for item in ${aliases_output}; do
        if [[ $toggle -eq 0 ]]; then
            short="$item"
            toggle=1
        else
            name="$item"
            toggle=0
            log "- the alias ${BOLD}${GREEN}${short}${RESET} ${ITALIC}maps to${RESET} ${BLUE}${name}${RESET}"
        fi
    done
}

# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_aliases
    remove_colors
fi
