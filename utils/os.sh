#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__OS_SH_LOADED:-}" ]] && declare -f "os" > /dev/null && return
__OS_SH_LOADED=1

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


# os
#
# Will try to detect the operating system of the host computer
# where options are: darwin, linux, windowsnt,
function os() {
    # shellcheck source="./text.sh"
    source "${UTILS}/text.sh"

    local -r os_type=$(lc "${OSTYPE}") || "$(lc "$(uname)")" || "unknown"
    case "$os_type" in
        'linux'*)
           echo "linux"
          ;;
        'freebsd'*)
          echo "freebsd"
          ;;
        'windowsnt'*)
          echo "windows"
          ;;
        'darwin'*)
          echo "macos"
          ;;
        'sunos'*)
          echo "solaris"
          ;;
        'aix'*)
          echo "aix"
          ;;
        *) echo "unknown/${os_type}"
    esac
}

function is_os() {
  local -r test="${1:?test value for is_os is missing}"

  if [[ "$(os)" == "${test}" ]]; then
    return 0;
  else
    return 1;
  fi
}


function is_mac() {
    [[ $(uname -s) == Darwin* ]];
}

function is_windows() {
    [[ $(uname -s) == CYGWIN* || $(uname -s) == MINGW* ]] || command -v cmd.exe &>/dev/null;
}

# is_wsl
#
# Returns true if running inside Windows Subsystem for Linux
function is_wsl() {
    [[ -f /proc/version ]] && grep -qi microsoft /proc/version
}

function get_kernel_version() {
    uname -r
}

function get_storage() {
    if is_linux; then
        df --output="source" --output="fstype" --output="avail" --output="pcent" --exclude-type="tmpfs" -h --exclude-type="devtmpfs"

    elif is_mac; then
        df -P -h -a | grep -vE 'TimeMachine|backupdb|^(devfs|autofs|map|localhost:) ' | \
        awk 'BEGIN {print "Filesystem\tType\tUse%\tAvail\tMounted on"}
            NR>1 {
                # Reconstruct mount point
                mount_point = $6
                for(i=7; i<=NF; i++) mount_point = mount_point " " $i

                # Get filesystem type using stat (fast and reliable)
                fstype = "unknown"
                if (system("test -d \"" mount_point "\"") == 0) {
                    cmd = "stat -f %T \"" mount_point "\" 2>/dev/null"
                    cmd | getline fstype
                    close(cmd)
                }

                # Network filesystem detection
                if ($1 ~ /^\/\//) fstype = "smb"
                if ($1 ~ /^\/dev\//) fstype = "apfs"
                if ($1 ~ /^\/Applications\//) fstype = "unknown"
                if ($1 ~ /^[a-zA-Z0-9.]+:\//) fstype = "nfs"

                # Truncate fields
                fs = length($1) > 30 ? substr($1,1,27) "..." : $1
                mnt = length(mount_point) > 35 ? substr(mount_point,1,37) "..." : mount_point

                printf "%s\t%s\t%s\t%s\t%s\n", fs, fstype, $5, $4, mnt
            }' | \
        column -t -s $'\t'

    elif is_windows; then
        powershell.exe -Command "\
            Get-Volume | Where-Object {\$_.DriveType -eq 'Fixed'} | \
            ForEach-Object {
                \$free = [math]::Round(\$_.SizeRemaining / 1GB, 2)
                \$total = [math]::Round(\$_.Size / 1GB, 2)
                \$used = \$total - \$free
                \$pct = if (\$total -gt 0) { [math]::Round((\$used / \$total) * 100) } else { 0 }
                [PSCustomObject]@{
                    Filesystem = \$_.FileSystemType
                    Drive = \$_.DriveLetter + ':'
                    'Size(GB)' = \$total
                    'Free(GB)' = \$free
                    'Use%' = \"\$pct%\"
                }
            }" | \
        awk 'BEGIN {print "Filesystem Type Use% Avail Mounted_on"}
            NR>1 {
                gsub(/\\r/,"");
                printf "%s %s %s %.1fG %s\n", $3, $1, $5, $4, $2
            }' | \
        column -t
    else
        echo "Unsupported operating system"
        return 1
    fi
}

# get_shell()
#
# gets the active shell program running inside of
function get_shell() {
    local shell
    # Get shell name, remove leading dash (login shell), extract basename
    shell=$(ps -p $$ -o comm= | sed 's/^-//')
    shell="${shell##*/}"  # Extract basename (e.g., /bin/zsh -> zsh)
    [ "$shell" = "sh" ] && {
        # Check for POSIX-compliant modes of different shells
        [ -n "$BASH_VERSION" ] && shell=bash
        [ -n "$ZSH_VERSION" ] && shell=zsh
        [ -n "$FISH_VERSION" ] && shell=fish
        [ -n "$NUSHELL_VERSION" ] && shell=nu
    }
    # Fallback to SHELL environment variable if detection fails
    [ "$shell" = "sh" ] && [ -n "$SHELL" ] && {
        case "$SHELL" in
            */bash) shell=bash ;;
            */zsh) shell=zsh ;;
            */fish) shell=fish ;;
            */nu) shell=nu ;;
        esac
    }
    # Default to bash if still sh
    [ "$shell" = "sh" ] && shell=bash
    echo "$shell"
}



