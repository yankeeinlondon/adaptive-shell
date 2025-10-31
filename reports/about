#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
    REPORTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "${REPORTS}" == *"/utils" ]];then
        ROOT="${REPORTS%"/utils"}"
        UTILS="${ROOT}/utils"
        PROGRAMS="${ROOT}/programs"
    else
        ROOT="${REPORTS}/.."
        UTILS="${ROOT}/utils"
        PROGRAMS="${ROOT}/programs"
    fi
else
    ROOT="${ADAPTIVE_SHELL}"
    REPORTS="${ROOT}/reports"
    PROGRAMS="${ROOT}/programs"
    UTILS="${ROOT}/utils"
fi

# shellcheck source="../utils/errors.sh"
source "${UTILS}/errors.sh"
allow_errors

function report_about() {
    catch_errors

    # shellcheck source="../color.sh"
    source "${ROOT}/color.sh"
    # shellcheck source="../utils.sh"
    source "${ROOT}/utils.sh"
    # shellcheck source="./aliases.sh"
    source "${REPORTS}/aliases.sh"
    # shellcheck source="./paths.sh"
    source "${REPORTS}/paths.sh"

    # shellcheck source="../programs/versioning.sh"
    source "${PROGRAMS}/versioning.sh"
    # shellcheck source="../programs/ssh.sh"
    source "${PROGRAMS}/ssh.sh"

    setup_colors

    TITLE="${MACHINE_NAME:-${TITLE:-${DIM:-}${ITALIC:-}your System}}"

    DEFAULT_DESC="${DIM}This system uses the ${ITALIC}adaptive shell${RESET}${DIM} bootstrap which provides functions, aliases, and installers based on the detected environment.${RESET}"

    CUSTOM_DESC="$(colorize "${MACHINE_DESC}")"

    DESC="$(newline_on_word_boundary "${CUSTOM_DESC:-${DEFAULT_DESC}}")"

    if is_linux; then
        OS_NAME="$(strip_after "/" "$(distro)")"
        KERNEL=", $(get_kernel_version)"
    else
        OS_NAME="$(os)"
        KERNEL=""
    fi
    OS_INFO=" (${DIM}${OS_NAME} $(os_version)${KERNEL}${RESET})"

    log ""
    log "${BOLD}${YELLOW}About${RESET} ${TITLE}${RESET}${OS_INFO}"
    log "------------------------------------------------------------"
    log "${DESC}"

    log ""

    log "${BOLD}Aliases:${RESET}"
    log "------------------------------------------------------------"
    report_aliases

    log ""
    log "${BOLD}Executable ${RESET}${DIM}paths detected${RESET}${BOLD}:${RESET}"
    log "------------------------------------------------------------"
    report_paths

    log ""
    log "${BOLD}Software:${RESET}"
    log "------------------------------------------------------------"
    source "${REPORTS}/sys.sh"
    editors
    setup_colors # this must be re-established as editors() call will have removed it

    VERSIONING=()
    if has_command "git"; then
        INFO="$(git_identity)"
        VERSIONING+=( "${INFO}" )
    fi
    log "${BOLD}GIT:${RESET}       ${VERSIONING[*]}"

    if has_file "${HOME}/.ssh/authorized_keys"; then
        SSH_AUTH_KEYS="✅ Authorized Keys"
    else
        SSH_AUTH_KEYS="❌ Authorized Keys"
    fi

    if has_file "${HOME}/.ssh/id_rsa.pub"; then
        SSH_PUB_KEY="✅ Public Key"
    else
        SSH_PUB_KEY="❌ Public Key"
    fi

    if has_file "${HOME}/.ssh/config"; then
        # shellcheck disable=SC2207
        local -ra hosts=($(get_ssh_hosts))
        if is_empty hosts; then
            SSH_KNOWN_HOSTS="❌ Known Hosts"
        else
            SSH_KNOWN_HOSTS="✅ Known Hosts [${#hosts[@]}]"
        fi
    else
        SSH_KNOWN_HOSTS="❌ Known Hosts"
    fi

    SSH="${SSH_AUTH_KEYS}, ${SSH_PUB_KEY}, ${SSH_KNOWN_HOSTS}"
    log "${BOLD}SSH:${RESET}       ${SSH}"


    log ""
    log "${BOLD}Functions:${RESET}"
    log "------------------------------------------------------------"
    log "- ${BLUE}${BOLD}sys${RESET}: storage, network, hardware info"
    log "- ${BLUE}${BOLD}add${RESET}: function to install common programs setup a directory based on "
    log "- ${BLUE}${BOLD}prep${RESET}: directory ${ITALIC}context-aware${RESET} for preparatory tasks"

    if is_pve_host; then
        log ""
        log "${BOLD}Proxmox:${RESET}"
        log "------------------------------------------------------------"
        pct list
    fi

    # mapfile -t FN < <(list_functions)
    # log "$(filter_out FN "is_" "has_" "get_")"

    remove_colors
}


# Call the main function when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_about
fi

