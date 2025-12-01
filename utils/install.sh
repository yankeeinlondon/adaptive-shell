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

# _try_cargo_install <pkg1> [<pkg2>] ...
#
# Attempts to install packages using cargo. Returns 0 on success, 1 on failure.
# Note: cargo install builds from source, which takes longer than pre-built binaries.
function _try_cargo_install() {
    local -r pkg_names=("$@")

    if ! has_command "cargo"; then
        return 1
    fi

    for pkg in "${pkg_names[@]}"; do
        # Check if package exists on crates.io
        if cargo search --limit 1 "${pkg}" 2>/dev/null | grep -q "^${pkg} = "; then
            logc "- building {{GREEN}}${pkg}{{RESET}} from source using {{BOLD}}cargo{{RESET}}"
            cargo install "${pkg}" && return 0
            logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to build {{GREEN}}${pkg}{{RESET}} package!"
            return 1
        else
            logc "- {{BOLD}}cargo{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
        fi
    done

    return 1
}

# _try_nix_install <pkg1> [<pkg2>] ...
#
# Attempts to install packages using nix-env. Returns 0 on success, 1 on failure.
function _try_nix_install() {
    local -r pkg_names=("$@")

    if ! has_command "nix-env"; then
        return 1
    fi

    for pkg in "${pkg_names[@]}"; do
        if nix-env -qa "${pkg}" 2>/dev/null | grep -q .; then
            logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nix{{RESET}}"
            nix-env -iA "nixpkgs.${pkg}" && return 0
            logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
            return 1
        else
            logc "- {{BOLD}}nix{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
        fi
    done

    return 1
}

deno() {
    log ""
}

rust() {
    log ""
}

# install_on_macos [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on macOS. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_macos() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_macos()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try brew with each package name variant
    if has_command "brew"; then
        for pkg in "${pkg_names[@]}"; do
            if brew info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}brew{{RESET}}"
                brew install "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}brew{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try port with each package name variant
    if has_command "port"; then
        for pkg in "${pkg_names[@]}"; do
            if port search --exact "${pkg}" 2>/dev/null | grep -q .; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}port{{RESET}}"
                port install "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}port{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try fink with each package name variant
    if has_command "fink"; then
        for pkg in "${pkg_names[@]}"; do
            if fink list -t "${pkg}" 2>/dev/null | grep -q "^${pkg}"; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}fink{{RESET}}"
                fink install "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}fink{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this macOS system"
    return 1
}

# install_on_debian [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on Debian/Ubuntu. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_debian() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_debian()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try nala (preferred over apt) with each package name variant
    if has_command "nala"; then
        for pkg in "${pkg_names[@]}"; do
            if apt info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nala{{RESET}}"
                ${SUDO} nala install -y "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}nala{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try apt with each package name variant
    if has_command "apt"; then
        for pkg in "${pkg_names[@]}"; do
            if apt info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}apt{{RESET}}"
                ${SUDO} apt install -y "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}apt{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this Debian system"
    return 1
}

# install_on_fedora [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on Fedora/RHEL/CentOS. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_fedora() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_fedora()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try dnf with each package name variant
    if has_command "dnf"; then
        for pkg in "${pkg_names[@]}"; do
            if dnf info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}dnf{{RESET}}"
                ${SUDO} dnf install -y "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}dnf{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try yum with each package name variant
    if has_command "yum"; then
        for pkg in "${pkg_names[@]}"; do
            if yum info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}yum{{RESET}}"
                ${SUDO} yum install -y "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}yum{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this Fedora system"
    return 1
}

# installed <filter>
function installed() {
    # TODO
}


# install_on_alpine [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on Alpine Linux. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_alpine() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_alpine()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try apk with each package name variant
    if has_command "apk"; then
        for pkg in "${pkg_names[@]}"; do
            if apk search -e "${pkg}" 2>/dev/null | grep -q .; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}apk{{RESET}}"
                ${SUDO} apk add "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}apk{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this Alpine system"
    return 1
}

# install_on_arch [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on Arch Linux. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_arch() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_arch()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try pacman (official repos) with each package name variant
    if has_command "pacman"; then
        for pkg in "${pkg_names[@]}"; do
            if pacman -Si "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}pacman{{RESET}}"
                ${SUDO} pacman -S --noconfirm "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}pacman{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try yay (AUR) with each package name variant
    if has_command "yay"; then
        for pkg in "${pkg_names[@]}"; do
            if yay -Si "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}yay{{RESET}} (AUR)"
                yay -S --noconfirm "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}yay{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try paru (AUR) with each package name variant
    if has_command "paru"; then
        for pkg in "${pkg_names[@]}"; do
            if paru -Si "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}paru{{RESET}} (AUR)"
                paru -S --noconfirm "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}paru{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this Arch system"
    return 1
}

function install_jq() {
    if is_mac; then
        install_on_macos "jq"
    elif is_debian || is_ubuntu; then
        install_on_debian "jq"
    elif is_alpine; then
        install_on_alpine "jq"
    elif is_fedora; then
        install_on_fedora "jq"
    elif is_arch; then
        install_on_arch "jq"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}jq{{RESET}}, go to {{GREEN}}https://jqlang.org/download/{{RESET}} and download manually"
        return 1
    fi
}

function install_neovim() {
    logc "\nInstalling {{BOLD}}{{BLUE}}neovim{{RESET}}"
    if is_mac; then
        install_on_macos "neovim"
    elif is_debian || is_ubuntu; then
        install_on_debian "neovim"
    elif is_alpine; then
        install_on_alpine "neovim"
    elif is_fedora; then
        install_on_fedora "neovim"
    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}neovim{{RESET}}, go to {{GREEN}}https://jqlang.org/download/{{RESET}} and download manually"
        return 1
    fi
}

# installs `eza` if it can but if not then it will try `exa`
function install_eza() {
    nix-env -iA nixpkgs.eza
}

dust() {
    nix-env -iA nixpkgs.dust
}


install_bun() {
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
