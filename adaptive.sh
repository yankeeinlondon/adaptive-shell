#!/usr/bin/env bash

# Safe defaults for GUI-launched shells (WezTerm via BTT/Dock)
: "${HOME:?HOME not set}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${ZDOTDIR:=$HOME}"

# shellcheck disable=SC2155
__adaptive_resolve_root() {
    if [[ -n ${BASH_SOURCE[0]:-} ]]; then
        builtin cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd
        return
    fi

    if [[ -n ${ZSH_VERSION:-} ]]; then
        local sourced
        eval 'sourced="${(%):-%x}"'
        builtin cd "$(dirname "${sourced}")" 2>/dev/null && pwd
        return
    fi

    pwd
}

ADAPTIVE_SHELL="$(__adaptive_resolve_root)"
export ADAPTIVE_SHELL
unset -f __adaptive_resolve_root

ROOT="${ADAPTIVE_SHELL}"
UTILS="${ROOT}/utils"
REPORTS="${ROOT}/reports"
# Get the directory of the current script
CONFIG_LOCATION="${HOME}/.config/sh"
COMPLETIONS="${HOME}/.completions"

# ensure_autoload
#
# Ensures that autoload -Uz compinit && compinit is properly configured
# in ~/.zshrc for zsh shells. Removes all existing autoload -Uz lines
# and adds a single consolidated line at the end.
function ensure_autoload() {
    # Only proceed if running in zsh
    if ! is_zsh; then
        return 0
    fi

    local zshrc="${HOME}/.zshrc"

    # Remove all lines containing 'autoload -Uz' from .zshrc
    if file_exists "${zshrc}"; then
        # Create a temporary file
        local tmpfile
        tmpfile=$(mktemp)

        # Filter out lines with autoload -Uz
        grep -v "autoload -Uz" "${zshrc}" >"${tmpfile}" 2>/dev/null || true

        # Replace the original file
        mv "${tmpfile}" "${zshrc}"
    fi

    # Add the autoload line at the end
    echo "autoload -Uz compinit && compinit" >>"${zshrc}"
}

# add_to_fpath <path>
#
# Adds the given path to the fpath in ~/.zshrc if not already present.
# Only operates in zsh shells.
function add_to_fpath() {
    local -r path="${1:?path is missing in call to add_to_fpath!}"

    # Only proceed if running in zsh
    if ! is_zsh; then
        return 0
    fi

    local zshrc="${HOME}/.zshrc"

    # Check if path is already in fpath in .zshrc
    if file_exists "${zshrc}"; then
        if grep -q "fpath.*${path}" "${zshrc}" 2>/dev/null; then
            # Path already present
            return 0
        fi
    fi

    # Add the path to fpath
    echo "fpath+=( \"${path}\" )" >>"${zshrc}"
}

# offer_starship_install
#
# Offers -- at most once per host -- to install the starship prompt.
#
# Declining writes a marker file so later shells stay silent; delete it
# (or run `install_starship`) to revisit the decision.
function offer_starship_install() {
    local -r marker="${HOME}/.adaptive-no-starship"

    if has_command "starship"; then
        return 0
    fi

    # Only ever prompt from an interactive shell with a terminal
    # attached. A prompt raised during a non-interactive startup (an
    # editor capturing the environment, scp, cron) blocks forever with
    # nothing on screen explaining why.
    case "$-" in
        *i*) ;;
        *) return 0 ;;
    esac
    if [ ! -t 0 ] && [ ! -r /dev/tty ]; then
        return 0
    fi
    if file_exists "${marker}"; then
        return 0
    fi

    # shellcheck source="./utils/interactive.sh"
    source "${UTILS}/interactive.sh"

    log ""
    logc "{{BOLD}}{{GREEN}}starship{{RESET}} -- the prompt this config expects -- is not installed on this host."

    if ! confirm "Install it now?"; then
        : > "${marker}"
        logc "{{DIM}}- ok, not asking again{{RESET}}"
        logc "{{DIM}}- run {{BOLD}}{{BLUE}}install_starship{{RESET}}{{DIM}} whenever you change your mind{{RESET}}"
        return 0
    fi

    # shellcheck source="./utils/install.sh"
    source "${UTILS}/install.sh"

    if ! install_starship; then
        logc "{{DIM}}- run {{BOLD}}{{BLUE}}install_starship{{RESET}}{{DIM}} to try again{{RESET}}"
        return 1
    fi

    # user-functions.sh defines a `starship` wrapper when the binary is
    # missing, and functions shadow executables -- drop it or the real
    # starship stays unreachable for the rest of this shell.
    unset -f starship 2> /dev/null || true
}

