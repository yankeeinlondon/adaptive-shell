#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/color.sh"
source "${SCRIPT_DIR}/utils.sh"

function aliases_for_env() {
    local -a aliases=()

    if has_command "kubectl"; then
        aliases+=(
            [name]: "kubectl"
            [short]: "k"
        )
    fi

    if has_command "nvim"; then
        aliases+=(
            [name]: "nvim"
            [short]: "v"
        )
    fi

    if has_command "lazygit"; then
        aliases+=(
            [name]: "lazygit"
            [short]: "lg"
        )
    fi

    if has_command "htop"; then
        aliases+=(
            [name]: "htop"
            [short]: "top"
        )
    fi


    if has_command "python3"; then
        aliases+=(
            [name]: "python3"
            [short]: "python"
        )
    fi


    if has_command "eza"; then
        aliases+=(
            [name]: "eza --icons=always --hyperlink"
            [short]: "ls"
        )
        aliases+=(
            [name]: "eza -lhga --git  --hyperlink --group"
            [short]: "ll"
        )
        aliases+=(
            [name]: "eza -lDga --git  --hyperlink"
            [short]: "ld"
        )
        aliases+=(
            [name]: "eza -lTL 3 --icons=always  --hyperlink"
            [short]: "lt"
        )
    elif has_command "exa"; then
        aliases+=(
            [name]: "exa -a "
            [short]: "ls"
        )
        aliases+=(
            [name]: "exa -lhga --git "
            [short]: "ll"
        )
        aliases+=(
            [name]: "exa -lDga --git "
            [short]: "ld"
        )
        aliases+=(
            [name]: "exa -lTL 3 "
            [short]: "lt"
        )
    fi

    echo "${aliases[@]}"
}

# report_aliases
#
# Reports to screen the aliases which have been setup for the
# the system based on detected features.
function report_aliases() {
    setup_colors
    
    # Consume the flattened numeric array produced by aliases_for_env()
    local -r raw_output="$(aliases_for_env)"

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

        log "- the alias ${BOLD}${GREEN}${short}${RESET} ${ITALIC}maps to${RESET} ${BLUE}${name}${RESET}"
    done <<< "${formatted}"
            
    # remove_colors
}

# report_aliases
