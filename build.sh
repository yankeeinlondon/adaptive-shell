#!/usr/bin/env bash

# shellcheck source="./utils.sh"
source "${HOME}/.config/sh/utils.sh"

function neovim() {
    if is_debian; then
        cd "${HOME}" > /dev/null|| exit 1
        log ""
        log "Installing ${BOLD}neovim${RESET} Source and compiling latest"
        log ""
        
        log "- installing build dependencies"
        sudo apt install -y ninja-build gettext cmake luajit libluajit-5.1-dev lua-lpeg libunibilium-dev

        # Clone or update the repository
        if [ ! -d "neovim" ]; then
            git clone https://github.com/neovim/neovim
        else
            log "- neovim directory exists, pulling latest changes"
            cd neovim && git pull && cd ..
        fi

        cd neovim > /dev/null || exit

        # Build Neovim
        log "- building neovim"
        make CMAKE_BUILD_TYPE=RelWithDebInfo
        if [ $? -ne 0 ]; then
            log "${RED}${BOLD}✗ Build failed.${RESET}"
            cd - >/dev/null || exit
            return 1
        fi

        # Generate DEB package
        cd build || exit
        log "- packaging neovim into DEB"
        if cpack -G DEB; then
            DEB_FILE="$(get_filename_starting_with "nvim-linux")"
            log "- installing ${DEB_FILE}"
            DEB_DH_MAKESHLIBS_ARG=--ignore-missing-info ${SUDO} dpkg -i --force-overwrite  "${DEB_FILE}"
            log "${GREEN}✓ Successfully installed neovim${RESET}"
        else 
            log "${RED}${BOLD}✗ Failed to generate DEB package.${RESET}"
            cd - >/dev/null || exit
            return 1
        fi

        cd - > /dev/null || exit
    else 
        log "Building neovim from source is automated only for Debian-based systems."
        log "See https://github.com/neovim/neovim for other distributions."
    fi
}

if [[ -z "$1" ]]; then 
    log "no build target specified!"
else
    case "$1" in
        neovim) 
            neovim
            log ""
            ;;
        *) log "the build target ${BOLD}${RED}${1}${RESET} is not recognized!"
    esac;
fi