# isMacOrLinux()
#
# Returns `true` if current OS is macOS or Linux
function isMacOrLinux() {
    local -r os="$(os)";

    if [[ "${os}" == "linux" ]]; then
        return 0;
    elif [[ "${os}" == "macos" ]]; then
        return 0;
    else
        return 1;
    fi
}

function is_linux() {
    local -r os="$(os)";

    if [[ "${os}" == "linux" ]]; then
        return 0;
    else
        return 1;
    fi
}

# distro()
#
# will try to detect the distro and version of the os release
function distro() {
    if [[ $(os) == "linux" ]]; then
        # Check /etc/os-release
        if [ -f /etc/os-release ]; then
        local name version
        name=$(grep '^NAME=' /etc/os-release | cut -d= -f2- | sed 's/"//g')
        version=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2- | sed 's/"//g')
        if [ -n "$name" ]; then
            if [ -n "$version" ]; then
            echo "$name/$version"
            else
            echo "$name/unknown"
            fi
            return
        fi
        fi

        # Check /etc/lsb-release
        if [ -f /etc/lsb-release ]; then
        local dist_id dist_release
        dist_id=$(grep '^DISTRIB_ID=' /etc/lsb-release | cut -d= -f2- | sed 's/"//g')
        dist_release=$(grep '^DISTRIB_RELEASE=' /etc/lsb-release | cut -d= -f2- | sed 's/"//g')
        if [ -n "$dist_id" ]; then
            if [ -n "$dist_release" ]; then
            echo "$dist_id/$dist_release"
            else
            echo "$dist_id/unknown"
            fi
            return
        fi
        fi

        # Check Debian
        if [ -f /etc/debian_version ]; then
        local version
        version=$(cat /etc/debian_version)
        echo "Debian/$version"
        return
        fi

        # Check Red Hat-based systems
        if [ -f /etc/redhat-release ]; then
        local content name version
        content=$(cat /etc/redhat-release)
        name=$(awk '{sub(/ release.*/, ""); print}' <<< "$content")
        version=$(awk '{for(i=1; i<=NF; i++) if ($i == "release") {print $(i+1); exit}}' <<< "$content")
        if [ -z "$version" ]; then
            version="unknown"
        fi
        echo "$name/$version"
        return
        fi

        # Check Alpine
        if [ -f /etc/alpine-release ]; then
        local version
        # shellcheck disable=SC2002
        version=$(cat /etc/alpine-release | tr -d '\n')
        echo "Alpine/$version"
        return
        fi

        # Check Arch Linux
        if [ -f /etc/arch-release ]; then
        echo "Arch Linux/unknown"
        return
        fi

        # Check Slackware
        if [ -f /etc/slackware-version ]; then
        local content name version
        content=$(cat /etc/slackware-version)
        name=$(awk '{print $1}' <<< "$content")
        version=$(awk '{print $2}' <<< "$content")
        echo "$name/$version"
        return
        fi

        # Check Gentoo
        if [ -f /etc/gentoo-release ]; then
        local version
        version=$(awk '{print $NF}' /etc/gentoo-release)
        echo "Gentoo/$version"
        return
        fi

        # Fallback if no known distro detected
        echo "unknown/unknown"
    else
        return 1
    fi
}

