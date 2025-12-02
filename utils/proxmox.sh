#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__PROXMOX_SH_LOADED:-}" ]] && return
__PROXMOX_SH_LOADED=1

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

# pve_api_get <path>
#
# Makes a GET request to the Proxmox VE API.
#   - on success, results are passed back on STDOUT
#   - on failure, error message is returned on STDERR
function pve_api_get() {
    local -r api_path="${1}"
    local -r host="$(get_proxmox_node)"
    local -r fq_path="${API_BASE}${api_path}"
    local -r token="$(get_pve_api_key)"
    local -r url="https://${host}:${PVE_API_PORT}${fq_path}"

    if is_pve_host; then
        logc "pve host"
        # TODO: use CLI
    fi

    if is_empty "${host}"; then
        error "No Proxmox host found. Set PROXMOX_HOST environment variable." ${EXIT_API}
    fi

    if pve_ensure_prerequisites; then
        local result
        result=$(curl -sk --max-time 10 \
            -H "Authorization: PVEAPIToken=${PVE_API_TOKEN}" \
            "https://${host}:${PROXMOX_API_PORT}${fq_path}" 2>/dev/null
        )

        if [[ -z "${result}" ]] || ! echo "${result}" | jq -e '.data' &>/dev/null; then
            error "Proxmox API call failed: GET https://${host}:${PROXMOX_API_PORT}${fq_path}" ${EXIT_API}
        fi

        # Return the result
        echo "${result}"
    else
        logc "\nAPI call to {{BLUE}}${url}{{RESET}} was cancelled because package requirements (e.g., {{BOLD}}curl{{RESET}} and {{BOLD}}jq{{RESET}}) were not installed on the system.\n"

        return ${EXIT_MISSING_PREREQ}
    fi

}


function call_api() {
    local -r path="${1:?No path passed to call_api()}"
    local -r filter="${2:-}"
    local offset_filter
    if is_pve_host; then
        offset_filter=$(ensure_starting ". " "$(strip_leading ".data " "$filter")")
        debug "call_api" "using pvesh to get '${path}' with filter '${offset_filter}'"
        printf "%s" "$(get_pvesh "${path}" "$offset_filter")"
    else
        offset_filter=$(ensure_starting ".data " "$(strip_leading ". " "$filter")")
        debug "call_api" "using pve API to get '${path}' with filter '${offset_filter}'"
        printf "%s" "$(get_pve "${path}" "$offset_filter")"
    fi
}


# validate_api_key() <api_key>
#
# checks that a API call to Proxmox with the provided API_KEY
# returns a 200 status code.
function validate_api_key() {
    local -r key="${1:?no URL was passed to fetch_get()}"
    local -r code=$(validate_api_key "${key}")

    if [[ "$code" == "200" ]]; then
        debug "validate_api_key" "key was valid"
        return 0
    else
        debug "validate_api_key" "invalid key [${code}]: ${key}"
        return 1
    fi
}

function set_default_token() {
    local -r token="${1:?no URL was passed to fetch_get()}"

    replace_line_in_file "${MOXY_CONFIG_FILE}" "DEFAULT_API" "DEFAULT_API=${token}"
}

# save_pve_cluster
#
# Takes a validated PVE node and get's the cluster
# information so that the file ${CLUSTER_ENV_FILE}
function save_pve_cluster() {
    local -r node="${1}"

    if not_empty "${node}"; then
        get_pve_cluster
    fi
}

# match_known_cluster
#
# Checks:
#   1. if there is a requested cluster then:
#      - we will see if `PVE_CLUSTER_${match}` is defined and return it if it is
#      - where "${match}" is the upper-cased version of
#   2. if no requested cluster but we have a `DEFAULT_PVE_CLUSTER` assigned
#
function match_known_cluster() {
    local -r requested="${1}"
    local match
    # the ENV variables starting with PVE_CLUSTER_
    local -a candidates
    if is_empty "${requested}"; then
        if is_empty "${DEFAULT_PVE_CLUSTER}"; then
            :
        else
            :
        fi
    else
        match="PVE_CLUSTER_$(uc "${requested}")"
        # TODO: iterate over candidates to see where $match _starts with_
        # one of the candidates.
    fi
}

