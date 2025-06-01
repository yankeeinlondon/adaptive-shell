#!/usr/bin/env bash

# Get the directory of the current script
SCRIPT_DIR="${HOME}/.config/sh"
COMPLETIONS="${HOME}/.completions"

# shellcheck source="./color.sh"
export AD_COLOR="${SCRIPT_DIR}/color.sh"
# shellcheck source="./utils.sh"
export AD_UTILS="${SCRIPT_DIR}/utils.sh"

# shellcheck source="./sys.sh"
export AD_SYS="${SCRIPT_DIR}/sys.sh"

# shellcheck source="./sys.sh"
export AD_TRACK="${SCRIPT_DIR}/track.sh"

# shellcheck source="./color.sh"
source "${SCRIPT_DIR}/color.sh"

setup_colors

# shellcheck source="./utils.sh"
source "${SCRIPT_DIR}/utils.sh"

# shellcheck source="./prep.sh"
source "${SCRIPT_DIR}/prep.sh"

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
    source "${SCRIPT_DIR}/resources/_pm2"
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
                [[ -r "$COMPLETION" ]] && source "$COMPLETION"
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
    source "${SCRIPT_DIR}/proxmox.sh"
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
    export PATH="${PATH}:${HOME}/.local/bin"
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

# if has_command "fzf"; then
#     export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
#     export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --lin-range :500 {}"
# fi

if has_command "eza"; then 
    alias ls='eza -a --icons=always --hyperlink'
    alias ll='eza -lhga --git  --hyperlink'
    alias ld='eza -lDga --git  --hyperlink'
    alias lt='eza -lTL 3 --icons=always  --hyperlink'
    # export FZF_ALT_C_OPTS="--preview 'eza --tree -color=always {} | head -200'"
elif has_command "exa"; then
    alias ls='exa -a '
    alias ll='exa -lhga --git '
    alias ld='exa -lDga --git '
    alias lt='exa -lTL 3 '
    # export FZF_ALT_C_OPTS="--preview 'exa --tree -color=always {} | head -200'"
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

function net() {
    bash "${AD_SYS}" "net"
}


function sys() {
    bash "${AD_SYS}" "sys"
}

function track() {
    local -ra params=( "$@" )

    bash "${AD_TRACK}" "${params[@]}"
}
