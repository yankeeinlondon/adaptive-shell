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

# shellcheck source="../utils.sh"
source "${ROOT}/utils.sh"

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

cloudflared() {
    if is_debian; then
        # Add cloudflare gpg key
        sudo mkdir -p --mode=0755 /usr/share/keyrings
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

        # Add this repo to your apt repositories
        echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

        # install cloudflared
        sudo apt-get update && sudo apt-get install cloudflared
    fi
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
