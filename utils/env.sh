#!/usr/bin/env bash

# Source guard - prevents re-execution when sourced multiple times
[[ -n "${__ENV_SH_LOADED:-}" ]] && return
__ENV_SH_LOADED=1

# append_to_path <path>
#
# Appends the path passed in to the PATH env variable
# and re-exports PATH
function append_to_path() {
    local -r new="${1:?No path passed into append_to_path()!}"
    local -r current="${PATH:-}"
    local -r newPath="${current};${new}"

    export PATH="${newPath}"
    echo "${newPath}"
}

# has_path()
#
# checks whether the passed in path already exists in $PATH
# variable
function has_path() {
    local -r find="${1:?no path passed into has_path()!}"

    if contains "${find}" "${PATH:- }"; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}
