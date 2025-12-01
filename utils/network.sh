#!/usr/bin/env bash


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
