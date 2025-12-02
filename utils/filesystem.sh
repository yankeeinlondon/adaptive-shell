#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__FILESYSTEM_SH_LOADED:-}" ]] && return
__FILESYSTEM_SH_LOADED=1

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

# file_exists <filepath>
#
# tests whether a given filepath exists in the filesystem
function file_exists() {
    local filepath="${1:?filepath is missing in call to file_exists!}"

    if [ -f "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}

# dir_exists <filepath>
#
# tests whether a given directory path exists in the filesystem
function dir_exists() {
    local filepath="${1:?filepath is missing}"

    if [ -d "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}

function ensure_directory() {
    local dirpath="${1:?no directory path passed to ensure_directory!}"

    if [ -d "${dirpath}" ]; then
        return 0;
    else
        mkdir "${dirpath}" || echo "Failed to make directory '${dirpath}'!" && exit 1
    fi
}

function has_file() {
    local -r filepath="${1:?no filepath passed to filepath()!}"

    if [ -f "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}


# validates that the current directory has a package.json file
function has_package_json() {
    local -r filepath="${PWD}/package.json"

    if [ -f "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}

# find_in_file <filepath> <key>
#
# Finds the first occurrence of <key> in the given file
# and if that line is the form "<key>=<value>" then
# it returns the <value>, otherwise it will return
# the line.
function find_in_file() {
    local -r filepath="${1:?find_in_file() called but no filepath passed in!}"
    local -r key="${2:?find_in_file() called but key value passed in!}"

    source "${UTILS}/logging.sh"
    source "${UTILS}/text.sh"

    if file_exists "${filepath}"; then
        debug "find_in_file(${filepath})" "file found"
        local found=""

        while read -r line; do
            if not_empty "${line}" && contains "${key}" "${line}"; then
                if starts_with "${key}=" "${line}"; then
                    found="$(strip_before "${key}=" "${line}")"
                else
                    found="${line}"
                fi
                break
            fi
        done < "$filepath"

        if not_empty "$found"; then
            debug "find_in_file" "found ${key}: ${found}"
            printf "%s" "$found"
            return 0
        else
            debug "find_in_file" "Did not find '${key}' in the file at '${filepath}'"
            echo ""
            return 0
        fi
    else
        debug "find_in_file" "no file at filepath"
        return 1
    fi
}



# get_file() <filepath>
#
# Gets the content from a file at the given <filepath>
function get_file() {
    local -r filepath="${1:?get_file() called but no filepath passed in!}"

    source "${UTILS}/logging.sh"

    if file_exists "${filepath}"; then
        debug "get_file(${filepath})" "getting data"
        local content
        { IFS= read -rd '' content <"${filepath}"; } 2>/dev/null || true
        printf '%s' "${content}"
    else
        debug "get_file(${filepath})" "call to get_file(${filepath}) had invalid filepath"
        return 1
    fi
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