# os_version()
#
# Detect and return the OS version for Linux, macOS, and Windows
function os_version() {
    case $(os) in
        linux)
            local distro_output
            distro_output=$(distro)
            local version="${distro_output##*/}"

            # Handle Arch Linux's special case
            if [[ "$version" == "unknown" && "$distro_output" == *"Arch Linux/"* ]]; then
                if [ -f /etc/arch-release ]; then
                    version=$(date -r /etc/arch-release "+%Y.%m.%d")
                fi
            fi
            echo "$version"
            ;;
        macos)
            sw_vers -productVersion
            ;;
        windows)
            local ver_output version
            # Get Windows version from cmd.exe
            ver_output=$(cmd.exe /c ver 2>/dev/null)
            # shellcheck disable=SC2181
            if [[ $? -ne 0 ]]; then
                echo "unknown"
                return 1
            fi
            # Extract version from output format: "Microsoft Windows [Version 10.0.19045.4291]"
            version=$(echo "$ver_output" | awk '{print $4}' | tr -d ']')
            if [[ -z "$version" ]]; then
                echo "unknown"
                return 1
            fi
            echo "$version"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}



# Function to get the number of CPUs/threads
get_cpu_count() {
    local os
    os="$(uname)"
    case "$os" in
        Linux)
            if command -v nproc &>/dev/null; then
                nproc
            else
                # Fallback if nproc is not available.
                grep -c ^processor /proc/cpuinfo
            fi
            ;;
        Darwin)
            # macOS
            sysctl -n hw.ncpu
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows (in Git Bash, MSYS, or Cygwin)
            # WMIC output typically contains a header line, so we filter it.
            if command -v WMIC &>/dev/null; then
                WMIC CPU Get NumberOfLogicalProcessors | grep -Eo '[0-9]+' | head -n1
            else
                echo "WMIC command not found. Are you sure you're running in a Windows environment with WMIC available?" >&2
                return 1
            fi
            ;;
        *)
            echo "Unsupported OS: $os" >&2
            return 1
            ;;
    esac
}

