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

# shellcheck source="../color.sh"
source "${ROOT}/color.sh"
# shellcheck source="../utils.sh"
source "${ROOT}/utils.sh"


function net() {
    if [[ "$(os)" == "macos" ]]; then
        ifconfig | grep "inet "
    elif [[ "$(os)" == "linux" ]]; then
        ip addr show | grep "inet "
    fi
}

function sys() {

    if is_linux; then
        OS="{{BOLD}}${YELLOW}$(os) {{RESET}}{{BOLD}}$(distro){{RESET}}"
    else
        OS="{{BOLD}}${YELLOW}$(os) {{RESET}}{{BOLD}}$(os_version){{RESET}}"
    fi

    MEM="$(get_memory)"
    MEM="$(find_replace ".00" "" "${MEM}")"
    ARCH="$(get_arch)"

    PROG=()
    if has_command "node" || has_command "nodejs"; then
        PROG+=("node")
    fi
    if has_command "bun"; then
        PROG+=("{{ITALIC}}{{DIM}}bun{{RESET}}")
    fi
    if has_command "pnpm"; then
        PROG+=("{{ITALIC}}{{DIM}}pnpm{{RESET}}")
    fi

    if has_command "python" || has_command "python3"; then
        PROG+=("python")
    fi

    if has_command "conda"; then
        PROG+=("{{ITALIC}}{{DIM}}conda{{RESET}}")
    fi

    if has_command "uv"; then
        PROG+=("{{ITALIC}}{{DIM}}uv{{RESET}}")
    fi

    if has_command "perl"; then
        PROG+=("perl")
    fi
    if has_command "rustup"; then
        PROG+=("rust")
    fi
    if has_command "php"; then
        PROG+=("php")
    fi
    if has_command "go"; then
        PROG+=("go")
    fi
    if has_command "lua"; then
        PROG+=("lua")
    fi

    FIRM="$(get_firmware)"

    logc ""
    logc "{{BOLD}}${BLUE}$(hostname){{RESET}}"
    logc "${OS}"
    logc "{{DIM}}---------------------------{{RESET}}"
    logc "{{BOLD}}Memory:{{RESET}}    ${MEM} {{DIM}}{{ITALIC}}gb{{RESET}}"
    logc "{{BOLD}}Arch:{{RESET}}      ${ARCH}"
    logc "{{BOLD}}Kernel:{{RESET}}    $(get_kernel_version)"
    if get_cpu_count &>/dev/null; then
        CPU_COUNT="$(get_cpu_count)"
        logc "{{BOLD}}CPU count:{{RESET}} ${CPU_COUNT}"
    fi

    if get_cpu_family &>/dev/null; then
        CPU="$(get_cpu_family)"
        logc "{{BOLD}}CPU type:{{RESET}}  ${CPU}"
    fi
    if not_empty "$FIRM"; then
        logc "{{BOLD}}Firmware:{{RESET}}  ${FIRM}"
    fi
    if is_lxc; then
        logc "{{BOLD}}Container:{{RESET}} LXC"
    fi
    if is_vm; then
        logc "{{BOLD}}Container:{{RESET}} VM"
    fi
    if is_docker; then
        logc "{{BOLD}}Container:{{RESET}} ${BLUE}Docker{{RESET}}"
    fi
    if get_ssh_connection &>/dev/null; then
        logc "{{BOLD}}SSH:{{RESET}}       $(get_ssh_connection)"
    fi

    editors
    logc "{{BOLD}}Lang:{{RESET}}      ${PROG[*]}"


    if has_command "systemctl"; then
        SYSD=( "$(get_systemd_units "getty" "cron" "postfix" "systemd" "user" "dbus" "pve-container@")" )
        # shellcheck disable=SC2178
        SYSD="$(find_replace "ssh" "{{DIM}}{{ITALIC}}ssh{{RESET}}" "${SYSD[*]}")"
        logc "{{BOLD}}Services:{{RESET}}  ${SYSD[*]}"
    fi
    if has_command "rc-status"; then
        # Alpine
        SYSD=( "$(get_alpine_services "getty" "cron" "postfix" "user" "dbus")" )
        # shellcheck disable=SC2178
        SYSD="$(find_replace "ssh" "{{DIM}}{{ITALIC}}ssh{{RESET}}" "${SYSD[*]}")"
        logc "{{BOLD}}Services:{{RESET}}  ${SYSD[*]}"
    fi

    logc "{{BOLD}}Network:{{RESET}}"
    net

    STORAGE="$(get_storage)"
    STORAGE="$(find_replace "dev" "{{DIM}}dev{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "zfs" "${GREEN}{{BOLD}}zfs{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "smb" "${BLUE}{{BOLD}}smb{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "cifs" "${BLUE}{{BOLD}}cifs{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "nfs" "${BRIGHT_BLUE}{{BOLD}}nfs{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "apfs" "${YELLOW}{{BOLD}}apfs{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "unknown" "${RED}{{BOLD}}unknown{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "Applications" "{{DIM}}Applications{{RESET}}" "${STORAGE}")"

    logc "{{BOLD}}Storage:{{RESET}}"
    logc "$(indent "    " "${STORAGE}")"

    remove_colors
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command="${1:-sys}"

    case "${command}" in
        net)
            net
            ;;
        sys)
            sys
            ;;
        *)
            logc "- unknown command ${RED}{{BOLD}}${command}{{RESET}} for sys module"
            exit 1
            ;;
    esac
fi
