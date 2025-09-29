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
# This modern version requires Bash 4.0+ for cleaner array handling
function report_aliases_modern() {
    setup_colors

    # Get the array directly from aliases_for_env using eval
    local raw_output
    raw_output="$(aliases_for_env)"

    if [[ -z "${raw_output}" ]]; then
        log "none"
        remove_colors
        return 0
    fi

    # Convert string to proper array using eval (bash 4.0+ feature)
    local -a alias_array
    eval "alias_array=( ${raw_output} )"

    # Iterate through array in steps of 4 (name_key, name_val, short_key, short_val)
    local i
    for ((i=0; i < ${#alias_array[@]}; i+=4)); do
        # Ensure we have all 4 elements
        if [[ $((i+3)) -lt ${#alias_array[@]} ]]; then
            # local name_key="${alias_array[i]}"
            local name_val="${alias_array[i+1]}"
            # local short_key="${alias_array[i+2]}"
            local short_val="${alias_array[i+3]}"

            log "- the alias ${BOLD}${GREEN}${short_val}${RESET} ${ITALIC}maps to${RESET} ${BLUE}${name_val}${RESET}"
        fi
    done
}


function report_aliases_fallback() {
    setup_colors

    # Get the output from aliases_for_env
    local raw_output
    raw_output="$(aliases_for_env)"

    if [[ -z "${raw_output}" ]]; then
        log "none"
        return 0
    fi

    # Parse using simpler string operations (compatible with bash 3.x)
    local remaining="${raw_output}"

    while [[ "${remaining}" == *"[name]:"* ]]; do
        # Find start of [name]: block
        local after_name="${remaining#*[name]: }"

        # Extract name (everything before next [short]:)
        local name="${after_name%%[short]:*}"
        name="${name% }"  # trim trailing space

        # Move to [short]: section
        local after_short="${after_name#*[short]: }"

        # Extract short value (everything before next [name]: or end)
        local short
        if [[ "${after_short}" == *"[name]:"* ]]; then
            short="${after_short%%[name]:*}"
            remaining="[name]:${after_short#*[name]:}"
        else
            short="${after_short}"
            remaining=""
        fi

        # Clean up short value
        short="${short% }"  # trim trailing space

        # Output if we have both values
        [[ -n "${name}" && -n "${short}" ]] && \
            log "- the alias ${BOLD}${GREEN}${short}${RESET} ${ITALIC}maps to${RESET} ${BLUE}${name}${RESET}"
    done
}

# report_aliases_fallback
#
# Fallback version for older Bash versions (< 4.0)
# Uses more basic string operations and manual array building
function report_aliases() {
    local bash_major_version="${BASH_VERSION%%.*}"

    if [[ "${bash_major_version}" -ge 4 ]]; then
        report_aliases
    else
        report_aliases_fallback
    fi
}