function adaptive_setup() {

    # shellcheck source="./utils/text.sh"
    source "${UTILS}/logging.sh"
    # shellcheck source="./utils/detection.sh"
    source "${UTILS}/detection.sh"
    # shellcheck source="./utils/filesystem.sh"
    source "${UTILS}/filesystem.sh"
    # shellcheck source="./utils/empty.sh"
    source "${UTILS}/empty.sh"
    # shellcheck source="./utils.sh"
    source "${ROOT}/utils.sh"
    # shellcheck source="./reports/paths.sh"
    source "${REPORTS}/paths.sh"
    # shellcheck source="./reports/aliases.sh"
    source "${REPORTS}/aliases.sh"

    # Set up aliases and PATH variables
    set_aliases
    append_to_path # Add detected paths (e.g., ~/.local/bin, ~/.cargo/bin) to PATH

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

    if has_command "uv"; then
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
            append_to_path
        fi
        if ! file_exists "${COMPLETIONS}/_pyenv"; then
            echo "- adding $(get_shell) completions for pyenv to ${BLUE}${COMPLETIONS}${RESET} directory"
            echo ""
            pyenv init - "$(get_shell)" >>"${COMPLETIONS}/_pyenv"
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

    if has_command "pm2"; then
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

    if has_command "brew"; then
        HOMEBREW_PREFIX=$(brew --prefix)
        if is_zsh; then
            fpath+=("$HOMEBREW_PREFIX/share/zsh/site-functions")
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

        fpath+=("${HOME}/.completions")
        autoload -Uz compinit && compinit
        autoload -U add-zsh-hook
    fi

    if is_pve_host; then
        source "${UTILS}/proxmox-api.sh"
    fi

    if has_command "aws_completer"; then
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
        if file_exists "${UTILS}/wezterm.sh"; then
            # shellcheck source="./utils/wezterm.sh"
            source "${UTILS}/wezterm.sh"
        fi
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

    # Completion loading below spawns each CLI via `source <(...)`. In a
    # TTY-less shell (e.g. Zed/IDE environment capture: `$SHELL -l -i -c`
    # with pipes) that combination can deadlock zsh, wedging the editor's
    # env capture so its language servers never start. Completions are
    # useless without a terminal, so skip the whole region.
    if [ -t 0 ] || [ -t 1 ]; then

        if has_command "just"; then

            if is_zsh; then
                if file_exists "${HOME}/.zsh/completion/_just"; then
                    logc "- {{BOLD}}just{{RESET}} completions loaded"
                else
                    logc "- {{ITALIC}}adding {{RESET}}{{BOLD}}just{{RESET}} completions"
                    just --completions zsh >"${HOME}/.zsh/completion/_just"
                    add_to_fpath "_just"
                    ensure_autoload
                fi
            elif is_bash; then
                if file_exists "${HOME}/.local/share/bash-completion/completions"; then
                    if file_contains "${HOME}/.local/share/bash-completion/completions" "_just() {"; then
                        logc "- {{BOLD}}just{{RESET}} completions loaded"
                    else
                        logc "- {{ITALIC}}adding {{RESET}}{{BOLD}}just{{RESET}} completions"
                        just --completions bash >>"${HOME}/.local/share/bash-completion/completions"
                    fi
                fi
            fi
        fi

        if has_command "hug"; then

            if is_zsh; then
                if file_exists "${HOME}/.zsh/completion/_hug"; then
                    logc "- {{BOLD}}hug{{RESET}} ({{DIM}}{{ITALIC}}tree-hugger{{RESET}}) completions loaded"
                else
                    logc "- {{ITALIC}}adding {{RESET}}{{BOLD}}hug{{RESET}} ({{DIM}}{{ITALIC}}tree-hugger{{RESET}}) completions"
                    hug completions zsh >"${HOME}/.zsh/completion/_hug"
                    add_to_fpath "_hug"
                    ensure_autoload
                fi
            elif is_bash; then
                if file_exists "${HOME}/.local/share/bash-completion/completions"; then
                    if file_contains "${HOME}/.local/share/bash-completion/completions" "_hug() {"; then
                        logc "- {{BOLD}}hug{{RESET}} completions loaded"
                    else
                        logc "- {{ITALIC}}adding {{RESET}}{{BOLD}}hug{{RESET}} ({{DIM}}{{ITALIC}}tree-hugger{{RESET}}) completions"
                        hug completions bash >>"${HOME}/.local/share/bash-completion/completions"
                    fi
                fi
            fi
        fi
        if has_command "homey"; then

            if is_zsh; then
                source <(COMPLETE=zsh homey)
                logc "- {{BOLD}}homey{{RESET}} ({{DIM}}{{ITALIC}}homelab{{RESET}}) completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash homey)
                logc "- {{BOLD}}homey{{RESET}} ({{DIM}}{{ITALIC}}homelab{{RESET}}) completions loaded"
            fi
        fi

        if has_command "messenger"; then

            if is_zsh; then
                source <(COMPLETE=zsh messenger)
                logc "- {{BOLD}}messenger{{RESET}} completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash messenger)
                logc "- {{BOLD}}messenger{{RESET}} completions loaded"
            fi
        fi

        if has_command "md"; then

            if is_zsh; then
                source <(COMPLETE=zsh md)
                logc "- {{BOLD}}md{{RESET}} ({{DIM}}{{ITALIC}}darkmatter{{RESET}}) completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash md)
                logc "- {{BOLD}}md{{RESET}} ({{DIM}}{{ITALIC}}darkmatter{{RESET}}) completions loaded"
            fi
        fi

        if has_command "bt"; then

            if is_zsh; then
                source <(COMPLETE=zsh bt)
                logc "- {{BOLD}}bt{{RESET}} ({{DIM}}{{ITALIC}}biscuit-terminal{{RESET}}) completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash bt)
                logc "- {{BOLD}}bt{{RESET}} ({{DIM}}{{ITALIC}}biscuit-terminal{{RESET}}) completions loaded"
            fi
        fi

        if has_command "sniff"; then

            if is_zsh; then
                source <(COMPLETE=zsh sniff)
                logc "- {{BOLD}}sniff{{RESET}} completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash sniff)
                logc "- {{BOLD}}sniff{{RESET}} completions loaded"
            fi
        fi

        if has_command "wt"; then

            if is_zsh; then
                source <(wt --completions zsh)
                logc "- {{BOLD}}wt{{RESET}} ({{DIM}}worktree{{RESET}}) completions loaded"
            elif is_bash; then
                source <(wt --completions bash)
                logc "- {{BOLD}}wt{{RESET}} ({{DIM}}worktree{{RESET}}) completions loaded"
            fi
        fi

        if has_command "playa"; then

            if is_zsh; then
                source <(COMPLETE=zsh playa)
                logc "- {{BOLD}}playa{{RESET}} completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash playa)
                logc "- {{BOLD}}playa{{RESET}} completions loaded"
            fi
        fi

        if has_command "so-you-say"; then

            if is_zsh; then
                source <(COMPLETE=zsh so-you-say)
                logc "- {{BOLD}}so-you-say{{RESET}} ({{DIM}}{{ITALIC}}biscuit-speaks{{RESET}}) completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash so-you-say)
                logc "- {{BOLD}}so-you-say{{RESET}} ({{DIM}}{{ITALIC}}biscuit-speaks{{RESET}}) completions loaded"
            fi
        fi

        if has_command "model"; then

            if is_zsh; then
                source <(COMPLETE=zsh model)
                logc "- {{BOLD}}model{{RESET}} ({{DIM}}{{ITALIC}}model-citizen{{RESET}}) completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash model)
                logc "- {{BOLD}}model{{RESET}} ({{DIM}}{{ITALIC}}model-citizen{{RESET}}) completions loaded"
            fi
        fi

        if has_command "bh"; then

            if is_zsh; then
                source <(COMPLETE=zsh bh)
                logc "- {{BOLD}}bh{{RESET}} ({{DIM}}{{ITALIC}}biscuit-hash{{RESET}}) completions loaded"
            elif is_bash; then
                source <(COMPLETE=bash bh)
                logc "- {{BOLD}}bh{{RESET}} ({{DIM}}{{ITALIC}}biscuit-hash{{RESET}}) completions loaded"
            fi
        fi

        if has_command "claudine"; then

            if is_zsh; then
                source <(claudine completions zsh)
                logc "- {{BOLD}}claudine{{RESET}} completions loaded"
            elif is_bash; then
                source <(claudine completions bash)
                logc "- {{BOLD}}claudine{{RESET}} completions loaded"
            fi
        fi

        if has_command "unchained"; then

            if is_zsh; then
                # source <(unchained completions zsh)
                logc "- {{BOLD}}unchained{{RESET}} completions loaded"
            elif is_bash; then
                # source <(unchained completions bash)
                logc "- {{BOLD}}unchained{{RESET}} completions loaded"
            fi
        fi

        if has_command "question"; then

            if is_zsh; then
                source <(question completions zsh)
                logc "- {{BOLD}}question{{RESET}} ({{DIM}}{{ITALIC}}biscuit-tui{{RESET}}) completions loaded"
            elif is_bash; then
                source <(question completions bash)
                logc "- {{BOLD}}question{{RESET}} ({{DIM}}{{ITALIC}}biscuit-tui{{RESET}}) completions loaded"
            fi
        fi

    fi # end TTY guard around completion loading

    source "${ROOT}/user-functions.sh"

    offer_starship_install

    # NOTE: use `has_command` (not `type`) for every tool initialized via
    # `eval "$(tool ...)"`. `user-functions.sh` defines wrapper *functions*
    # for tools that aren't installed; `type` sees those wrappers and we'd
    # end up running the "install me?" prompt inside a command substitution,
    # where its prompt is swallowed and its output is eval'd as shell code.
    if has_command "starship"; then
        if is_zsh; then
            eval "$(starship init zsh)"
        elif is_bash; then
            eval "$(starship init bash)"
        fi
    fi

    if has_command "atuin"; then
        SHELL="$(get_shell)"
        eval "$(atuin init "${SHELL}" --disable-up-arrow)"
    fi

    if has_command "direnv"; then
        SHELL="$(get_shell)"
        eval "$(direnv hook "${SHELL}")"
    fi

    # zoxide must init last — after compinit and after every other tool
    # that hooks the prompt or cd (starship, atuin, direnv).
    if has_command "zoxide"; then
        eval "$(zoxide init "$(get_shell)")"
    fi

    log ""
    logc "{{DIM}}* use the {{BOLD}}{{GREEN}}about{{RESET}} {{ITALIC}}function{{RESET}} to get details on this machine"

}

adaptive_setup
