#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__CONFIGURE_SH_LOADED:-}" ]] && declare -f "configure_git" > /dev/null && return
__CONFIGURE_SH_LOADED=1

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

# shellcheck source="./logging.sh"
source "${UTILS}/logging.sh"

# configure_git
#
# Adds Name, Email,
function configure_git() {
    source "${UTILS}/text.sh"
    source "${UTILS}/empty.sh"
    source "${UTILS}/ssh.sh"

    local -r name=$(strip_trailing "$(git config --global user.name)" "\n")
    local -r email=$(strip_trailing "$(git config --global user.email)" "\n")
    local -r signingkey=$(strip_trailing "$(git config --global user.signingkey)" "\n")

    git config set --global advice.addIgnoredFile false 2>/dev/null || true

    if not_empty "${name}" || not_empty "${email}" || not_empty "${signingkey}"; then
        logc "- {{BOLD}}{{BLUE}}git{{RESET}}{{BOLD}} is configured:"
        logc "    - Name: \t{{YELLOW}}${name}{{RESET}}"
        logc "    - Email:\t{{YELLOW}}${email}{{RESET}}"
        logc "    - Signing Key: {{YELLOW}}${signingkey}{{RESET}}"
    else
        logc "- your {{BOLD}}{{GREEN}}git{{RESET}} configuration is taken from the {{BLUE}}~/.config/git/config{{RESET}} file"
        logc "- if you've linked your config to a shared directory or are using a git dotfiles to sync across machines then you should have this set but it doesn't look like that has been done on this host yet."
        logc ""
    fi
    local user
    if user=$(github_auth_test); then
        logc "    - SSH Token: ✅ {{ITALIC}}connects as{{RESET}}{{BOLD}} ${user}"
    else
        logc "    - SSH Token: ❌ unable to connect to github"
    fi

}


function configure_ssh_keys() {
    source "${UTILS}/filesystem.sh"
    source "${UTILS}/interactive.sh"

    local -r ssh_dir="${HOME}/.ssh"
    local has_keypair=false

    # Check for common SSH keypair types
    if file_exists "${ssh_dir}/id_ed25519" || file_exists "${ssh_dir}/id_rsa" || file_exists "${ssh_dir}/id_ecdsa"; then
        has_keypair=true
    fi

    if [[ "${has_keypair}" == true ]]; then
        logc "- an {{BOLD}}{{BLUE}}SSH keypair{{RESET}} already exists on this host:"
        if file_exists "${ssh_dir}/id_ed25519"; then
            logc "    - {{YELLOW}}${ssh_dir}/id_ed25519{{RESET}}"
        fi
        if file_exists "${ssh_dir}/id_rsa"; then
            logc "    - {{YELLOW}}${ssh_dir}/id_rsa{{RESET}}"
        fi
        if file_exists "${ssh_dir}/id_ecdsa"; then
            logc "    - {{YELLOW}}${ssh_dir}/id_ecdsa{{RESET}}"
        fi
        return 0
    fi

    logc "- no {{BOLD}}{{BLUE}}SSH keypair{{RESET}} found on this host"
    if confirm "Create a new SSH keypair?"; then
        # Ensure .ssh directory exists with correct permissions
        if [[ ! -d "${ssh_dir}" ]]; then
            mkdir -p "${ssh_dir}"
            chmod 700 "${ssh_dir}"
        fi

        logc "- generating {{BOLD}}ed25519{{RESET}} keypair..."
        ssh-keygen -t ed25519 -f "${ssh_dir}/id_ed25519" || return 1
        logc "- {{BOLD}}{{GREEN}}SSH keypair created{{RESET}}"
    else
        logc "- skipping SSH keypair creation"
    fi
}

# CLI invocation handler - allows running script directly with a function name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set up paths for sourcing dependencies
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${UTILS%"/utils"}"

    cmd="${1:-}"
    shift 2>/dev/null || true

    if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
        script_name="$(basename "${BASH_SOURCE[0]}")"
        echo "Usage: $script_name <function> [args...]"
        echo ""
        echo "Available functions:"
        # List all functions that don't start with _
        declare -F | awk '{print $3}' | grep -v '^_' | sort | sed 's/^/  /'
        exit 0
    fi

    # Check if function exists and call it
    if declare -f "$cmd" > /dev/null 2>&1; then
        "$cmd" "$@"
    else
        echo "Error: Unknown function '$cmd'" >&2
        echo "Run '$(basename "${BASH_SOURCE[0]}") --help' for available functions" >&2
        exit 1
    fi
fi
