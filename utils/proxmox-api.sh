#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__PROXMOX_API_SH_LOADED:-}" ]] && return
__PROXMOX_API_SH_LOADED=1

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
source "${UTILS}/proxmox-utils.sh"


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

function status_help() {
    log ""
    log "${BOLD}Status Help${RESET}"
    log " - specify the area you want to get status on:"
    log " - choices are: ${GREEN}lxc${RESET}, ${GREEN}vm${RESET}, ${GREEN}nodes${RESET}, ${GREEN}storage${RESET},"
    log ""
}

# lxc_status()
#
# Reports on all of the LXC containers running in the cluster.
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

function pve_lxc_containers() {
    local -r path="/cluster/resources"
    local -r filter="| map(select(.type == 'lxc'))"
    local -r suggested_host="${1:-}"
    local resources

    resources="$(pve_endpoint "${path}" "${filter}" "${suggested_host}" )"

    printf "%s" "${resources}"
}

function pve_vm_containers() {
    local -r path="/cluster/resources"
    local -r filter="| map(select(.type == 'qemu'))"
    local -r suggested_host="${1:-}"
    local resources

    resources="$(pve_endpoint "${path}" "${filter}" "${suggested_host}" )"

    printf "%s" "${resources}"
}

function pve_storage() {
    local -r path="/cluster/resources"
    local -r filter="| map(select(.type == 'storage'))"
    local -r suggested_host="${1:-}"
    local resources

    resources="$(pve_endpoint "${path}" "${filter}" "${suggested_host}" )"

    printf "%s" "${resources}"
}

function pve_cifs_storage() {
    local -r path="/cluster/resources"
    local -r filter="| map(select(.type == 'storage' && .plugintype == 'cifs'))"
    local -r suggested_host="${1:-}"
    local resources

    resources="$(pve_endpoint "${path}" "${filter}" "${suggested_host}" )"

    printf "%s" "${resources}"
}

# pve_next_id() -> number
#
# Provides the lowest available container ID.
function pve_next_id() {
    local -r path="/cluster/nextid"
    local -r filter="none"
    local -r suggested_host="${1:-}"
    local resources

    resources="$(pve_endpoint "${path}" "${filter}" "${suggested_host}" )"

    printf "%s" "${resources}"
}

# pve_backups()
#
# A list of the backups schedule across the cluster
function pve_backups() {
    local -r path="/cluster/backup"
    local -r filter="none"
    local -r suggested_host="${1:-}"
    local resources

    resources="$(pve_endpoint "${path}" "${filter}" "${suggested_host}" )"

    printf "%s" "${resources}"
}

function pve_version() {
    local -r path="/version"
    local -r filter=".version"
    local -r suggested_host="${1:-}"
    local resources

    resources="$(pve_endpoint "${path}" "${filter}" "${suggested_host}" )"

    printf "%s" "${resources}"
}

# pve_node_log() <[node]> <[host]>
#
# Get's the logs from a specific node or across all of them.
function pve_node_log() {
    local -r node="${1:-none}"
    local -r path="/cluster/log"
    local -r suggested_host="${2:-}"
    local filter
    if [[ "${node}" == "none" ]]; then
        filter="none"
    else
        filter="| map(select(.node == '${node}'))"
    fi
    local resources

    resources="$(pve_endpoint "${path}" "${filter}" "${suggested_host}" )"

    printf "%s" "${resources}"
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
