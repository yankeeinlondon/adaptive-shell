#!/usr/bin/env bash

# shellcheck source="./color.sh"
source "${HOME}/.config/sh/color.sh"

setup_colors

# shellcheck source="./utils.sh"
source "${HOME}/.config/sh/utils.sh"

# shellcheck source="./prep.sh"
source "${HOME}/.config/sh/prep.sh"

if is_zsh; then
    emulate zsh -R
fi

if type rustup &>/dev/null; then
    RUSTUP=$(add_completion "rustup" "$(rustup completions "$(get_shell)" rustup)")
    CARGO=$(add_completion "cargo" "$(rustup completions "$(get_shell)" cargo)")
    if ! is_zsh; then
        source "${RUSTUP}"
        source "${CARGO}"
    fi
fi

if type uv &>/dev/null; then
    if is_fish; then
        uv generate-shell-completion fish | source
    else 
        UV=$(add_completion "uv" "$(rustup completions "$(get_shell)" rustup)")
        source "$UV"
    fi
fi

if type pm2 &>/dev/null; then
    source "${HOME}/.config/sh/resources/_pm2"
fi

if type brew &>/dev/null; then
    HOMEBREW_PREFIX=$(brew --prefix)
    if is_zsh; then
        fpath+=( "$HOMEBREW_PREFIX/share/zsh/site-functions" )
    elif is_bash; then
        if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
                source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
        else
            for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
                [[ -r "$COMPLETION" ]] && source "$COMPLETION"
            done
        fi
    fi
fi

if is_zsh; then
    if file_exists "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "${HOME}/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        source "${HOME}/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        source "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        source "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    unsetopt beep

    fpath+=( "${HOME}/.completions" )
    autoload -Uz compinit && compinit
    autoload -U add-zsh-hook
fi

if is_pve_host; then
    source "${HOME}/.config/sh/proxmox.sh"
fi



if type aws_completer &>/dev/null; then
    if ! is_zsh; then
        source <"$(aws_completer "$(get_shell)")"
    fi
fi

if ! file_exists "${HOME}/.adaptive-initialized"; then
    OS="$(os)"
    distro="$(distro)"

    log ""
    log "It appears this system hasn't yet been initialized for your OS."
    log "Initialization just ensures that the core utils for your OS are"
    log "installed as a baseline."
    log ""
    if is_linux; then
        log "The detected OS is: ${BOLD}${BRIGHT_BLUE}${OS}${RESET} → ${BOLD}${distro}${RESET}"
    else
        log "The detected OS is: ${BOLD}${BRIGHT_BLUE}${OS}${RESET}"
    fi
    log ""
    if confirm "Would you like to do this now?"; then

        log "Installing"
        touch "${HOME}/.adaptive-initialized"

        bash "${HOME}/.config/initialize.sh"
    else 
        log "Ok bye."
        log "${DIM}- run ${BOLD}${BLUE}initialize${RESET}${DIM} at any time to "

        touch "${HOME}/.adaptive-initialized"
    fi

fi


if not_empty "${WEZTERM_CONFIG_DIR}"; then 
  # shellcheck source="./wezterm.sh"
  source "${HOME}/.config/sh/wezterm.sh"
fi

if type "batcat" &>/dev/null; then
    alias cat="batcat";
fi

if type "bat" &>/dev/null; then
    alias cat="bat";
fi

if type "nala" &>/dev/null; then
    alias apt="nala"
fi

if dir_exists "${HOME}/Library/Android/sdk"; then
    export ANDROID_HOME="${HOME}/Library/Android/sdk"
    # shellcheck disable=SC2155
    export NDK_HOME="${ANDROID_HOME}/nd/$(ls -1 "${ANDROID_HOME}/ndk")"
fi

if is_linux && is_debian && [[ "$(os_version)" != "13"  ]]; then
    if ! has_command "nvim"; then
        log "${BOLD}${YELLOW}nvim${RESET} is not installed and this version of Debian OS is"
        log "way behind on neovim versions!"
        log ""
        log "Would you like to build from source?"
        if confirm "build from source"; then
            "${HOME}/.config/sh/build.sh" "neovim"
        else
            log "Ok. Version 13 onward of Debian should be fine"
            log ""
        fi
    fi
