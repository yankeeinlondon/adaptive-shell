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
        return ${EXIT_OK}
    fi

    # Check for mounted config in containers/VMs
    if is_lxc || is_vm; then
        if file_exists "${HOME}/.config/pve/api-key"; then
            return ${EXIT_OK}
        fi
    fi

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
        log_error "jq is required for Proxmox API calls. Install with: apt install jq"
        return ${EXIT_CONFIG}
    fi

    if is_empty "${host}"; then
        log_error "No Proxmox host found. Set PROXMOX_HOST environment variable."
        return ${EXIT_API}
    fi

    local result
    result=$(curl -sk --max-time 10 \
        -H "Authorization: PVEAPIToken=$PVE_API_TOKEN" \
        "https://${host}:${PROXMOX_API_PORT}${fq_path}" 2>/dev/null
    )

    if [[ -z "${result}" ]] || ! echo "${result}" | jq -e '.data' &>/dev/null; then
        log_error "Proxmox API call failed: GET https://${host}:${PROXMOX_API_PORT}${fq_path}"
        return ${EXIT_API}
    fi

    # Return the result
    echo "${result}"
}

# is_dns_name <name>
#
# Validates whether the given string is a valid DNS hostname
# according to RFC 1123. Returns 0 if valid, 1 if invalid.
#
# - Labels may contain letters, digits, and hyphens
# - Labels cannot start or end with a hyphen
# - Each label max 63 characters
# - Total length max 253 characters
# - Trailing dot (FQDN) is allowed
function is_dns_name() {
    local -r name="${1:-}"

    # Empty string is invalid
    [[ -z "$name" ]] && return 1

    # Remove trailing dot for validation (FQDN format)
    local check_name="${name%.}"

    # Check total length (max 253 without trailing dot)
    [[ ${#check_name} -gt 253 ]] && return 1

    # Check for double dots (empty labels)
    [[ "$check_name" == *".."* ]] && return 1

    # Split into labels and validate each
    local IFS='.'
    local labels
    read -ra labels <<< "$check_name"

    local label
    for label in "${labels[@]}"; do
        # Empty label
        [[ -z "$label" ]] && return 1

        # Label too long (max 63)
        [[ ${#label} -gt 63 ]] && return 1

        # Must start with alphanumeric
        [[ ! "$label" =~ ^[a-zA-Z0-9] ]] && return 1

        # Must end with alphanumeric
        [[ ! "$label" =~ [a-zA-Z0-9]$ ]] && return 1

        # Must contain only alphanumeric and hyphens
        [[ ! "$label" =~ ^[a-zA-Z0-9-]+$ ]] && return 1
    done

    return 0
}

# is_ip4_address <address>
#
# Validates whether the given string is a valid IPv4 address.
# Returns 0 if valid, 1 if invalid.
#
# - Four octets separated by dots
# - Each octet: 0-255
# - No leading zeros (except for "0" itself)
function is_ip4_address() {
    local -r address="${1:-}"

    # Empty string is invalid
    [[ -z "$address" ]] && return 1

    # Must match basic IPv4 pattern (no leading/trailing dots, no double dots)
    [[ ! "$address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 1

    # Split into octets and validate each
    local IFS='.'
    local octets
    read -ra octets <<< "$address"

    # Must have exactly 4 octets
    [[ ${#octets[@]} -ne 4 ]] && return 1

    local octet
    for octet in "${octets[@]}"; do
        # No leading zeros (except for "0" itself)
        if [[ ${#octet} -gt 1 && "$octet" =~ ^0 ]]; then
            return 1
        fi

        # Must be in range 0-255
        if [[ "$octet" -gt 255 ]]; then
            return 1
        fi
    done

    return 0
}

# is_ip6_address <address>
#
# Validates whether the given string is a valid IPv6 address.
# Returns 0 if valid, 1 if invalid.
#
# Supports:
# - Full form: 8 groups of 4 hex digits
# - Compressed form with ::
# - IPv4-mapped addresses (::ffff:192.168.1.1)
# - Zone identifiers (fe80::1%eth0)
function is_ip6_address() {
    local address="${1:-}"

    # Empty string is invalid
    [[ -z "$address" ]] && return 1

    # Extract and remove zone identifier if present (e.g., %eth0)
    local zone=""
    if [[ "$address" == *"%"* ]]; then
        zone="${address#*%}"
        address="${address%%\%*}"
        # Zone must not be empty
        [[ -z "$zone" ]] && return 1
    fi

    # Check for IPv4-mapped/embedded address (::ffff:192.168.1.1 or 64:ff9b::192.168.1.1)
    if [[ "$address" =~ ^(.*):([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        local ipv4_part="${BASH_REMATCH[2]}"
        local ipv6_prefix="${BASH_REMATCH[1]}"

        # Validate the IPv4 portion
        if ! is_ip4_address "$ipv4_part"; then
            return 1
        fi

        # IPv4 part counts as 2 groups (32 bits = 2 x 16-bit groups)
        # So prefix should have at most 6 groups

        # Handle special cases
        if [[ "$ipv6_prefix" == ":" ]]; then
            # ::192.168.1.1 form - valid
            return 0
        elif [[ "$ipv6_prefix" == "::ffff" ]] || [[ "$ipv6_prefix" == "::FFFF" ]]; then
            # IPv4-mapped addresses ::ffff:x.x.x.x
            return 0
        elif [[ "$ipv6_prefix" =~ ::$ ]]; then
            # Ends with :: like 64:ff9b::
            # Replace IPv4 with two zero groups for validation
            address="${ipv6_prefix}0:0"
        else
            # Ends with : like prefix:
            # Replace IPv4 with two zero groups for validation
            address="${ipv6_prefix}:0:0"
        fi
    fi

    # Check for multiple :: (only one allowed)
    # Count occurrences of :: using bash string manipulation
    local temp="${address//::/_DC_}"
    local double_colon_count=$(( (${#temp} - ${#address}) / 2 ))
    [[ "$double_colon_count" -gt 1 ]] && return 1

    # Check for ::: (invalid)
    [[ "$address" == *":::"* ]] && return 1

    # Check for leading single colon (but not ::)
    [[ "$address" =~ ^:[^:] ]] && return 1

    # Check for trailing single colon (but not ::)
    [[ "$address" =~ [^:]:$ ]] && return 1

    # Handle :: expansion
    local expanded="$address"
    if [[ "$address" == *"::"* ]]; then
        # Count existing groups
        local groups_before groups_after
        local before_part="${address%%::*}"
        local after_part="${address#*::}"

        groups_before=0
        groups_after=0

        if [[ -n "$before_part" ]]; then
            local IFS=':'
            local -a parts
            read -ra parts <<< "$before_part"
            groups_before=${#parts[@]}
        fi

        if [[ -n "$after_part" ]]; then
            local IFS=':'
            local -a parts
            read -ra parts <<< "$after_part"
            groups_after=${#parts[@]}
        fi

        local total_groups=$((groups_before + groups_after))
        [[ "$total_groups" -gt 7 ]] && return 1

        # Build expansion
        local zeros_needed=$((8 - total_groups))
        local zeros=""
        for ((i = 0; i < zeros_needed; i++)); do
            zeros="${zeros}0:"
        done
        zeros="${zeros%:}"

        if [[ -z "$before_part" && -z "$after_part" ]]; then
            expanded="0:0:0:0:0:0:0:0"
        elif [[ -z "$before_part" ]]; then
            expanded="${zeros}:${after_part}"
        elif [[ -z "$after_part" ]]; then
            expanded="${before_part}:${zeros}"
        else
            expanded="${before_part}:${zeros}:${after_part}"
        fi
    fi

    # Now validate expanded form - should be 8 groups separated by colons
    local IFS=':'
    local -a groups
    read -ra groups <<< "$expanded"

    [[ ${#groups[@]} -ne 8 ]] && return 1

    local group
    for group in "${groups[@]}"; do
        # Each group must be 1-4 hex characters
        [[ ! "$group" =~ ^[0-9a-fA-F]{1,4}$ ]] && return 1
    done

    return 0
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
            return ${EXIT_OK}
        fi
    done

    log_error "No reachable Proxmox node found"
    return ${EXIT_API}
}



# about_container
#
# Displays information about the current container/VM environment.
# Used for displaying system info in shell startup.
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
        return ${EXIT_FALSE}
    fi

    logc "${message}"
}

