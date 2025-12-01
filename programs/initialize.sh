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

# shellcheck source="../color.sh"
source "${ROOT}/color.sh"
# shellcheck source="../utils.sh"
source "${ROOT}/utils.sh"

# os_initialized()
#
# tests to see if the OS has been initialized yet; this is determined
# by whether a file at `${HOME}/.adaptive-initialized-os` exists.
function os_initialized() {
    if file_exists "${HOME}/.adaptive-initialized-os"; then

        logc "{{DIM}}- OS initialization was already done; add {{BLUE}}--force{{RESET}}{{DIM}} if you want to re-run it{{RESET}}"
    fi
}


function get_nala() {
    set -e

    base_url="https://deb.volian.org/volian/pool/main/v/volian-archive/"
    version="0.3.1"

    archive="volian-archive-nala_${version}_all.deb"
    keyring="volian-archive-keyring_${version}_all.deb"

    wget "${base_url}${archive}" -P /tmp
    wget "${base_url}${keyring}" -P /tmp

    echo "sudo is required to install the archives, update apt, and install Nala"

    sudo apt-get install /tmp/${archive} /tmp/${keyring} -y
    sudo apt-get update
    sudo apt-get install nala -y
}

# use_allowed_hosts_alias()
#
# creates a symbol link to `authorized_keys` in the .config directory
# if it exists
function use_allowed_hosts_alias() {
    if file_exists "${HOME}/.config/authorized_keys"; then
        if file_exists "${HOME}/.ssh/authorized_keys"; then
            mv "${HOME}/.ssh/authorized_keys" "${HOME}/.ssh/authorized_keys.old"
        fi
        cp "${HOME}/.config/authorized_keys" "${HOME}/.ssh/authorized_keys"
    fi
}

function source_adaptive() {
    add_to_rc "source ${HOME}/.config/sh"
}

function debian() {
    setup_colors
    if has_command "nala"; then
        log "- ${BOLD}${BLUE}nala${RESET} already installed, skipping"
    else
        if get_nala; then
            log ""
            log "- ${BOLD}${BLUE}nala${RESET} has been installed in favor of apt"
            log ""
        fi
    fi

    log "- installing Debian core packages via Nala"
    log ""

    nala update
    if [[ "$(os_version)" -ge 13 ]]; then
        EZA="eza"
    else
        EZA="exa"
    fi
    nala install curl wget neofetch htop btop iperf3 jq lsof gh bat ripgrep shellcheck lsb-release npm bat exa htop btop fzf ninja-build gettext cmake unzip delta qemu-guest-agent yamllint gpg git xclip "${EZA}" -y

    if has_command "node"; then
        if ! has_command "n"; then
            log "- install the 'n' library from ${BOLD}npm${RESET}"
            log ""
            if npm i -g n; then
                log "- switching node to version 22"

                n 22
            fi
        fi

        if ! has_command "eslint_d"; then
            log "- installing the ${BLUE}${BOLD}eslint_d${RESET} linter"
            npm i -g eslint_d
        fi
    fi

    log ""
    log "- Nala installation complete"

    if ! has_command "nvim"; then
        if [[ "$(os_version)" -ge 13 ]]; then
            log ""
            log "You have a version of debian which is new enough to just"
            log "install ${BLUE}${BOLD}neovim${RESET} from the package manager."
            log ""
            log "Earlier versions effectively required you build from source,"
            log "which is still an option of course."
            log ""
            if  confirm "Install neovim with package manager?"; then
                nala install nvim -y
            else
                if confirm "Build neovim from source?"; then
                    bash "${HOME}/.config/sh/build.sh" "neovim"
                fi
            fi
        else
            log ""
            log "You have a version of Debian below version 13."
            log "This means that the package manager's ${BLUE}${BOLD}neovim${RESET}"
            log "version is VERY old."
            log ""
            if confirm "Build neovim from source?"; then
                bash "${HOME}/.config/sh/build.sh" "neovim"
            fi
        fi
    fi

    # add quemu client if appropriate
    if is_lxc || is_vm; then
        nala install
    fi

    log ""

    # stylua
    if has_command "stylua"; then
        log "- ${BOLD}${BLUE}stylua${RESET} already installed, ${ITALIC}skipping${RESET}"
    else
        if wget https://github.com/JohnnyMorganz/StyLua/releases/download/v2.0.2/stylua-linux-x86_64.zip; then
            unzip stylua-linux-x86.zip
            if mv "stylua-linux-x86.zip" "/usr/local/bin"; then
                log "- installed ${BLUE}${BOLD}stylua${RESET} linter into /usr/local/bin"
                rm stylua-linux-x86_64.zip &>/dev/null
            fi
        fi
    fi

    # Create a private/public key (when not already existing)
    if [[ -f "${HOME}/.ssh/id_rsa" ]]; then
        log "- a ${BOLD}${BLUE}SSH keypair${RESET} ( .ssh/id_rsa, .ssh/id_rsa.pub ) already exists on this machine"
    else
        echo ""
        log "- Provision a private/public ${BOLD}SSH keypair${RESET} for this machine"
        ssh-keygen
        echo ""
    fi
    use_allowed_hosts_alias

    # starship
    if has_command "starship"; then
        log "- ${BOLD}${BLUE}Starship${RESET} prompt already installed"
    else
        bash "${HOME}/.config/sh/install.sh" "starship"
    fi

    # add atuin
    if has_command "atuin"; then
        log "- ${BOLD}${BLUE}atuin${RESET} already installed"
    else
        log "- installing ${BOLD}atuin${RESET} for history search"
        bash -e <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
        log ""
        log "- installed ${BOLD}${BLUE}atuin${RESET}"
        log ""
    fi

    # gpg
    if has_command "gpg"; then
        log "- the ${BOLD}${BLUE}gpg${RESET} utility is installed and you have the following private keys:"
        log ""
        gpg --list-secret-keys --keyid-format=long
        log ""
    fi

    source_adaptive

    log ""
    log "${BOLD}Note:${RESET} you may need to ${ITALIC}source${RESET} your ${BOLD}rc${RESET} file to be fully configured."
    log ""

    remove_colors
}


function main() {
    # shellcheck source="../utils/install.sh"
    source "${UTILS}/install.sh"

    OS="$(os)"

    setup_colors
    log "Initializing packages for ${BOLD}${YELLOW}${OS}${RESET}"
    log ""


    case "${OS}" in

        linux)
            if is_debian; then
                debian
            else
                log "- no initialization yet for the ${BOLD}$(distro)${RESET} distro."
            fi
            ;;
        macos)

            install_neovim
            install_jq
            install_eza
            install_dust
            install_ripgrep
            install_starship
            install_uv
            ;;

        windows)

            log "- no initialization yet for ${BOLD}Windows${RESET}."
            ;;

        *)
            log "- unknown OS ${RED}${BOLD}${OS}${RESET}"
            exit 1
            ;;
    esac


    remove_colors
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "${@}"
fi

