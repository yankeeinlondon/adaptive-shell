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

source "${UTILS}/color.sh";
source "${UTILS}/typeof.sh"
source "${UTILS}/logging.sh"
source "${UTILS}/errors.sh"
source "${UTILS}/text.sh"
source "${UTILS}/filesystem.sh"
source "${UTILS}/os.sh"
source "${UTILS}/functions.sh"
source "${UTILS}/lists.sh"
source "${UTILS}/detection.sh"
source "${UTILS}/link.sh"

# os_initialized()
#
# tests to see if the OS has been initialized yet; this is determined
# by whether a file at `${HOME}/.adaptive-initialized-os` exists.
function os_initialized() {
    if file_exists "${HOME}/.adaptive-initialized-os"; then

        logc "{{DIM}}- OS initialization was already done; add {{BLUE}}--force{{RESET}}{{DIM}} if you want to re-run it{{RESET}}"
    fi
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
        if install_nala; then
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

function init_js() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/detection.sh"
    source "${UTILS}/empty.sh"
    source "${UTILS}/install.sh"
    source "${UTILS}/lang-js.sh"

    logc "\nInitializing a {{BOLD}}{{BLUE}}JS{{RESET}}/{{BOLD}}{{BLUE}}TS{{RESET}} project"
    local -r dir="$(pwd)"

    if ! [[ -f "./package.json" ]]; then
        cd "$(repo_root ".")" > /dev/null || error "problem finding root directory while trying initialize the JS/TS project" 1
        logc "{{DIM}}- moving temporarily to repo root"
    fi

    if has_function "gitignore"; then
        gitignore
    fi

    if [[ -f "./.shellcheckrc" ]]; then
        logc "{{DIM}}- the {{BLUE}}.shellcheckrc{{RESET}}{{DIM}} file already exists"
    else
        cp "${UTILS}/../resources/.shellcheckrc" "."
    fi

    if [[ -f "./.markdownlint.jsonc" ]]; then
        logc "{{DIM}}- the {{BLUE}}.markdownlint.jsonc{{RESET}}{{DIM}} file already exists"
    else
        cp "${UTILS}/../resources/.markdownlint.jsonc" "."
    fi

    if has_dependency_anywhere "typescript"; then
        if [[ -f "./tsconfig.json" ]]; then
            logc "{{DIM}}- repo is a {{BLUE}}Typescript{{RESET}}{{DIM}} project, {{BLUE}}tsconfig.json{{RESET}}{{DIM}} already exists"
        else
            logc "- repo is a {{BLUE}}Typescript{{RESET}} project but is missing {{BLUE}}tsconfig.json{{RESET}}!"
            cp "${ROOT}/resources/tsconfig.json" "." > /dev/null || error "failed to copy tsconfig.json to repo's root!"
        fi
    fi

    ensure_install "npm" "install_npm"

    local -r pkg="$(js_package_manager)"
    if is_empty "pkg"; then
        logc "- unable to determine preferred package manager (will use {{BLUE}}pnpm{{RESET}})"
        ensure_install "pnpm" "install_pnpm"
    else
        logc "- {{GREEN}}${pkg}{{RESET}} will be used as package manager"
        local -a _dev=(
            "vitest"
            "@vitest/ui"
            "@vitest/coverage-v8"
            "bumpp"
            "npm-run-all"
            "typescript"
            "husky"
            "@types/node"
            "typed-tester"
            "jiti"
        )
        if has_dependency "vue" || has_dependency "react"; then
            _dev+=("vite")
        else
            _dev+=("tsdown")
        fi
        packages_not_installed _dev
        if [[ "${#_dev[@]}" -gt 0 ]]; then
            logc "- installing the following dev dependencies: {{BLUE}}${_dev[*]}"
            "${pkg}" install -D "${_dev[@]}" > /dev/null || error "failed to install dev dependencies!"
            logc "- dev dependencies installed"
        fi

        local -a _dep=(
        )
        if [[ -f "./src/index.ts" ]]; then
            _dep+=(
                "inferred-types"
            )
        fi
        if has_dependency "vue"; then
            _dep+=("vueuse")
        fi
        packages_not_installed _dep
        if [[ "${#_dep[@]}" -gt 0 ]]; then
            logc "- installing the following dependencies: {{BLUE}}${_dep[*]}"
            "${pkg}" install "${_dep[@]}" > /dev/null || error "failed to install dependencies!"
        fi

        if [[ "${#_dev[@]}" -eq 0 ]] && [[ "${#_dep[@]}" -eq 0 ]]; then
            logc "{{DIM}}- all npm packages already installed"
        fi

    fi

    local DEP CONFIG
    if DEP="$(get_js_linter_by_dep)"; then
        logc "- the linter {{BOLD}}{{BLUE}}${DEP}{{RESET}} was found in your installed dependencies"
        install_js_linter_config "${DEP}"
        if CONFIG="$(get_js_linter_by_config_file)"; then
            if contains "${CONFIG}" "${DEP}"; then
                logc "- the configuration file -- {{BLUE}}${CONFIG}{{RESET}} -- matches the linter"
            else
                logc "- {{YELLOW}}{{BOLD}}WARN:{{RESET}} the configuration file found is for a different linter than what has been installed as a dependency!"
            fi
        else
            install_js_linter_config "${DEP}"
        fi
    elif CONFIG="$(get_js_linter_by_config_file)"; then
        # Config file but nothing installed
        logc "- we found the linter configuration file {{BLUE}}${CONFIG}{{RESET}} but no linters are installed!"
    fi

    if [[ "${dir}" != "${PWD}" ]]; then
        logc "{{DIM}}- returning back to working directory"
        cd "${dir}" > /dev/null
    fi
}