fi

# source user's `.env` in home directory
# if it exists.
if file_exists "${HOME}/.env"; then
    set -a
    source "${HOME}/.env"
    set +a
fi

if has_command "kubectl"; then
    alias k='kubectl'
fi

if has_command "nvim"; then
    alias v='nvim'
fi

if has_command "lazygit"; then
    alias lg='lazygit'
fi

if has_command "htop"; then
  alias top='htop'
fi

if dir_exists "${HOME}/.bun"; then
    [ -s "${HOME}/.bun/_bun" ] && source "${HOME}/.bun/_bun"
    export PATH="${PATH}:${HOME}/.bun"
fi

if dir_exists "${HOME}/.local/bin"; then
    export PATH="${PATH}:${HOME}/.local/bin/"
fi

if dir_exists "${HOME}/bin"; then
    export PATH="${PATH}:${HOME}/bin"
fi

if has_command "python3"; then
    alias python='python3'
    alias pip='pip3'
fi

if has_command "gpg"; then
    TTY="$(tty)"
    export GPG_TTY="$TTY"
fi

if [ -z "${LANG}" ]; then
    export LANG="C.UTF-8"
    export LC_ALL="C.UTF-8"
fi

if has_command "yazi"; then
    function y() {
        export EDITOR="nvim"
        local -r tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd" || exit 1
        fi
        rm -f -- "$tmp"
    }
else
    function y() {
        log ""
        log "the ${BOLD}${BLUE}Yazi${RESET} CLI file explorer is not installed"
        log "> https://yazi-rs.github.io/docs/installation"
        log ""
        }
fi

if has_command "fzf"; then
    export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
    export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --lin-range :500 {}"
fi

if has_command "eza"; then 
    alias ls='eza -a --icons=always'
    alias ll='eza -lhga --git '
    alias ld='eza -lDga --git'
    alias lt='eza -lTL 3 --icons=always'
    export FZF_ALT_C_OPTS="--preview 'eza --tree -color=always {} | head -200'"
elif has_command "exa"; then
    alias ls='exa -a '
    alias ll='exa -lhga --git '
    alias ld='exa -lDga --git'
    alias lt='exa -lTL 3 '
    export FZF_ALT_C_OPTS="--preview 'exa --tree -color=always {} | head -200'"
fi


# use "dust" over base "du" if available
function du() {
  if has_command "dust"; then
    dust -X .git -X node_modules "$*" && log "\nExcluded .git and node_modules directory from results" && log "use 'dust' to not exclude"
  else
    if [ -z "$*" ]; then
        $(which du) "."
    else
        $(which du) "$*"
    fi
    
  fi
}

# history convenience utility
function h () {
	re='^[0-9]+$'
	if [[  $1 =~ $re ]]; then
		log "${BOLD}History${RESET} (${ITALIC}last $1${RESET}):"
	 	history "$1"
	 elif [[ -z "$1" ]]; then
		log "${BOLD}History${RESET} (${ITALIC}all${RESET}):"
	 	history
	 else
	 	log "${BOLD}History${RESET} (filtered by '$1')"
        if has_command "rg"; then
            history | rg "$1"
        else 
            history | grep "$1"
        fi
	fi
}

function initialize() {
    bash "${HOME}/.config/sh/initialize.sh"
}


function vitesse() {
  if [ -z "$1" ]; then
    log "Syntax: ${BOLD}vitesse${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to install to  ${NO_DIM}\n"
    return
  fi

  npx degit antfu/vitesse "$1" --force
}


function vitesse-ext() {
  if [ -z "$1" ]; then
    log "Syntax: ${BOLD}vitesse-ext${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to install to  ${NO_DIM}\n"
    return
  fi

  npx degit antfu/vitesse-webext "$1" --force
}

