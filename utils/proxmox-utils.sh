#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__PROXMOX_UTILS_SH_LOADED:-}" ]] && declare -f "pve_endpoint" > /dev/null && return
__PROXMOX_UTILS_SH_LOADED=1

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

source "${UTILS}/logging.sh"
source "${UTILS}/detection.sh"

# Proxmox API Port
PVE_API_PORT="${PVE_API_PORT:-8006}"
PVE_API_BASE="/api2/json/"

# Exit codes
EXIT_OK=0
EXIT_CONFIG=1
EXIT_API=2
EXIT_MISSING_PREREQ=3
EXIT_JQ_PARSING=4
EXIT_INVALID_NODE=5

CLUSTER_ENV_FILE="${HOME}/.pve-cluster.env"

# pve_ensure_prerequisites()
#
# Ensures that curl and jq are installed before making an API call
function pve_ensure_prerequisites() {
    if ! has_command "jq"; then
        logc "{{BOLD}}{{BLUE}}jq{{RESET}} is required for Proxmox API calls."
        if confirm "Install jq now?"; then
            if ! install_jq; then
                error "Failed to install {{BOLD}}{{BLUE}}jq{{RESET}}" "${EXIT_API}"
            fi
        else
            logc "Ok. Quitting for now, you can install {{BOLD}}{{BLUE}}jq{{RESET}} and then run this command again.\n"

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
            return ${EXIT_CONFIG}
        fi
    fi

    return ${EXIT_OK}
}

# pve_request_url()
#
# receives the api_path and returns the fully formed API URL.
function pve_request_url() {
    local -r api_path="${1}"
    local -r host="$(get_proxmox_node "")"
    local -r fq_path="${PVE_API_BASE}${api_path}"

    echo "https://${host}:${PVE_API_PORT}${fq_path}"
}


# pve_endpoint <path> <filter> <suggested_host>
#
# An abstraction over whether we'll make an API call or a CLI call
# based on if the host machine is a PVE node or not.
function pve_endpoint() {
    local -r path="${1:?No path passed to pve_endpoint()}"
    local -r filter="${2:-}"
    local -r suggested_host="${3}"
    local sanitized

    if is_pve_host; then
        sanitized="."
    else
        sanitized=".data"
    fi

    if [[ "${filter}" != "none"  ]]; then
        if starts_with "$filter" "."; then
            sanitized="${sanitized}$(strip_leading "$filter" ".")"
        else
            sanitized="${sanitized} ${filter}"
        fi
    fi

    if is_pve_host; then
        debug "pve_endpoint" "using CLI to get '${path}' with filter '${sanitized}'"
        printf "%s" "$(pve_cli_call "${path}" "$sanitized")"
    else
        debug "pve_endpoint" "using API to get '${path}' with filter '${sanitized}'"
        printf "%s" "$(pve_api_call "${path}" "$sanitized" "${suggested_host}")"
    fi
}


# validate_api_key() <api_key>
#
# checks that a API call to Proxmox with the provided API_KEY
# returns a 200 status code.
function validate_api_key() {
    local -r key="${1:?no API key was passed to validate_api_key()}"
    local -r host="$(get_proxmox_node "")"
    local -r url="https://${host}:${PVE_API_PORT}${PVE_API_BASE}version"

    local code
    code=$(curl -sk -o /dev/null -w "%{http_code}" \
        -H "Authorization: PVEAPIToken=${key}" \
        "${url}" 2>/dev/null)

    if [[ "$code" == "200" ]]; then
        debug "validate_api_key" "key was valid"
        return 0
    else
        debug "validate_api_key" "invalid key [${code}]"
        return 1
    fi
}

function set_default_token() {
    local -r token="${1:?no token was passed to set_default_token()}"

    replace_line_in_file "${MOXY_CONFIG_FILE}" "DEFAULT_API" "DEFAULT_API=${token}"
}

