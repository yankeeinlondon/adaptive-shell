#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source="./color.sh"
source "${SCRIPT_DIR}/color.sh"
# shellcheck source="./utils.sh"
source "${SCRIPT_DIR}/utils.sh"

function aliases_for_env() {
    local -a aliases=()

    # Each alias is defined as: name_command short_alias
    # This pattern is clean, readable, and compatible with bash 3.x+

    if has_command "kubectl"; then
        aliases+=(
            "kubectl" "k"
        )
    fi

    if has_command "nvim"; then
        aliases+=(
            "nvim" "v"
        )
    fi

    if has_command "lazygit"; then
        aliases+=(
            "lazygit" "lg"
        )
    fi

    if has_command "batcat"; then
        aliases+=(
            "batcat" "cat"
        )
    fi

    if type "bat" &>/dev/null; then
        aliases+=(
            "bat" "cat"
        )
    fi

    if type "nala" &>/dev/null; then
        aliases+=(
            "nala" "apt"
        )
    fi


    if has_command "htop"; then
        aliases+=(
            "htop" "top"
        )
    fi

    if has_command "python3"; then
        aliases+=(
            "python3" "python"
        )
    fi

    if has_command "eza"; then
        aliases+=(
            "eza --icons=always --hyperlink" "ls"
            "eza -lhga --git --hyperlink --group" "ll"
            "eza -lDga --git --hyperlink" "ld"
            "eza -lTL 3 --icons=always --hyperlink" "lt"
        )
    elif has_command "exa"; then
        aliases+=(
            "exa -a " "ls"
            "exa -lhga --git " "ll"
            "exa -lDga --git " "ld"
            "exa -lTL 3 " "lt"
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

    # Process pairs: name, short
    for ((i = 0; i < ${#aliases[@]}; i += 2)); do
        local name="${aliases[i]}"
        local short="${aliases[i+1]}"
        log "- the alias ${BOLD}${GREEN}${short}${RESET} ${ITALIC}maps to${RESET} ${BLUE}${name}${RESET}"
    done

}

# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_aliases
    remove_colors
fi