# pve_node_up
#
# Receives an array of candidate nodes and returns
# the first URL which is actively listening on the expected API port.
#
# If no candidates are found to be a valid API endpoint then
# an empty string is returned.
function pve_node_up() {
    local -na candidates=${1}

    # TODO iterate over candidates; below code is just representative
    # for candidate in ${@candidates}; do
    #     if curl -sk --max-time 2 --connect-timeout 2 "https://$candidate:${PROXMOX_API_PORT}/" &>/dev/null; then
    #         echo "$candidate"
    #         return ${EXIT_OK};
    #     fi
    # end

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

    candidates=( "$(match_known_cluster "${requested}")" )
    if [[ "$#candidates" > 0 ]]; then
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
    elif
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


# pve_version
#
# Provides the PVE version of the PVE node.
function pve_version() {
    if is_pve_host; then
        local version
        version="$(pveversion)"
        version="$(strip_before "pve-manager/" "${version}")"
        version="$(strip_after_last "/"  "${version}")"

        echo "${version}"
        return 0
    else
        local -r version="$(get_pve_version)"

        echo "${version}"
        return 0
    fi
}

# get_next_container_id()
function get_next_container_id() {
    local host
    if not_empty "$1"; then
        host="${1}"
    else
        host="$(get_default_node)"
    fi
    local -r url=$(get_pve_url "${host}" "/cluster/nextid")
    local -r resp=$(fetch_get "${url}" "$(pve_auth_header)")
    local -r id="$(echo "${resp}" | jq --raw-output '.data')"

    printf "%s" "${id}"
}


# get_pve_version()
#
# Gets the PVE version information via the Proxmox API.
# You may optionally pass in a PVE HOST but if not
# then the "default host" will be used.
# shellcheck disable=SC2120
function get_pve_version() {
    local result;
    if is_pve_host; then
        result="$(pveversion)"
    else
        result="$(pve_api_get '/')"
    fi

    local -r version="$(echo "${result}" | jq --raw-output '.data.version')"

    printf "%s" "${version}"
}

# get_nodes() <[host]>
#
# Gets the nodes by querying either the <host> passed in
# or the default host otherwise.
function get_pve_nodes() {
    local result;
    if is_pve_host; then
        result=$(get_pvesh "/nodes")
    else
        result=$(pve_api_get "/nodes")
    fi

    result="$(pve_parse "/nodes" "${result}")"

    echo "${result}"
}

# pve_version_check()
#
# Validates that the PVE version is the minimum required.
# It uses `pveversion` command when directly no a host
# but otherwise relies on the API.
function pve_version_check() {
    local -r version="$(pve_version)"
    # shellcheck disable=SC2207
    local -ri major=( $(major_version "${version}") )

    if [[ major -lt 7  ]]; then
        log "You are running version ${version} of Proxmox but the scripts\nin Moxy require at least version 7."
        log ""
        log "Please consider upgrading."
        log ""
        exit
    fi

}

# next_container_id
#
# If executing on a PVE node it will return the lowest available
# PVE ID in the cluster.
function next_container_id() {
    if is_pve_host; then
        local -r cid=$(pvesh get /cluster/nextid)
        echo "$cid"
        return 0
    else
        printf "%s" "$(get_next_container_id "")"
        return 0
    fi
}

function get_pvesh() {
    local -r path=${1:?no path provided to get_pvesh())}
    local -r filter=${2:-}

    local -r request="pvesh get ${path} --output-format=json"

    local response
    debug "get_pvesh(${path})" "got a response, now filtering with: ${filter}"
    # unfiltered response
    response="$(eval "$request")"
    debug "get_pvesh" "got a response from CLI of ${#response} characters"
    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]] || is_empty "$1"; then
        error "CLI call to ${BOLD}${request}${RESET} failed to return successfully (or returned nothing)"
    fi
    # jq filtering applied
    local filtered
    if not_empty "$filter"; then
        filtered="$(printf "%s" "${response}" | jq --raw-output "${filter}")" || error "Problem using jq with filter '${filter}' on the request ${BOLD}${request}${RESET} which produced a response of ${#response} chars:\n\nRESPONSE:\n${response}\n---- END RESPONSE ----\n"
    else
        filtered="${response}"
    fi

    printf "%s" "${filtered}"
}

# pve_parse
#
# Parses an API response with jq.
function pve_parse() {
    local -r request_path="${1}"
    local -r response="${2}"
    local -r query="${3:-.data}"
    local -r url="$(get_pve_url "${request_path}")"
    local processed

    processed="$(printf "%s" "${response}" | jq --raw-output "${filter}")" || error "Problems parsing {{BLUE}}${url}{{RESET}}" ${EXIT_JQ_PARSING}

    stdout "${processed}"

}

function get_pve() {
    local -r path=${1:?no path passed to get_pve()}
    local -r filter=${2:-}
    local -r host=${3:-"$(get_default_node)"}
    local result

    result=$(pve_api_get "${path}")

    local response
    response="$(fetch_get "${url}" "$(pve_auth_header)")"

    if not_empty "${response}" && not_empty "${filter}"; then
        debug "get_pve(${path})" "got a response, now filtering with: ${filter}"

        response="$(printf "%s" "${response}" | jq --raw-output "${filter}")" || error "Problem using jq with filter '${filter}' on a response [${#response} chars] from the URL ${url}"
        printf "%s" "${response}"
    else
        echo "${response}"
    fi
}

