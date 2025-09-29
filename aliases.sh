#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

function aliases_for_env() {
    local -a aliases=()


    if has_command "kubectl"; then
        aliases+=(
            "[name]: kubectl"
            "[short]: k"
        )
    fi

    if has_command "nvim"; then
        aliases+=(
            "[name]: nvim"
            "[short]: v"
        )
    fi

    if has_command "lazygit"; then
        aliases+=(
            "[name]: lazygit"
            "[short]: lg"
        )
    fi

    if has_command "htop"; then
        aliases+=(
            "[name]: htop"
            "[short]: top"
        )
    fi


    if has_command "python3"; then
        aliases+=(
            "[name]: python3"
            "[short]: python"
        )
    fi


    if has_command "eza"; then
        aliases+=(
            "[name]: eza --icons=always --hyperlink"
            "[short]: ls"
        )
        aliases+=(
            "[name]: eza -lhga --git  --hyperlink --group"
            "[short]: ll"
        )
        aliases+=(
            "[name]: eza -lDga --git  --hyperlink"
            "[short]: ld"
        )
        aliases+=(
            "[name]: eza -lTL 3 --icons=always  --hyperlink"
            "[short]: lt"
        )
    elif has_command "exa"; then
        aliases+=(
            "[name]: exa -a "
            "[short]: ls"
        )
        aliases+=(
            "[name]: exa -lhga --git "
            "[short]: ll"
        )
        aliases+=(
            "[name]: exa -lDga --git "
            "[short]: ld"
        )
        aliases+=(
            "[name]: exa -lTL 3 "
            "[short]: lt"
        )
    fi

    printf '%s\n' "${aliases[@]}"
}


function set_aliases() {
    # Read the output from aliases_for_env into an array
    local -a aliases_output
    mapfile -t aliases_output < <(aliases_for_env)
    setup_colors

    # Process pairs of lines as associative array entries
    local i=0
    while [ $i -lt ${#aliases_output[@]} ]; do
        # Create an associative array for this alias pair
        declare -A a
        
        # Process the next two lines if they exist
        if [ $((i+1)) -lt ${#aliases_output[@]} ]; then
            local name_line="${aliases_output[$i]}"
            local short_line="${aliases_output[$((i+1))]}"
            
            # Parse the name line: "[name]: command"
            if [[ "$name_line" =~ \[name\]:\ (.+) ]]; then
                a[name]="${BASH_REMATCH[1]}"
            fi
            
            # Parse the short line: "[short]: alias"
            if [[ "$short_line" =~ \[short\]:\ (.+) ]]; then
                a[short]="${BASH_REMATCH[1]}"
            fi
            
            # Only create alias if we have both values
            if [[ -n "${a[name]}" && -n "${a[short]}" ]]; then
                # Create the actual alias
                alias "${a[short]}=${a[name]}"
                
                # Log the alias mapping
                log "The alias ${BOLD}${GREEN}${a[short]}${RESET} maps to '${a[name]}'"
            fi
            
            # Move to next pair
            i=$((i+2))
        else
            # Incomplete pair, skip
            i=$((i+1))
        fi
        
        # Clear the associative array for next iteration
        unset a
    done

    remove_colors
}

set_aliases
