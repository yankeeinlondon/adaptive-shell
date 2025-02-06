#!/usr/bin/env bash

# shellcheck source="./utils.sh"
source "${HOME}/.config/sh/utils.sh"

deno() {
    log ""
}

rust() {
    log ""
}

bun() {
    log "- installing ${BOLD}${BLUE}Bun${RESET}"
    log ""
    curl -fsSL https://bun.sh/install | bash
    log ""
    log "- ${BOLD}${BLUE}Bun${RESET} installed"
    log ""
}

uv() {
    log ""
}

yaza() {
    log ""
}


starship() {
    if is_linux || is_macos; then
        log "- installing ${BOLD}Starship${RESET} prompt"
        log ""
        curl -sS https://starship.rs/install.sh | sh
        log ""
        log "- ${ITALIC}source${RESET} your ${BOLD}${YELLOW}rc${RESET} file to start the prompt"
    else
        log "- please check the website on how to install ${BOLD}Starship${RESET}"
        log "  on your OS."
        log ""
        log "- https://starship.rs/installing/"
        log ""
    fi
}

case "${1}" in

    starship)
        starship
        ;;
    bun)
        bun
        ;;

    *)
        log "- unknown package ${RED}${BOLD}${OS}${RESET} requested to install"
        exit 1
        ;;
esac 
