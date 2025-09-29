#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source="./color.sh"
source "${SCRIPT_DIR}/color.sh"
# shellcheck source="./utils.sh"
source "${SCRIPT_DIR}/utils.sh"

function aliases_for_env() {
    local -a aliases=()

    # Each alias is defined as: short_alias command_to_map_to
    # This pattern is clean, readable, and compatible with bash 3.x+

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


    if has_command "htop"; then
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
    echo "${aliases[*]}"
}

# report_aliases
#
# Reports to screen the aliases which have been setup for the
# the system based on detected features.
function report_aliases() {
    setup_colors

    local -a aliases_output
    aliases_output=$(aliases_for_env)

    if [[ -z "${aliases_output}" ]]; then
        log "none"
        return 0
    fi

    # Convert pipe-separated output to array using bash 3.x compatible method
    local IFS='|'
    # shellcheck disable=SC2206
    local -a aliases=( ${aliases_output} )

    # Process pairs: short_alias, command_to_map_to
    for ((i = 0; i < ${#aliases[@]}; i += 2)); do
        local short="${aliases[i]}"
        local name="${aliases[i+1]}"
        log "- the alias ${BOLD}${GREEN}${short}${RESET} ${ITALIC}maps to${RESET} ${BLUE}${name}${RESET}"
    done

}

# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_aliases
    remove_colors
fi