function gitignore() {
  if [ ! -f "./.gitignore" ]; then
    log "- creating ${BLUE}.gitignore${RESET} file"
    log ""
    cat <<'EOF' > "./.gitignore"
# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
**/trace/*.json
# Runtime data
*.pid
*.seed
*.pid.lock
# Directory for instrumented libs generated by jscoverage/JSCover
lib-cov
# Coverage directory used by tools like istanbul
coverage
# nyc test coverage
.nyc_output
# Grunt intermediate storage (http://gruntjs.com/creating-plugins#storing-task-files)
.grunt
# Bower dependency directory (https://bower.io/)
bower_components
# node-waf configuration
.lock-wscript
# Compiled binary addons (https://nodejs.org/api/addons.html)
build/Release
# Dependency directories
node_modules/
jspm_packages/
# Optional npm cache directory
.npm
# Optional eslint cache
.eslintcache
# Optional REPL history
.node_repl_history
# Output of 'npm pack'
*.tgz
# Yarn Integrity file
.yarn-integrity
# dotenv environment variables file
.env
# next.js build output
.next
# OS X temporary files
.DS_Store
# Transpiled Destinations
**/dist/
**/.presite
frontend/.vite-ssg-dist/**
/functions
# for simple TODOs
/todo.md

# Local Netlify folder
.netlify

.tsbuildinfo
trace/*
.trace/*
EOF
  else
    log "- the ${BLUE}.gitignore${RESET} file already exists, ${ITALIC}skipping${RESET}"
  fi
}

function net() {
    setup_colors
    if [[ "$(os)" == "macos" ]]; then
        ifconfig | grep "inet "
    elif [[ "$(os)" == "linux" ]]; then 
        ip addr show | grep "inet "
    fi
    remove_colors
}

function sys() {
    setup_colors

    if is_linux; then
        OS="${BOLD}${YELLOW}$(os) ${RESET}${BOLD}$(distro)${RESET}"
    else
        OS="${BOLD}${YELLOW}$(os) ${RESET}${BOLD}$(os_version)${RESET}"
    fi

    MEM="$(get_memory)"
    MEM="$(find_replace ".00" "" "${MEM}")"
    ARCH="$(get_arch)"


    EDITORS=()
    if has_command "nvim"; then
        EDITORS+=("nvim")
    fi
    if has_command "vim"; then
        EDITORS+=("vim")
    fi
    if has_command "code"; then
        EDITORS+=("code")
    fi
    if has_command "zed"; then
        EDITORS+=("zed")
    fi
    if has_command "emacs"; then
        EDITORS+=("emacs")
    fi
    if has_command "brackets"; then
        EDITORS+=("brackets")
    fi
    if has_command "subl"; then
        EDITORS+=("subl")
    fi
    if has_command "atom"; then
        EDITORS+=("atom")
    fi
    if has_command "micro"; then
        EDITORS+=("micro")
    fi
    if has_command "nano"; then
        EDITORS+=("nano")
    fi
    if has_command "mate"; then
        EDITORS+=("mate")
    fi
    if has_command "idea"; then
        EDITORS+=("idea")
    fi
    if has_command "webstorm"; then
        EDITORS+=("webstorm")
    fi
    if has_command "rubymine"; then
        EDITORS+=("rubymine")
    fi
    if has_command "pycharm"; then
        EDITORS+=("pycharm")
    fi
    if has_command "goland"; then
        EDITORS+=("goland")
    fi
    if has_command "phpstorm"; then
        EDITORS+=("phpstorm")
    fi
    if has_command "rider"; then
        EDITORS+=("rider")
    fi

    PROG=()
    if has_command "node" || has_command "nodejs"; then
        PROG+=("node")
    fi
    if has_command "bun"; then
        PROG+=("${ITALIC}${DIM}bun${RESET}")
    fi
    if has_command "pnpm"; then
        PROG+=("${ITALIC}${DIM}pnpm${RESET}")
    fi

    if has_command "python" || has_command "python3"; then
        PROG+=("python")
    fi

    if has_command "conda"; then
        PROG+=("${ITALIC}${DIM}conda${RESET}")
    fi

    if has_command "uv"; then
        PROG+=("${ITALIC}${DIM}uv${RESET}")
    fi

    if has_command "perl"; then
        PROG+=("perl")
    fi
    if has_command "rustup"; then
        PROG+=("rust")
    fi
    if has_command "php"; then
        PROG+=("php")
    fi
    if has_command "go"; then
        PROG+=("go")
    fi
    if has_command "lua"; then
        PROG+=("lua")
    fi

    FIRM="$(get_firmware)"

    log ""
    log "${BOLD}${BLUE}$(hostname)${RESET}"
    log "${OS}"
    log "${DIM}---------------------------${RESET}"
    log "${BOLD}Memory:${RESET}    ${MEM} ${DIM}${ITALIC}gb${RESET}"
    log "${BOLD}Arch:${RESET}      ${ARCH}"
    log "${BOLD}Kernel:${RESET}    $(get_kernel_version)"
    if get_cpu_count &>/dev/null; then
        CPU_COUNT="$(get_cpu_count)"
        log "${BOLD}CPU count:${RESET} ${CPU_COUNT}"
    fi

    if get_cpu_family &>/dev/null; then
        CPU="$(get_cpu_family)"
        log "${BOLD}CPU type:${RESET}  ${CPU}"
    fi
    if not_empty "$FIRM"; then
        log "${BOLD}Firmware:${RESET}  ${FIRM}"
    fi
    if is_lxc; then
        log "${BOLD}Container:${RESET} LXC"
    fi
    if is_vm; then
        log "${BOLD}Container:${RESET} VM"
    fi
    if is_docker; then
        log "${BOLD}Container:${RESET} ${BLUE}Docker${RESET}"
    fi
    if get_ssh_connection &>/dev/null; then
        log "${BOLD}SSH:${RESET}       $(get_ssh_connection)"
    fi

    log "${BOLD}Editors:${RESET}   ${EDITORS[*]}"
    log "${BOLD}Lang:${RESET}      ${PROG[*]}"


    if has_command "systemctl"; then
        SYSD=( "$(get_systemd_units "getty" "cron" "postfix" "systemd" "user" "dbus" "pve-container@")" )
        # shellcheck disable=SC2178
        SYSD="$(find_replace "ssh" "${DIM}${ITALIC}ssh${RESET}" "${SYSD[*]}")"
        log "${BOLD}Services:${RESET}  ${SYSD[*]}"
    fi
    if has_command "rc-status"; then
        # Alpine
        SYSD=( "$(get_alpine_services "getty" "cron" "postfix" "user" "dbus")" )
        # shellcheck disable=SC2178
        SYSD="$(find_replace "ssh" "${DIM}${ITALIC}ssh${RESET}" "${SYSD[*]}")"
        log "${BOLD}Services:${RESET}  ${SYSD[*]}"
    fi

    log "${BOLD}Network:${RESET}"
    net 

    STORAGE="$(get_storage)"
    STORAGE="$(find_replace "dev" "${DIM}dev${RESET}" "${STORAGE}")"
    STORAGE="$(find_replace "zfs" "${GREEN}${BOLD}zfs${RESET}" "${STORAGE}")"
    STORAGE="$(find_replace "smb" "${BLUE}${BOLD}smb${RESET}" "${STORAGE}")"
    STORAGE="$(find_replace "cifs" "${BLUE}${BOLD}cifs${RESET}" "${STORAGE}")"
    STORAGE="$(find_replace "nfs" "${BRIGHT_BLUE}${BOLD}nfs${RESET}" "${STORAGE}")"
    STORAGE="$(find_replace "apfs" "${YELLOW}${BOLD}apfs${RESET}" "${STORAGE}")"
    STORAGE="$(find_replace "unknown" "${RED}${BOLD}unknown${RESET}" "${STORAGE}")"
    STORAGE="$(find_replace "Applications" "${DIM}Applications${RESET}" "${STORAGE}")"

    log "${BOLD}Storage:${RESET}"
    log "$(indent "    " "${STORAGE}")"
    
    remove_colors
}

if type "starship" &>/dev/null; then 
    if is_zsh; then
        eval "$(starship init zsh)"
    elif is_bash; then
        eval "$(starship init bash)"
    fi
fi

if type "atuin" &>/dev/null; then
    SHELL="$(get_shell)";
    eval "$(atuin init "${SHELL}" --disable-up-arrow)"
fi

if type "direnv" &>/dev/null; then
    SHELL="$(get_shell)";
    eval "$(direnv hook "${SHELL}")"
fi

remove_colors
