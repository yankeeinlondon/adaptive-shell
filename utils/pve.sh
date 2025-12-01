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

# shellcheck source="./typeof.sh"
source "${UTILS}/typeof.sh"
# shellcheck source="./detection.sh"
source "${UTILS}/detection.sh"
# shellcheck source="./filesystem.sh"
source "${UTILS}/filesystem.sh"
# shellcheck source="./network.sh"
source "${UTILS}/network.sh"
# shellcheck source="./logging.sh"
source "${UTILS}/logging.sh"

# Exit codes
EXIT_OK=0
EXIT_CONFIG=1
EXIT_FALSE=1
EXIT_API=2
EXIT_NOTFOUND=3

# sniff out an API key
API_KEY=${API_KEY:-${PROXMOX_API_KEY}}

# Proxmox API Port
PROXMOX_API_PORT="${PROXMOX_API_PORT:-8006}"
API_BASE="/api2/json/"

# has_pve_api_key
#
# Checks whether a Proxmox VE API key is available.
# Returns 0 if found, 1 if not.
#
# Checks in order:
# 1. PVE_API_KEY environment variable
# 2. Mounted config file in containers/VMs at ~/.config/pve/api-key
function has_pve_api_key() {
    # Check environment variable first (fastest)
    if not_empty "${PVE_API_KEY}"; then
        # shellcheck disable=SC2086
        return ${EXIT_OK}
    fi

    # Check for mounted config in containers/VMs
    if is_lxc || is_vm; then
        if file_exists "${HOME}/.config/pve/api-key"; then
            # shellcheck disable=SC2086
            return ${EXIT_OK}
        fi
    fi

    # shellcheck disable=SC2086
    return ${EXIT_FALSE}
}

# is_pve_container
#
# Test whether current host is an LXC container or VM
# running on Proxmox VE with API access available.
# Returns 0 if true, 1 if false.
function is_pve_container() {
    # Must be running in a container or VM
    if ! is_lxc && ! is_vm; then
        # shellcheck disable=SC2086
        return ${EXIT_FALSE}
    fi

    # Must have API key access
    has_pve_api_key
}

# pve_api_get <path>
#
# Makes a GET request to the Proxmox VE API.
# Echoes the JSON response on success, or returns error code on failure.
#
# Requires:
#   - PVE_API_TOKEN environment variable
#   - jq command available
#   - Reachable Proxmox node
function pve_api_get() {
    local -r path="${1:?pve_api_get requires an API path}"
    local -r host="$(get_proxmox_node)"
    local -r fq_path="${API_BASE}${path}"

    if ! has_command "jq"; then
        logc "{{BOLD}}{{BLUE}}jq{{RESET}} is required for Proxmox API calls."
        if confirm "Install jq now?"; then
            if ! install_jq; then
                error "Failed to install {{BOLD}}{{BLUE}}jq{{RESET}}" "${EXIT_API}"
            fi
        else
            logc "Ok. Quitting for now, you can install {{BOLD}}{{BLUE}}jq{{RESET}} and then run this command again.\n"
            # shellcheck disable=SC2086
            return ${EXIT_CONFIG}
        fi
    fi

    if ! has_command "curl"; then
        logc "{{BOLD}}{{BLUE}}curl{{RESET}} is required for Proxmox API calls."
        if confirm "Install curl now?"; then
            if ! install_jq; then
                error "Failed to install {{BOLD}}{{BLUE}}jq{{RESET}}" "${EXIT_API}"
            fi
        else
            logc "Ok. Quitting for now, you can install {{BOLD}}{{BLUE}}jq{{RESET}} and then run this command again.\n"
            # shellcheck disable=SC2086
            return ${EXIT_CONFIG}
        fi
    fi

    if is_empty "${host}"; then
        log_error "No Proxmox host found. Set PROXMOX_HOST environment variable."
        # shellcheck disable=SC2086
        return ${EXIT_API}
    fi

    local result
    result=$(curl -sk --max-time 10 \
        -H "Authorization: PVEAPIToken=$PVE_API_TOKEN" \
        "https://${host}:${PROXMOX_API_PORT}${fq_path}" 2>/dev/null
    )

    if [[ -z "${result}" ]] || ! echo "${result}" | jq -e '.data' &>/dev/null; then
        log_error "Proxmox API call failed: GET https://${host}:${PROXMOX_API_PORT}${fq_path}"
        # shellcheck disable=SC2086
        return ${EXIT_API}
    fi

    # Return the result
    echo "${result}"
}





# get_proxmox_node
#
# Attempts to find a reachable Proxmox VE node.
# Checks PROXMOX_HOST first, then common local names.
# Echoes the hostname on success, returns error code on failure.
#
# Candidates checked in order:
# 1. PROXMOX_HOST (or pve.home if not set)
# 2. PROXMOX_FALLBACK (or pve.local if not set)
# 3. pve
function get_proxmox_node() {
    local -r primary="${PROXMOX_HOST:-pve.home}"
    local -r fallback="${PROXMOX_FALLBACK:-pve.local}"
    local candidates=(
        "${primary}"
        "${fallback}"
        "pve"
    )

    for candidate in "${candidates[@]}"; do
        [[ -z "$candidate" ]] && continue
        log_verbose "Trying PVE node: $candidate"
        if curl -sk --max-time 2 --connect-timeout 2 "https://$candidate:${PROXMOX_API_PORT}/" &>/dev/null; then
            log_verbose "Found PVE node: $candidate"
            echo "$candidate"
            # shellcheck disable=SC2086
            return ${EXIT_OK}
        fi
    done

    error "No reachable Proxmox node found" "${EXIT_API}"
}



# about_container
#
# Displays information about the current container environment.
function about_container() {
    local message

    if is_lxc; then
        if is_pve_container; then
            message="{{BOLD}}Proxmox LXC{{RESET}} container"
        else
            message="{{BOLD}}LXC{{RESET}} container"
        fi
    elif is_vm; then
        if is_pve_container; then
            message="{{BOLD}}Proxmox VM{{RESET}}"
        else
            message="{{BOLD}}VM{{RESET}}"
        fi
    else
        # shellcheck disable=SC2086
        return ${EXIT_FALSE}
    fi

    logc "${message}"
}

