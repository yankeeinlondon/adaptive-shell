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
