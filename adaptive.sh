#!/usr/bin/env bash

# shellcheck disable=SC2155
export ADAPTIVE_SHELL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="${ADAPTIVE_SHELL}"
UTILS="${ROOT}/utils"
REPORTS="${ROOT}/reports"

# Get the directory of the current script
CONFIG_LOCATION="${HOME}/.config/sh"
COMPLETIONS="${HOME}/.completions"

# shellcheck source="./color.sh"
export AD_COLOR="${ROOT}/color.sh"
# shellcheck source="./utils.sh"
export AD_UTILS="${UTILS}/utils.sh"


# shellcheck source="./color.sh"
source "${ROOT}/color.sh"
setup_colors

# shellcheck source="./utils.sh"
source "${ROOT}/utils.sh"

# shellcheck source="./reports/paths.sh"
source "${REPORTS}/paths.sh"
# shellcheck source="./reports/aliases.sh"
source "${REPORTS}/aliases.sh"

# Set up aliases and PATH variables
set_aliases

if is_zsh; then
    emulate zsh -R
fi

if has_command "rustup"; then
    # Skip completion setup in non-interactive shells
    if [[ "$-" == *i* ]]; then
        RUSTUP=$(add_completion "rustup" "$(rustup completions "$(get_shell)" rustup 2>/dev/null || echo)" 2>/dev/null || true)
        CARGO=$(add_completion "cargo" "$(rustup completions "$(get_shell)" cargo 2>/dev/null || echo)" 2>/dev/null || true)
        if ! is_zsh; then
            if not_empty "${RUSTUP}" && [ -f "${RUSTUP}" ]; then
                # shellcheck disable=SC1090
                source "${RUSTUP}" 2>/dev/null || true
            fi
            if not_empty "${CARGO}" && [ -f "${CARGO}" ]; then
                # shellcheck disable=SC1090
                source "${CARGO}" 2>/dev/null || true
            fi
        fi
    fi
fi

if type uv &>/dev/null; then
    if is_fish; then
        uv generate-shell-completion fish
    else 
        # Skip completion setup in non-interactive shells
        if [[ "$-" == *i* ]]; then
            UV=$(add_completion "uv" "$(rustup completions "$(get_shell)" rustup 2>/dev/null || echo)" 2>/dev/null || true)
            # shellcheck disable=SC1090
            ([ -n "$UV" ] && [ -f "$UV" ] && source "$UV" 2>/dev/null) || true
        fi
    fi
fi

if has_command "pyenv"; then 
    add_to_rc "PYENV_ROOT=${HOME}/.pyenv"
    if dir_exists "${HOME}/.pyenv/bin"; then
        add_to_path "${HOME}/.pyenv/bin"
    fi
    if ! file_exists "${COMPLETIONS}/_pyenv"; then
        echo "- adding $(get_shell) completions for pyenv to ${BLUE}${COMPLETIONS}${RESET} directory"
        echo ""
        pyenv init - "$(get_shell)" >> "${COMPLETIONS}/_pyenv"
    fi
    # if file_exists "${COMPLETIONS}/_pyenv.zsh"; then
    #     if if_zsh; then
    #         source "${COMPLETIONS}/_pyenv.zsh"
    #     fi
    # else 
    #     echo "- ${BOLD}warning:${RESET} expected a completions file at: ${BLUE}${COMPLETIONS}/_pyenv${RESET}"
    #     echo "  but not found!"
    # fi
fi

if type pm2 &>/dev/null; then
    # shellcheck source="./resources/_pm2"
    source "${CONFIG_LOCATION}/resources/_pm2"
fi

if is_mac; then
    function flush() {
        if confirm "Flush DNS Cache?"; then
            sudo dscacheutil -flushcache
            sudo killall -HUP mDNSResponder
        fi
    }
fi

if type brew &>/dev/null; then
    HOMEBREW_PREFIX=$(brew --prefix)
    if is_zsh; then
        fpath+=( "$HOMEBREW_PREFIX/share/zsh/site-functions" )
    elif is_bash; then
        if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
                # shellcheck disable=SC1091
                source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
        else
            for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
                # shellcheck disable=SC1090
                [[ -r "$COMPLETION" ]] && source "${COMPLETION}"
            done
        fi
    fi
fi

if is_zsh; then
    if file_exists "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        # shellcheck disable=SC1091
        source "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "${HOME}/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        # shellcheck disable=SC1091
        source "${HOME}/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        # shellcheck disable=SC1091
        source "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    if file_exists "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
        # shellcheck disable=SC1091
        source "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
    fi
    unsetopt beep

    fpath+=( "${HOME}/.completions" )
    autoload -Uz compinit && compinit
    autoload -U add-zsh-hook
fi

if is_pve_host; then
    # shellcheck source="./utils/proxmox.sh"
    source "${UTILS}/proxmox.sh"
fi

if type aws_completer &>/dev/null; then
    if ! is_zsh; then
        # Skip completion setup in non-interactive shells
        if [[ "$-" == *i* ]]; then
            # shellcheck disable=SC1090
            source <"$(aws_completer "$(get_shell)" 2>/dev/null || echo)" 2>/dev/null || true
        fi
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

        bash "${HOME}/.config/sh/initialize.sh"
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



# source user's `.env` in home directory
# if it exists.
if file_exists "${HOME}/.env"; then
    set -a
    # shellcheck disable=SC1091
    source "${HOME}/.env"
    set +a
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


function vitesse_ext() {
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


log "- use the ${BOLD:-}${GREEN:-}sys${RESET:-} function for system, storage, and network info"
log "- use the ${BOLD:-}${GREEN:-}about${RESET:-} function for aliases, functions, and binary paths"

remove_colors

function net() {
    local -r file="${REPORTS}/sys.sh"

    bash "${file}" "net"
}

function sys() {
    local -r file="${REPORTS}/sys.sh"

    bash "${file}" "sys"
}

function track() {
    local -r file="${ROOT}/track.sh"
    local -ra params=( "$@" )

    bash "${file}" "${params[@]}"
}

function about() {
    local file="${REPORTS}/about"
    bash "${file}" "report_about"
}
