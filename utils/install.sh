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

# install_on_macos <pkg> [<alt_for_nix>]
#
# Attempts to install a named package on macos
function install_on_macos() {
    local -r pkg="${1:?no package provided to install_on_macos()!}"
    local -r nixAlt="${2:-${pkg}}"

    if [[ "$(has_command "brew")" && "$(brew info "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}brew{{RESET}}"
        brew install "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )

    # TODO if there is a way to validate whether "port" has this package like
    # we're doing for Brew then add that here
    elif has_command "port"; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}port{{RESET}}"
        port install "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    # TODO if there is a way to validate whether "fink" has this package like
    # we're doing for Brew then add that here
    elif has_command "fink"; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}fink{{RESET}}"
        fink install "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    # TODO if there is a way to validate whether "nix-env" has this package like
    # we're doing for Brew then add that here
    elif has_command "nix-env"; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nix{{RESET}}"
        nix-env -iA "nixpkgs.${nixAlt}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )

    else
        logc "- unsure how to install '${pkg}' on this machine's OS and available package managers"
        return 1
    fi

}

function install_on_debian() {
    local -r pkg="${1:?no package provided to install_on_debian()!}"
    local -r nixAlt="${2:-${pkg}}"

    if [[ "$(has_command "nala")" && "$(apt info "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nala{{RESET}}"
        ${SUDO} nala install "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    elif [[ "$(has_command "apt")" && "$(apt info "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}apt{{RESET}}"
        ${SUDO} apt install "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    elif [[ "$(has_command "nix-env")" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nix{{RESET}}"
        nix-env -iA "nixpkgs.${nixAlt}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    else
        logc "- unsure how to install '${pkg}' on this Debian system"
        return 1
    fi
}

# install_on_fedora <pkg> [<alt_for_nix>]
#
# Attempts to install a named package on Fedora/RHEL/CentOS using dnf or yum
function install_on_fedora() {
    local -r pkg="${1:?no package provided to install_on_fedora()!}"
    local -r nixAlt="${2:-${pkg}}"

    if [[ "$(has_command "dnf")" && "$(dnf info "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}dnf{{RESET}}"
        ${SUDO} dnf install -y "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    elif [[ "$(has_command "yum")" && "$(yum info "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}yum{{RESET}}"
        ${SUDO} yum install -y "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    elif [[ "$(has_command "nix-env")" && "$(nix-env -qa "${nixAlt}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nix{{RESET}}"
        nix-env -iA "nixpkgs.${nixAlt}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    else
        logc "- unsure how to install '${pkg}' on this Fedora system"
        return 1
    fi
}

# install_on_alpine <pkg> [<alt_for_nix>]
#
# Attempts to install a named package on Alpine Linux using apk
function install_on_alpine() {
    local -r pkg="${1:?no package provided to install_on_alpine()!}"
    local -r nixAlt="${2:-${pkg}}"

    if [[ "$(has_command "apk")" && "$(apk search -e "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}apk{{RESET}}"
        ${SUDO} apk add "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    elif [[ "$(has_command "nix-env")" && "$(nix-env -qa "${nixAlt}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nix{{RESET}}"
        nix-env -iA "nixpkgs.${nixAlt}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    else
        logc "- unsure how to install '${pkg}' on this Alpine system"
        return 1
    fi
}

# install_on_arch <pkg> [<alt_for_nix>]
#
# Attempts to install a named package on Arch Linux using pacman, with yay/paru fallback for AUR
function install_on_arch() {
    local -r pkg="${1:?no package provided to install_on_arch()!}"
    local -r nixAlt="${2:-${pkg}}"

    # Check if package exists in official repos via pacman
    if [[ "$(has_command "pacman")" && "$(pacman -Si "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}pacman{{RESET}}"
        ${SUDO} pacman -S --noconfirm "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    # Check AUR via yay
    elif [[ "$(has_command "yay")" && "$(yay -Si "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}yay{{RESET}} (AUR)"
        yay -S --noconfirm "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    # Check AUR via paru
    elif [[ "$(has_command "paru")" && "$(paru -Si "${pkg}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}paru{{RESET}} (AUR)"
        paru -S --noconfirm "${pkg}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    # Fallback to nix-env
    elif [[ "$(has_command "nix-env")" && "$(nix-env -qa "${nixAlt}" 2>/dev/null)" ]]; then
        logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nix{{RESET}}"
        nix-env -iA "nixpkgs.${nixAlt}" || ( logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!" && return 1 )
    else
        logc "- unsure how to install '${pkg}' on this Arch system"
        return 1
    fi
}

function install_jq() {
    if is_mac; then
        install_on_macos "jq"
    elif is_debian || is_ubuntu; then
        install_on_debian "jq"
    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}jq{{RESET}}, go to {{GREEN}}https://jqlang.org/download/{{RESET}} and download manually"
        return 1
    fi
}

neovim() {
    nix-env -iA nixpkgs.neovim
}

eza() {
    nix-env -iA nixpkgs.eza
}

dust() {
    nix-env -iA nixpkgs.dust
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

ripgrep() {
    nix-env -iA nixpkgs.ripgrep
}

nvm() {
    # brew is often outdated
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
}

yaza() {
    log ""
}

claude_code() {
    if is_windows; then
        irm https://claude.ai/install.ps1 | iex
    fi

}

install_node() {
    if is_wsl; then
        ${SUDO} apt update && ${SUDO} apt upgrade -y
    elif is_debian; then
        ${SUDO} apt update && ${SUDO} apt upgrade -y && ${SUDO} apt install nodejs
    fi
}

cloudflared() {
    if is_debian; then
        # Add cloudflare gpg key
        ${SUDO} mkdir -p --mode=0755 /usr/share/keyrings
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | ${SUDO} tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

        # Add this repo to your apt repositories
        echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | ${SUDO} tee /etc/apt/sources.list.d/cloudflared.list

        # install cloudflared
        ${SUDO} apt-get update && ${SUDO} apt-get install cloudflared
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

# Only run CLI if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
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
fi
