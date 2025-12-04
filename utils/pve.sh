#!/usr/bin/env bash

# FOR Proxmox containers (LXC and VM)
# The `proxmox.sh` file is for Proxmox Hosts

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__PVE_SH_LOADED:-}" ]] && declare -f "pve_api_get" > /dev/null && return
__PVE_SH_LOADED=1

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


source "${UTILS}/typeof.sh"
source "${UTILS}/detection.sh"
source "${UTILS}/filesystem.sh"
source "${UTILS}/network.sh"
source "${UTILS}/logging.sh"
source "${UTILS}/proxmox-api.sh"

# Exit codes
EXIT_OK=0
EXIT_CONFIG=1
EXIT_FALSE=1
EXIT_API=2
EXIT_NOTFOUND=3



# Proxmox API Port
PROXMOX_API_PORT="${PROXMOX_API_PORT:-8006}"
API_BASE="/api2/json/"

# pve_api_get <path> [filter] [host]
#
# Wrapper for pve_endpoint for backward compatibility.
function pve_api_get() {
    local -r path="${1:?pve_api_get requires an API path}"
    local -r filter="${2:-none}"
    local -r host="${3:-}"

    pve_endpoint "${path}" "${filter}" "${host}"
}

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


# whereami - Show which Proxmox node and VMID this container is running on
#
# Usage: whereami [-q|--quiet] [-j|--json]
#
# Options:
#   -q, --quiet   Output only "node:vmid" (for scripting)
#   -j, --json    Output as JSON
#   -h, --help    Show this help
function whereami() {
    set -euo pipefail

    # Parse arguments (before colors are set up)
    QUIET=false
    JSON=false
    VERBOSE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -j|--json)
                JSON=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;

            -h|--help)
                setup_colors
                usage
                ;;
            *)
                setup_colors
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Check dependencies
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
            if ! install_curl; then
                error "Failed to install {{BOLD}}{{BLUE}}curl{{RESET}}" "${EXIT_API}"
            fi
        else
            logc "Ok. Quitting for now, you can install {{BOLD}}{{BLUE}}jq{{RESET}} and then run this command again.\n"
            # shellcheck disable=SC2086
            return ${EXIT_CONFIG}
        fi
    fi

    # Load API token
    if [[ ! -f "$ENV_FILE" ]]; then
        error "API token file not found at $ENV_FILE" "${EXIT_CONFIG}"
    fi

    # shellcheck source=/dev/null
    source "$ENV_FILE"

    if [[ -z "${PVE_API_TOKEN:-}" ]]; then
        error "PVE_API_TOKEN not set in $ENV_FILE" "${EXIT_CONFIG}"
    fi

    HOSTNAME=$(hostname)
    debug "whereami" "Looking for hostname: $HOSTNAME"

    # Resolve seed node (dynamic discovery with fallbacks)
    SEED_NODE=$(resolve_seed_node)
    debug "whereami" "Using seed node: $SEED_NODE"

    # Single API call to get all VMs/LXCs across entire cluster
    debug "whereami" "Querying cluster resources..."
    RESULT=$(curl -sk --max-time 10 \
        -H "Authorization: PVEAPIToken=$PVE_API_TOKEN" \
        "https://$SEED_NODE:8006/api2/json/cluster/resources?type=vm" 2>/dev/null)

    if [[ -z "$RESULT" ]] || ! echo "$RESULT" | jq -e '.data' &>/dev/null; then
        log_error "Failed to query PVE cluster API"
        exit $EXIT_API
    fi

    # Find this container/VM by hostname in single pass
    MATCH=$(echo "$RESULT" | jq -r --arg name "$HOSTNAME" \
        '.data[] | select(.name == $name) | "\(.node):\(.vmid):\(.type)"' 2>/dev/null | head -1)

    if [[ -z "$MATCH" ]]; then
        log_error "Could not find container/VM with hostname '$HOSTNAME'"
        [[ "$VERBOSE" == true ]] && {
            echo -e "${YELLOW}Available VMs/LXCs:${NC}" >&2
            echo "$RESULT" | jq -r '.data[] | "  \(.name) (\(.type)) on \(.node)"' >&2
        }
        exit $EXIT_NOTFOUND
    fi

    # Parse the match (format: node:vmid:type)
    IFS=':' read -r NODE VMID TYPE <<< "$MATCH"
    debug "whereami" "Found: $HOSTNAME is $TYPE $VMID on node $NODE"

    # Output
    if [[ "$JSON" == true ]]; then
        jq -n \
            --arg hostname "$HOSTNAME" \
            --arg node "$NODE" \
            --arg vmid "$VMID" \
            --arg type "$TYPE" \
            '{hostname: $hostname, node: $node, vmid: ($vmid | tonumber), type: $type}'
    elif [[ "$QUIET" == true ]]; then
        echo "$NODE:$VMID"
    else
        echo -e "${BOLD}Hostname:${NC}  $HOSTNAME"
        echo -e "${BOLD}Node:${NC}      $NODE"
        echo -e "${BOLD}VMID:${NC}      $VMID"
        echo -e "${BOLD}Type:${NC}      $TYPE"
    fi

    # shellcheck disable=SC2086
    exit ${EXIT_OK}
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
