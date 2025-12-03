#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__PROXMOX_OTHER_SH_LOADED:-}" ]] && return
__PROXMOX_OTHER_SH_LOADED=1

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


# get_nodes() <[host]>
#
# Gets the nodes by querying either the <host> passed in
# or the default host otherwise.
function get_pve_nodes() {
    local result;
    if is_pve_host; then
        result=$(get_pvesh "/nodes")
    else
        result=$(pve_api_call "/nodes")
    fi

    result="$(pve_parse "/nodes" "${result}")"

    echo "${result}"
}




# get_nodes() <[host]>
#
# Gets the nodes by querying either the <host> passed in
# or the default host otherwise.
function get_pve_cluster() {
    local result;
    if is_pve_host; then
        result=$(get_pvesh "/cluster/status")
    else
        result=$(pve_api_call "/cluster/status")
    fi

    result="$(pve_parse "/cluster" "${result}")"

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

function pve_resources() {
    local resources
    if is_pve_host; then
        resources="$(get_pvesh "/cluster/resources" ".data")"
    else
        resources="$(get_pve "/cluster/resources" ".data")"
    fi

    printf "%s" "$(list "${resources}")"
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
    local -r cluster=$(pve_endpoint "/cluster/status" '.data | map(select(.type == "cluster"))')

    __name=$(echo "${cluster}" | jq -r '.[] | .name')

    local -r json=$(pve_endpoint "/cluster/status" '.data | map(select(.type == "node"))')
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