function pve_resources() {
    local resources
    if is_pve_host; then
        resources="$(get_pvesh "/cluster/resources" ".data")"
    else
        resources="$(get_pve "/cluster/resources" ".data")"
    fi

    printf "%s" "$(list "${resources}")"
}

function pve_lxc_containers() {
    local -r path="/cluster/resources"
    local resources
    if is_pve_host; then
        resources="$(get_pvesh "${path}" '. | map(select(.type == "lxc"))')"
    else
        resources="$(get_pve "${path}" '.data | map(select(.type == "lxc"))')"
    fi

    printf "%s" "${resources}"
}

function pve_vm_containers() {
    local -r path="/cluster/resources"
    local -r filter='.data.[] | map(select(.type == "qemu"))'
    local resources
    if is_pve_host; then
        resources=$(get_pvesh "${path}" '. | map(select(.type == "qemu"))')
    else
        resources=$(get_pve "${path}" '.data | map(select(.type == "qemu"))')
    fi

    printf "%s" "${resources}"
}

function pve_storage() {
    local resources
    if is_pve_host; then
        resources="$(get_pvesh "/storage" '. | map(.)')"
    else
        resources="$(get_pve "/storage" '.data | map(.)')"
    fi

    printf "%s" "${resources}"
}

function pve_sdn() {
    local -r path="/cluster/resources"
    local -r filter=".data | map(select(.type == \"sdn\"))"
    local resources
    if is_pve_host; then
        resources="$(get_pvesh "${path}" "${filter}")"
    else
        resources="$(get_pve "${path}" "${filter}")"
    fi

    printf "%s" "$(list "${resources}")"
}

function pve_nodes() {
    local nodes
    if is_pve_host; then
        nodes=$(get_pvesh "/nodes" '. | map(.)')
    else
        nodes=$(get_pve "/nodes" '.data | map(.)')
    fi

    printf "%s" "${nodes}"
}


# pve_cluster_info <ref:name> <ref:nodes>
function pve_cluster_info() {
    local -n __name=$1
    local -n __nodes=$2
    local -r cluster=$(call_api "/cluster/status" '.data | map(select(.type == "cluster"))')

    __name=$(echo "${cluster}" | jq -r '.[] | .name')

    local -r json=$(call_api "/cluster/status" '.data | map(select(.type == "node"))')
    local -a data
    json_list_data json data

    __nodes=()
    for idx in "${!data[@]}"; do
        local -A record
        record="${data[${idx}]}"
        __nodes+=( "${record[@]}" )
    done

}

function pve_cluster_status() {
    local cluster
    if is_pve_host; then
        cluster=$(get_pvesh "/cluster/status" '.data | map(.)')
    else
        cluster=$(get_pve "/cluster/status" '. | map(.)')
    fi

    printf "%s" "${cluster}"
}

function pve_cluster_replication() {
local cluster
    if is_pve_host; then
        cluster=$(get_pvesh "/cluster/replication" '.data | map(.)')
    else
        cluster=$(get_pve "/cluster/replication" '. | map(.)')
    fi

    printf "%s" "${cluster}"
}

function pve_cluster_ha_status() {
local cluster
    if is_pve_host; then
        cluster=$(get_pvesh "/cluster/ha/status/current" '.data | map(.)')
    else
        cluster=$(get_pve "/cluster/ha/status/current" '. | map(.)')
    fi

    printf "%s" "${cluster}"
}

function pve_cluster_ha_manager() {
local cluster
    if is_pve_host; then
        cluster=$(get_pvesh "/cluster/ha/status/manager_status" '.data | map(.)')
    else
        cluster=$(get_pve "/cluster/ha/status/manager_status" '. | map(.)')
    fi

    printf "%s" "${cluster}"
}

function pve_node_config() {
    local nodes
    if is_pve_host; then
        nodes=$(get_pvesh "/cluster/config/nodes" '.data | map(.)')
    else
        nodes=$(get_pve "/cluster/config/nodes" '. | map(.)')
    fi

    printf "%s" "${nodes}"
}

# pve_node_dns() <node>
function pve_node_dns() {
    local -r node="1:?No node name was passed to pve_node_dns()!"
    local resp
    if is_pve_host; then
        resp=$(get_pvesh "/nodes/${node}/dns" '.data | map(.)')
    else
        resp=$(get_pve "/nodes/${node}/dns" '. | map(.)')
    fi

    printf "%s" "${resp}"
}

# pve_node_disks() <node>
function pve_node_disks() {
    local -r node="1:?No node name was passed to pve_node_disks()!"
    local resp
    if is_pve_host; then
        resp=$(get_pvesh "/nodes/${node}/disks/list" '.data | map(.)')
    else
        resp=$(get_pve "/nodes/${node}/disks/list" '. | map(.)')
    fi

    printf "%s" "${resp}"
}

