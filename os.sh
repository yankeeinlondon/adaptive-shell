#!/usr/bin/env bash

# os
# 
# Will try to detect the operating system of the host computer
# where options are: darwin, linux, windowsnt, 
function os() {
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

# distro_version() <[vmid]>
#
# will try to detect the linux distro's version id and name 
# of the host computer or the <vmid> if specified.
function distro_version() {
    local -r vm_id="$1:-"

    if [[ $(os "$vm_id") == "linux" ]]; then
        if file_exists "/etc/os-release"; then
            local -r id="$(find_in_file "VERSION_ID=" "/etc/os-release")"
            local -r codename="$(find_in_file "VERSION_CODENAME=" "/etc/os-release")"
            echo "${id}/${codename}"
            return 0
        fi
    else
        error "Called distro() on a non-linux OS [$(os "$vm_id")]!"
    fi
}

# distro()
#
# will try to detect the linux distro of the host computer
# or the <vmid> if specified.
function distro() {

        if file_exists "/etc/os-release"; then
            local -r name="$(find_in_file "ID=" "/etc/os-release")" || "$(find_in_file "NAME=" "/etc/os-release")"

            echo "${name}"
            return 0
        fi

}
