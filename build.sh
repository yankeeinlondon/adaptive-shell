#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source="./utils.sh"
source "${SCRIPT_DIR}/utils.sh"

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

function rebuild_neovim() {
    setup_colors

    log "${BOLD}Rebuilding Neovim${RESET}"
    log "-----------------"

    if dir_exists "${HOME}/neovim"; then
      cd "${HOME}/neovim" || (echo "Unable to move into neovim directory!" && exit 1)
    else 
      if has_command "git"; then 
        cd "${HOME}"
        git clone https://github.com/neovim/neovim.git
      else 
        log ""
        log "git is not installed and neovim directory is non-existent! Exiting."
        log ""
        exit 1
      fi
    fi

    if is_debian; then
        apt update && apt upgrade -y
        apt install shellcheck ninja-build cmake gettext pkg-config build-essential automake fzf  -y
        log ""
        log "- pulling latest commit"
        git pull
        log ""

        log "- cleaning out prior build"
        log ""
        ${SUDO} make distclean || (log "Error running 'make distclean'!" && exit 1)

        log "- starting new build"

        make CMAKE_BUILD_TYPE=RelWithDebInfo || (log "\nFailed to build!" && exit 1)
        ${SUDO} make install || (log "Failed to make installable!" && exit 1)
    else 
        if is_mac; then 
            log "macOS is detected as operating system"
            log ""
            exit 0
        else 
            log "unknown OS: $(os)"
            exit 0
        fi 
    fi

    log ""
    if file_exists "/usr/local/bin/nvim"; then 
        log "- found pre-existing nvim executable in ${BLUE}/usr/local/bin${RESET}"
        log "- removing old version and establishing a symbolic link to newly build variant"
        log ""
        rm /usr/local/bin/nvim 
        ln -s "${HOME}/neovim/build/bin/nvim" "/usr/local/bin/nvim" || (echo "Failed to create symbolic link!" && exit 1)
        log ""
        log "${BOLD}nvim${RESET} has been updated; you may have to source your .bashrc/.zshrc etc."
        log ""
    else 
        if has_command "nvim"; then 
        log "- ${BOLD}Neovim${RESET} is installed at ${BLUE}$(which nvim)${RESET} but because it is"
        log "  not in ${BLUE}/usr/local/bin${RESET} we will not replace it with the"
        log "  recently built variant."
        log "- the newly built variant can be found at ${BLUE}${HOME}/neovim/build/bin${RESET}"
        log "- if you do wish to override the current executable then be sure to remove it first and"
        log "  then run the following from the terminal:"
        log ""
        log "  ln -s \"${HOME}/neovim/build/bin/nvim\" "
        log ""
        fi 
    fi

    cd "-"
}