# pve_lxc_status <node> <vmid>
function pve_lxc_status() {
    local -r node="${1:?No node name was passed to pve_lxc_container_status()!}"
    local -r vmid="${2:?No VMID passed to pve_lxc_container_status()}"
    local -A resp
    if is_pve_host; then
        resp=$(get_pvesh "/nodes/${node}/lxc/${vmid}/status/current" '.data | map(.)')
    else
        resp=$(get_pve "/nodes/${node}/lxc/${vmid}/status/current" '. | map(.)')
    fi

    printf "%s" "${resp[@]}"
}


function status_help() {
    log ""
    log "${BOLD}Status Help${RESET}"
    log " - specify the area you want to get status on:"
    log " - choices are: ${GREEN}lxc${RESET}, ${GREEN}vm${RESET}, ${GREEN}nodes${RESET}, ${GREEN}storage${RESET},"
    log ""
}



# json_list_data <ref:json> <ref:data> <ref: query>
function json_list_data() {
    allow_errors
    local -n __json=$1
    local -n __data=$2
    local -n __query=$3 2>/dev/null # sorting, filtering, etc.
    local -n __fn=$4 2>/dev/null
    catch_errors
    local -A record

    if is_not_typeof __json "string"; then
        error "Invalid JSON passed into json_list_data(); expected a reference to string data but instead got $(typeof __json)"
    fi

    if is_not_typeof __data "array"; then
        error "Invalid data structure passed into json_list_data() for data array. Expected an array got $(typeof data)"
    else
        # start with empty dataset
        __data=()
    fi

    local json_array
    mapfile -t json_array < <(jq -c '.[]' <<<"$__json")

    for json_obj in "${json_array[@]}"; do
        record=()
        while IFS= read -r -d '' key && IFS= read -r -d '' value; do
            record["$key"]="$value"
        done < <(jq -j 'to_entries[] | (.key, "\u0000", .value, "\u0000")' <<<"$json_obj")

        __data+=("$(declare -p record | sed 's/^declare -A record=//')")
    done
}



function lxc_status() {
    local -r json=$(pve_lxc_containers)
    local -a data=()
    local -A query=(
        [sort]="vmid"
    )
    json_list_data json data query
    local -A record

    local -A tag_color=()
    # shellcheck disable=SC2034
    local -a tag_palette=( "${BG_PALLETTE[@]}" )

    # Sort by VMID and display the results
    log ""
    log "🏃${BOLD} Running LxC Containers${RESET}"
    log "-----------------------------------------------------"
    for item in "${!data[@]}"; do
        eval "declare -A record=${data[item]}"
        if [[ "${record[status]}" == "running" ]]; then
            # shellcheck disable=SC2207
            local -a tags=( $(split_on ";" "${record["tags"]}") )
            local display_tags=""

            for t in "${tags[@]}"; do
                local color
                allow_errors
                if not_empty "${tag_color["$t"]}"; then
                    color="${tag_color["$t"]}"
                else
                    if ! unshift tag_palette color; then
                        tag_palette=( "${BG_PALLETTE[@]}" )
                        unshift tag_palette color
                    fi
                    tag_color["$t"]="$color"
                fi
                catch_errors
                display_tags="${display_tags} ${color}${t}${RESET}"
            done

            log "- ${record[name]} [${DIM}${record[vmid]}${RESET}]: ${ITALIC}${DIM}running on ${RESET}${record[node]}; ${display_tags}";
        fi
    done

    log ""
    log "✋${BOLD} Stopped LxC Containers${RESET}"
    log "-----------------------------------------------------"
    for item in "${!data[@]}"; do
        eval "declare -A record=${data[item]}"
        if [[ "${record[status]}" = "stopped" ]]; then
            # shellcheck disable=SC2207
            local -a tags=( $(split_on ";" "${record["tags"]:-}") )
            local display_tags=""

            for t in "${tags[@]}"; do
                local color
                if not_empty "${tag_color["$t"]:-}"; then
                    color="${tag_color["$t"]:-}"
                else
                    if ! unshift tag_palette color; then
                        # shellcheck disable=SC2034
                        tag_palette=( "${BG_PALLETTE[@]}" )
                        unshift tag_palette color
                    fi
                    tag_color["$t"]="$color"
                fi
                catch_errors
                display_tags="${display_tags} ${color}${t}${RESET}"
            done

            local template_icon=""
            if [[ "${record["template"]}" == "1" ]]; then
                template_icon="📄 "
            fi

            local locked_icon=""

            log "- ${template_icon}${locked_icon}${record["name"]} [${DIM}${record["vmid"]}${RESET}]: ${ITALIC}${DIM}residing on ${RESET}${record["node"]}; ${display_tags}";
        fi
    done
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