get_systemd_units() {
    local filters=("$@")

    if has_command "systemctl"; then
        # Retrieve the list of running service units (removing the .service suffix)
        # shellcheck disable=SC2207
        service_units=( $(systemctl list-units --type=service --state=running --no-legend \
                        | awk '{print $1}' \
                        | sed 's/\.service$//') )

        # If filters were provided, filter out any unit that contains any of them.
        if (( ${#filters[@]} > 0 )); then
            filtered_units=()
            for unit in "${service_units[@]}"; do
                exclude=false
                for filter in "${filters[@]}"; do
                    if [[ $unit == *"$filter"* ]]; then
                        exclude=true
                        break
                    fi
                done
                if ! $exclude; then
                    filtered_units+=("$unit")
                fi
            done
            service_units=( "${filtered_units[@]}" )
        fi
    else
        echo ""
    fi
    echo "${service_units[@]}"
}

get_launchd_units() {
    # Capture all provided filter conditions
    local filters=("$@")

    # shellcheck disable=SC2207
    units=( $(launchctl list | tail -n +2 | awk '{print $3}' | sed 's/^com\.apple\.//') )

    # If filters were provided, filter out any unit that contains any of them.
    if (( ${#filters[@]} > 0 )); then
        filtered_units=()
        for unit in "${units[@]}"; do
            exclude=false
            for filter in "${filters[@]}"; do
                if [[ $unit == *"$filter"* ]]; then
                    exclude=true
                    break
                fi
            done
            if ! $exclude; then
                filtered_units+=("$unit")
            fi
        done
        units=( "${filtered_units[@]}" )
    fi

    echo "${units[@]}"
}

get_alpine_services() {
    # Capture all provided filter conditions.
    local filters=("$@")

    # Get the list of running services:
    # - rc-status prints runlevel info and service statuses.
    # shellcheck disable=SC2207
    services=( $(rc-status | grep "\[.*started" | awk '{print $1}') )

    # If filters were provided, exclude any service whose name contains any of them.
    if (( ${#filters[@]} > 0 )); then
        filtered_services=()
        for service in "${services[@]}"; do
            exclude=false
            for filter in "${filters[@]}"; do
                if [[ $service == *"$filter"* ]]; then
                    exclude=true
                    break
                fi
            done
            if ! $exclude; then
                filtered_services+=( "$service" )
            fi
        done
        services=( "${filtered_services[@]}" )
    fi

    echo "${services[@]}"
}

# Function to get the CPU family/model name
get_cpu_family() {
    local os
    os="$(uname)"
    case "$os" in
        Linux)
            # Extract the model name from the first processor entry in /proc/cpuinfo
            grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^[ \t]*//'
            ;;
        Darwin)
            # macOS: use sysctl to get the brand string
            sysctl -n machdep.cpu.brand_string
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Windows: use WMIC to get the CPU name (family)
            if command -v WMIC &>/dev/null; then
                WMIC CPU Get Name | sed '1d' | head -n1 | sed 's/^[ \t]*//'
            else
                echo "WMIC command not found. Are you sure you're running in a Windows environment with WMIC available?" >&2
                return 1
            fi
            ;;
        *)
            echo "Unsupported OS: $os" >&2
            return 1
            ;;
    esac
}

# get_firmware()
#
# Gets the system firmware version
function get_firmware() {
    case $(os) in
        linux)
            if [ -f /sys/class/dmi/id/bios_version ]; then
                cat /sys/class/dmi/id/bios_version
            elif command -v dmidecode >/dev/null; then
                dmidecode -s bios-version 2>/dev/null || echo "unknown"
            else
                echo "unknown"
            fi
            ;;
        macos)
            system_profiler SPHardwareDataType | awk -F': ' '/Boot ROM Version/ {print $2}'
            ;;
        windows)
            cmd.exe /c "wmic bios get version" 2>/dev/null | awk 'NR==2 {print $1}' | tr -d '\r'
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

# get_memory()
#
# Gets total physical memory in GB (rounded to 2 decimal places)
function get_memory() {
    case $(os) in
        linux)
            if [ -f /proc/meminfo ]; then
                awk '/MemTotal/ {printf "%.2f", $2/1024/1024}' /proc/meminfo
            else
                echo "unknown"
            fi
            ;;
        macos)
            sysctl -n hw.memsize | awk '{printf "%.2f", $0/1024/1024/1024}'
            ;;
        windows)
            local -r mem_bytes=$(wmic ComputerSystem get TotalPhysicalMemory 2>/dev/null | awk 'NR==2 {print $1}')
            if [ -n "$mem_bytes" ]; then
                echo "$mem_bytes" | awk '{printf "%.2f", $0/1024/1024/1024}'
            else
                # Fallback to PowerShell command
                powershell.exe -Command "[math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)"
            fi
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

function is_debian() {
    if is_linux; then
        local distro_name
        distro_name="$(distro)"
        local lc_distro
        lc_distro="$(echo "${distro_name}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${lc_distro}" == *"debian"* ]]; then
            return 0
        fi
    fi
    return 1
}

function is_ubuntu() {
    if is_linux; then
        local distro_name
        distro_name="$(distro)"
        local lc_distro
        lc_distro="$(echo "${distro_name}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${lc_distro}" == *"ubuntu"* ]]; then
            return 0
        fi
    fi
    return 1
}

function is_alpine() {
    if is_linux; then
        local distro_name
        distro_name="$(distro)"
        local lc_distro
        lc_distro="$(echo "${distro_name}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${lc_distro}" == *"alpine"* ]]; then
            return 0
        fi
    fi
    return 1
}

# is_fedora
#
# Returns true if running on Fedora, RHEL, CentOS, Rocky Linux, or AlmaLinux
function is_fedora() {
    if is_linux; then
        local distro_name
        distro_name="$(distro)"
        local lc_distro
        lc_distro="$(echo "${distro_name}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${lc_distro}" == *"fedora"* ]] || \
           [[ "${lc_distro}" == *"rhel"* ]] || \
           [[ "${lc_distro}" == *"red hat"* ]] || \
           [[ "${lc_distro}" == *"centos"* ]] || \
           [[ "${lc_distro}" == *"rocky"* ]] || \
           [[ "${lc_distro}" == *"alma"* ]]; then
            return 0
        fi
    fi
    return 1
}

# is_arch
#
# Returns true if running on Arch Linux, Manjaro, or EndeavourOS
function is_arch() {
    if is_linux; then
        local distro_name
        distro_name="$(distro)"
        local lc_distro
        lc_distro="$(echo "${distro_name}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${lc_distro}" == *"arch"* ]] || \
           [[ "${lc_distro}" == *"manjaro"* ]] || \
           [[ "${lc_distro}" == *"endeavouros"* ]] || \
           [[ "${lc_distro}" == *"endeavour"* ]]; then
            return 0
        fi
    fi
    return 1
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
