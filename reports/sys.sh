#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__SYS_SH_LOADED:-}" ]] && return
__SYS_SH_LOADED=1

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
    REPORTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "${REPORTS}" == *"/utils" ]];then
        ROOT="${REPORTS%"/utils"}"
        UTILS="${ROOT}/utils"
    else
        ROOT="${REPORTS}/.."
        UTILS="${ROOT}/utils"
    fi
else
    ROOT="${ADAPTIVE_SHELL}"
    REPORTS="${ROOT}/reports"
    UTILS="${ROOT}/utils"
fi

function report_sys() {
    # shellcheck source="../utils/color.sh"
    source "${UTILS}/color.sh"
    # shellcheck source="../utils/logging.sh"
    source "${UTILS}/logging.sh"
    # shellcheck source="../utils/programs.sh"
    source "${UTILS}/programs.sh"
    # shellcheck source="../utils/detection.sh"
    source "${UTILS}/detection.sh"
    # shellcheck source="../utils/os.sh"
    source "${UTILS}/os.sh"
    # shellcheck source="../utils/network.sh"
    source "${UTILS}/network.sh"

    if is_linux; then
        OS="{{BOLD}}{{YELLOW}}$(os) {{RESET}}{{BOLD}}$(distro){{RESET}}"
    else
        OS="{{BOLD}}{{YELLOW}}$(os) {{RESET}}{{BOLD}}$(os_version){{RESET}}"
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
    logc "{{BOLD}}{{BLUE}}$(hostname){{RESET}}"
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
        logc "{{BOLD}}Container:{{RESET}} {{BLUE}}Docker{{RESET}}"
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

    logc "{{BOLD}}Network Interfaces:{{RESET}}"
    network_interfaces

    STORAGE="$(get_storage)"
    STORAGE="$(find_replace "dev" "{{DIM}}dev{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "zfs" "{{GREEN}}{{BOLD}}zfs{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "smb" "{{BLUE}}{{BOLD}}smb{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "cifs" "{{BLUE}}{{BOLD}}cifs{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "nfs" "{{BRIGHT_BLUE}}{{BOLD}}nfs{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "apfs" "{{YELLOW}}{{BOLD}}apfs{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "unknown" "{{RED}}{{BOLD}}unknown{{RESET}}" "${STORAGE}")"
    STORAGE="$(find_replace "Applications" "{{DIM}}Applications{{RESET}}" "${STORAGE}")"

    logc "{{BOLD}}Storage:{{RESET}}"
    logc "$(indent "    " "${STORAGE}")"
    logc ""
}

# CLI invocation handler - allows running script directly with a function name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set up paths for sourcing dependencies
    REPORTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${REPORTS}/.."
    UTILS="${ROOT}/utils"

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