# save_pve_cluster <node>
#
# Takes a validated PVE node and queries the cluster
# information, then saves it to ${CLUSTER_ENV_FILE}
# for faster future lookups.
function save_pve_cluster() {
    source "${UTILS}/text.sh"
    source "${UTILS}/filesystem.sh"

    local -r node="${1}"

    if is_empty "${node}"; then
        return 1
    fi

    local cluster_json
    cluster_json="$(get_pve_cluster)"

    if is_empty "${cluster_json}"; then
        debug "save_pve_cluster" "No cluster info returned from API"
        return 1
    fi

    # Parse cluster name
    local cluster_name
    cluster_name="$(echo "${cluster_json}" | jq -r '.[] | select(.type == "cluster") | .name' 2>/dev/null)"

    if is_empty "${cluster_name}"; then
        debug "save_pve_cluster" "Could not parse cluster name from response"
        return 1
    fi

    # Parse node IPs (nodes have type "node" and ip field)
    local node_ips
    node_ips="$(echo "${cluster_json}" | jq -r '[.[] | select(.type == "node") | .ip] | join(" ")' 2>/dev/null)"

    if is_empty "${node_ips}"; then
        # Fallback: use the node we connected to
        node_ips="${node}"
    fi

    # Uppercase cluster name for variable
    local var_name
    var_name="PVE_CLUSTER_$(uc "${cluster_name}")"

    # Create or update the cluster env file
    if file_exists "${CLUSTER_ENV_FILE}"; then
        # Check if this cluster already exists
        if grep -q "^${var_name}=" "${CLUSTER_ENV_FILE}" 2>/dev/null; then
            # Update existing entry
            sed -i.bak "s|^${var_name}=.*|${var_name}=\"${node_ips}\"|" "${CLUSTER_ENV_FILE}"
            rm -f "${CLUSTER_ENV_FILE}.bak"
        else
            # Append new cluster
            echo "${var_name}=\"${node_ips}\"" >> "${CLUSTER_ENV_FILE}"
        fi

        # Update DEFAULT_PVE_CLUSTER if not set or if only one cluster
        local cluster_count
        cluster_count="$(grep -c '^PVE_CLUSTER_' "${CLUSTER_ENV_FILE}" 2>/dev/null || echo "0")"

        if ! grep -q '^DEFAULT_PVE_CLUSTER=' "${CLUSTER_ENV_FILE}" 2>/dev/null; then
            echo "DEFAULT_PVE_CLUSTER=\"$(uc "${cluster_name}")\"" >> "${CLUSTER_ENV_FILE}"
        elif [[ "${cluster_count}" -eq 1 ]]; then
            sed -i.bak "s|^DEFAULT_PVE_CLUSTER=.*|DEFAULT_PVE_CLUSTER=\"$(uc "${cluster_name}")\"|" "${CLUSTER_ENV_FILE}"
            rm -f "${CLUSTER_ENV_FILE}.bak"
        fi
    else
        # Create new file
        {
            echo "# PVE Cluster Configuration"
            echo "# Auto-generated by adaptive shell scripts"
            echo ""
            echo "${var_name}=\"${node_ips}\""
            echo "DEFAULT_PVE_CLUSTER=\"$(uc "${cluster_name}")\""
        } > "${CLUSTER_ENV_FILE}"
    fi

    debug "save_pve_cluster" "Saved cluster ${cluster_name} with nodes: ${node_ips}"
    return 0
}

# match_known_cluster [requested]
#
# Looks up known cluster configurations from ENV variables.
# Returns space-delimited IP addresses for the matched cluster.
#
# Logic:
#   1. If requested is provided, look for PVE_CLUSTER_{UPPERCASE_REQUESTED}
#   2. If requested is empty but DEFAULT_PVE_CLUSTER is set, use that
#   3. Returns the value (space-delimited IPs) or empty string
function match_known_cluster() {
    source "${UTILS}/text.sh"

    local -r requested="${1:-}"
    local cluster_name
    local var_name

    if is_empty "${requested}"; then
        if is_empty "${DEFAULT_PVE_CLUSTER:-}"; then
            # No requested cluster, no default - return empty
            echo ""
            return 1
        else
            cluster_name="${DEFAULT_PVE_CLUSTER}"
        fi
    else
        cluster_name="$(uc "${requested}")"
    fi

    var_name="PVE_CLUSTER_${cluster_name}"

    # Use indirect expansion to get the variable value
    if [[ -n "${!var_name:-}" ]]; then
        echo "${!var_name}"
        return 0
    fi

    echo ""
    return 1
}

# pve_node_up <ref:candidates>
#
# Receives a reference to an array of candidate nodes and returns
# the first URL which is actively listening on the expected API port.
#
# If no candidates are found to be a valid API endpoint then
# an empty string is returned and exit code 1.
function pve_node_up() {
    local -n __candidates=$1

    for candidate in "${__candidates[@]}"; do
        if curl -sk --max-time 2 --connect-timeout 2 \
            "https://${candidate}:${PVE_API_PORT}/" &>/dev/null; then
            echo "$candidate"
            return ${EXIT_OK}
        fi
    done

    echo ""
    return 1
}