function init_python() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/detection.sh"
    source "${UTILS}/empty.sh"
    source "${UTILS}/install.sh"
    source "${UTILS}/lang-py.sh"
    logc ""
}

function init_rust() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/detection.sh"
    source "${UTILS}/empty.sh"
    source "${UTILS}/install.sh"
    source "${UTILS}/lang-rs.sh"
    logc ""
}


function main() {
    source "${UTILS}/install.sh"
    source "${UTILS}/os.sh"
    source "${UTILS}/configure.sh"

    local continue
    continue=0

    if looks_like_js_project; then
        init_js
        continue=1
    fi

    if looks_like_python_project; then
        init_python
        continue=1
    fi

    if looks_like_rust_project; then
        init_rust
        continue=1
    fi

    if [[ ${continue} -eq 0 ]] || [[ "$PWD" == "${HOME}" ]]; then
        OS="$(os)"

        logc "\nInitializing packages for {{BOLD}}{{YELLOW}}${OS}{{RESET}}"
        log ""

        case "${OS}" in

            linux)
                if is_debian || is_ubuntu; then
                    install_nala || error "Failed to install Nala!" 1
                fi
                install_git
                install_openssh
                install_gpg
                install_gh
                install_curl
                install_wget
                install_neovim
                install_jq
                install_yq
                install_eza
                install_dust
                install_ripgrep
                install_starship
                install_btop
                install_delta
                install_fzf

                configure_git
                ;;
            macos)

                install_git
                configure_git
                install_openssh
                install_gpg
                install_gh
                install_curl
                install_xh
                install_wget
                install_neovim
                install_jq
                install_jqp
                install_yq
                install_eza
                install_dust
                install_ripgrep
                install_starship
                install_uv
                install_claude_code
                install_gemini_cli
                install_btop
                install_delta
                install_fzf
                install_just

                ;;

            windows)
                install_jq
                install_delta
                install_yq
                ;;

            *)
                logc "- unknown OS {{RED}}{{BOLD}}${OS}{{RESET}}"
                exit 1
                ;;
        esac
    fi

}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "${@}"
fi

