#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__FILESYSTEM_SH_LOADED:-}" ]] && declare -f "file_exists" > /dev/null && return
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

# join <segment_a> <segment_b>
#
# Joins two path segments together in a valid manner for macOS, Linux, or Windows.
# Handles trailing/leading slashes and empty segments properly.
function join() {
    local a="${1:-}"
    local b="${2:-}"

    # Handle empty segments
    if [[ -z "$a" ]]; then
        printf '%s' "$b"
        return 0
    fi
    if [[ -z "$b" ]]; then
        printf '%s' "$a"
        return 0
    fi

    # Remove trailing slashes from first segment
    while [[ "$a" == */ ]]; do
        a="${a%/}"
    done

    # Remove leading slashes from second segment
    while [[ "$b" == /* ]]; do
        b="${b#/}"
    done

    # Join with single slash
    printf '%s/%s' "$a" "$b"
}

# absolute_path <path>
#
# Ensures that the path passed in is an absolute path.
# If the path is relative, attempts to resolve it using:
# 1. Current working directory (PWD)
# 2. Repository root (repo_root)
# Returns error if path cannot be resolved.
function absolute_path() {
    local path="${1:?no path passed to absolute_path()!}"

    # shellcheck source="./detection.sh"
    source "${UTILS}/detection.sh"
    # shellcheck source="./logging.sh"
    source "${UTILS}/logging.sh"

    # If already absolute, validate and return
    if [[ "$path" == /* ]] || [[ "$path" == \\* ]]; then
        if [[ -e "$path" ]]; then
            printf '%s' "$path"
            return 0
        else
            error "absolute_path: path '${path}' does not exist" 1
            return 1
        fi
    fi

    # Try joining with PWD
    local pwd_path
    pwd_path="$(join "${PWD}" "${path}")"
    if [[ -e "$pwd_path" ]]; then
        printf '%s' "$pwd_path"
        return 0
    fi

    # Try joining with repo_root
    local root_path
    local repo
    repo="$(repo_root 2>/dev/null)" || true

    if [[ -n "$repo" ]]; then
        root_path="$(join "$repo" "${path}")"
        if [[ -e "$root_path" ]]; then
            printf '%s' "$root_path"
            return 0
        fi
    fi

    # Path could not be resolved
    error "absolute_path: cannot resolve path '${path}' (tried PWD and repo_root)" 1
    return 1
}

# relative_path <path>
#
# Converts an absolute or relative path to be relative to the current working directory.
# If the path is already relative, validates and returns it.
# If the path is absolute, computes the relative path from PWD.
function relative_path() {
    local path="${1:?no path passed to relative_path()!}"

    # shellcheck source="./logging.sh"
    source "${UTILS}/logging.sh"

    # If path doesn't exist, try to resolve it first
    if [[ ! -e "$path" ]]; then
        # Try to resolve as absolute first
        path="$(absolute_path "$path" 2>/dev/null)" || {
            error "relative_path: path '${1}' does not exist and cannot be resolved" 1
            return 1
        }
    fi

    # If path is already relative, return it
    if [[ "$path" != /* ]] && [[ "$path" != \\* ]]; then
        printf '%s' "$path"
        return 0
    fi

    # Manual relative path computation that works everywhere
    local abs_path abs_pwd

    # Get absolute path of the target (resolve symlinks and normalize)
    if [[ -d "$path" ]]; then
        abs_path="$(cd "$path" && pwd)"
    else
        abs_path="$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi

    # Get absolute PWD (resolve symlinks)
    abs_pwd="$(pwd)"

    # If paths are identical, return "."
    if [[ "$abs_path" == "$abs_pwd" ]]; then
        printf '.'
        return 0
    fi

    # Find common prefix by iterating through path components
    local IFS='/'
    local -a pwd_parts=($abs_pwd)
    local -a path_parts=($abs_path)

    # Find where paths diverge
    local common_idx=0
    local max_idx=${#pwd_parts[@]}
    [[ ${#path_parts[@]} -lt $max_idx ]] && max_idx=${#path_parts[@]}

    for ((i=0; i<max_idx; i++)); do
        if [[ "${pwd_parts[$i]}" == "${path_parts[$i]}" ]]; then
            common_idx=$((i + 1))
        else
            break
        fi
    done

    # Build relative path
    local rel_path=""

    # Add ../ for each remaining PWD component
    local up_count=$((${#pwd_parts[@]} - common_idx))
    for ((i=0; i<up_count; i++)); do
        rel_path="${rel_path}../"
    done

    # Add remaining path components
    for ((i=common_idx; i<${#path_parts[@]}; i++)); do
        if [[ -n "${path_parts[$i]}" ]]; then
            rel_path="${rel_path}${path_parts[$i]}/"
        fi
    done

    # Remove trailing slash
    rel_path="${rel_path%/}"

    # If empty, return "."
    if [[ -z "$rel_path" ]]; then
        printf '.'
    else
        printf '%s' "$rel_path"
    fi
}

# get_file_path <filename>
#
# Searches for a file by name (without directory path) in the following order:
# 1. Current working directory
# 2. Repository root (if in a git repo)
# 3. Subdirectories of current working directory (up to depth 5 for performance)
# Returns the absolute path if found, error if not found.
function get_file_path() {
    local filename="${1:?no filename passed to get_file_path()!}"

    # shellcheck source="./detection.sh"
    source "${UTILS}/detection.sh"
    # shellcheck source="./logging.sh"
    source "${UTILS}/logging.sh"

    # Remove any directory components from input (just in case)
    filename="$(basename "$filename")"

    # Check current working directory first
    if [[ -f "${PWD}/${filename}" ]]; then
        printf '%s' "${PWD}/${filename}"
        return 0
    fi

    # Check repository root if in a git repo
    if is_git_repo "${PWD}"; then
        local root
        root="$(repo_root "${PWD}")"
        if [[ -f "${root}/${filename}" ]]; then
            printf '%s' "${root}/${filename}"
            return 0
        fi
    fi

    # Search subdirectories of PWD (limited depth for performance)
    local found
    found="$(find "${PWD}" -maxdepth 5 -type f -name "${filename}" -print -quit 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
        printf '%s' "${found}"
        return 0
    fi

    # File not found
    error "get_file_path: file '${filename}' not found in PWD, repo root, or subdirectories" 1
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