# get_proxmox_node
#
# Attempts to find a reachable Proxmox VE node.
#
# The PVE Node is resolved by:
#   - if the host machine has set `PVE_CLUSTER_XXX` set
#     then this will be used to determine the PVE Node
#   - if it isn't yet set then we'll instead:
#     1. PROXMOX_HOST (or pve.home if not set)
#     2. PROXMOX_FALLBACK (or pve.local if not set)
#     3. pve
function get_proxmox_node() {
    source "${UTILS}/network.sh"
    source "${UTILS}/filesystem.sh"

    local -r requested="${1}"
    local node
    local -a candidates

    if file_exists "${CLUSTER_ENV_FILE}"; then
        source "${CLUSTER_ENV_FILE}"
    fi

    local matched_nodes
    matched_nodes="$(match_known_cluster "${requested}")"
    if not_empty "${matched_nodes}"; then
        # Split space-delimited string into array
        read -ra candidates <<< "${matched_nodes}"
        node=$(pve_node_up candidates)
    elif is_ip4_address "${requested}"; then
        candidates=( "${requested}" )
        node=$(pve_node_up candidates)
        if is_empty "${node}"; then
            error "The IPv4 address {{BLUE}}${requested}{{RESET}} did not resolve to an active PVE node" ${EXIT_INVALID_NODE}
        fi
    elif is_ip6_address "${requested}"; then
        candidates=( "${requested}" )
        node=$(pve_node_up candidates)
        if is_empty "${node}"; then
            error "The IPv6 address {{BLUE}}${requested}{{RESET}} did not resolve to an active PVE node" ${EXIT_INVALID_NODE}
        fi
    elif is_dns_name "${requested}"; then
        candidates=( "${requested}" )
        node=$(pve_node_up candidates)
        if is_empty "${node}"; then
            error "The DNS name {{BLUE}}${requested}{{RESET}} did not resolve to an active PVE node" ${EXIT_INVALID_NODE}
        fi
    else
        local -r primary="${PROXMOX_HOST:-pve.home}"
        local -r fallback="${PROXMOX_FALLBACK:-pve.local}"
        local candidates=(
            "${primary}"
            "${fallback}"
            "pve"
        )
        node=$(pve_node_up candidates)
        if is_empty "${node}"; then
            error "None of the default candidates: -- [ ${candidates[*]} ] -- were an active PVE Node." ${EXIT_INVALID_NODE}
        fi
    fi

    # Success
    save_pve_cluster "${node}"

    echo "${node}"
}

# get_pve_api_key()
#
# Get's the API Key from the environment or in a known
# shared storage location.
function get_pve_api_key() {
    # Check for mounted config in containers/VMs
    if is_lxc || is_vm; then
        if file_exists "${HOME}/.config/pve/api-key.env"; then
            source "${HOME}/.config/pve/api-key.env";
            echo "${PVE_API_KEY}"
        fi
    elif ! is_pve_host; then
        echo "${PVE_API_KEY}"
    fi
}


# pve_apply_filter
#
# Parses an API response with jq.
function pve_apply_filter() {
    local -r response="${1}"
    local -r filter="${2}"
    local processed

    processed="$(printf "%s" "${response}" | jq --raw-output "${filter}")" || error "Problems parsing {{BLUE}}${url}{{RESET}}" ${EXIT_JQ_PARSING}

    stdout "${processed}"
}


# pve_api_call <path> <filter> <suggested_host>
function pve_api_call() {
    local -r api_path="${1}"
    local -r filter="${2}"
    local -r suggested_host="${3}"

    if ! pve_ensure_prerequisites; then
        logc "\nAPI call to {{BLUE}}${api_path}{{RESET}} was cancelled because package requirements (e.g., {{BOLD}}curl{{RESET}} and {{BOLD}}jq{{RESET}}) were not installed on the system.\n"

        return ${EXIT_MISSING_PREREQ}
    fi

    local -r host="$(get_proxmox_node "${suggested_host}")"

    if is_empty "${host}"; then
        error "No Proxmox host found. Set PROXMOX_HOST environment variable." ${EXIT_API}
    fi

    local -r url="https://${host}:${PVE_API_PORT}${PVE_API_BASE}${api_path}"

    local result
    result=$(curl -sk --max-time 10 \
        -H "Authorization: PVEAPIToken=${PVE_API_TOKEN}" \
        "${url}" 2>/dev/null
    )

    if [[ -z "${result}" ]] || ! echo "${result}" | jq -e '.data' &>/dev/null; then
        error "Proxmox API call failed: GET ${url}" ${EXIT_API}
    fi

    result=$(pve_apply_filter "${result}" "${filter}")

    # Return the result
    echo "${result}"
}

function pve_cli_call() {
    local -r path=${1:?no path provided to get_pvesh())}
    local -r filter=${2:-}

    local -r request="pvesh get ${path} --output-format=json"

    local response
    local exit_code
    # unfiltered response
    response="$(eval "$request")"
    exit_code=$?
    debug "pve_cli_call" "got a response from CLI of ${#response} characters"
    debug "pve_cli_call(${path})" "now filtering with: ${filter}"

    if [[ $exit_code -ne 0 ]] || is_empty "$response"; then
        error "CLI call to {{BOLD}}${request}{{RESET}} failed to return successfully (or returned nothing)"
    fi
    # jq filtering applied
    local filtered
    if not_empty "$filter"; then
        filtered="$(printf "%s" "${response}" | jq --raw-output "${filter}")" || error "Problem using jq with filter '${filter}' on the request {{BOLD}}${request}{{RESET}} which produced a response of ${#response} chars:\n\nRESPONSE:\n${response}\n---- END RESPONSE ----\n"
    else
        filtered="${response}"
    fi

    printf "%s" "${filtered}"
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
