#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__LANG_RS_SH_LOADED:-}" ]] && declare -f "get_cargo_toml" > /dev/null && return
__LANG_RS_SH_LOADED=1

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

# get_cargo_toml()
#
# Attempts to read in content from Cargo.toml from current working
# directory and if that fails but the cwd is a repo then it will look
# for the Cargo.toml in the repo's root.
function get_cargo_toml() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/filesystem.sh"
    source "${UTILS}/detection.sh"
    local content

    if [[ -f "./Cargo.toml" ]]; then
        content=$(get_file "./Cargo.toml")
    elif is_git_repo "." && [[ -f "$(repo_root ".")/Cargo.toml" ]]; then
        content=$(get_file "$(repo_root ".")/Cargo.toml")
    else
        return 1
    fi

    echo "${content}"
    return 0
}

# _extract_toml_section <section_name>
#
# Helper function to extract a TOML section from stdin.
# Reads from the start of [section_name] until the next section or EOF.
_extract_toml_section() {
    local section="${1:?section name required}"
    local in_section=0
    local line

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check if we're entering our target section
        if [[ "$line" =~ ^\[${section}\]$ ]]; then
            in_section=1
            continue
        fi
        # Check if we're entering a different section (exit our section)
        if [[ "$line" =~ ^\[.*\]$ ]] && [[ $in_section -eq 1 ]]; then
            break
        fi
        # Output lines if we're in our section
        if [[ $in_section -eq 1 ]]; then
            echo "$line"
        fi
    done
}

# _has_toml_key <section_content> <key>
#
# Helper function to check if a key exists in TOML section content.
# Handles both inline format (key = "value") and table format (key = { ... })
_has_toml_key() {
    local content="$1"
    local key="${2:?key name required}"

    # Match either:
    # - key = "..." (inline string)
    # - key = { ... } (inline table)
    # - key.* = ... (dotted key)
    # Allow for optional whitespace around the equals sign
    if echo "$content" | grep -qE "^${key}[[:space:]]*="; then
        return 0
    fi
    return 1
}

# has_dependency <dep>
#
# Validates that `dep` exists in the [dependencies] section
# of Cargo.toml.
function has_dependency() {
    local -r dep="${1:?no crate sent into has_dependency()!}"

    local cargo_toml
    cargo_toml=$(get_cargo_toml) || return 1

    local section_content
    section_content=$(echo "$cargo_toml" | _extract_toml_section "dependencies")

    if _has_toml_key "$section_content" "$dep"; then
        return 0
    else
        return 1
    fi
}

# has_dev_dependency <dep>
#
# Validates that `dep` exists in the [dev-dependencies] section
# of Cargo.toml.
function has_dev_dependency() {
    local -r dep="${1:?no crate sent into has_dev_dependency()!}"

    local cargo_toml
    cargo_toml=$(get_cargo_toml) || return 1

    local section_content
    section_content=$(echo "$cargo_toml" | _extract_toml_section "dev-dependencies")

    if _has_toml_key "$section_content" "$dep"; then
        return 0
    else
        return 1
    fi
}

# has_build_dependency <dep>
#
# Validates that `dep` exists in the [build-dependencies] section
# of Cargo.toml.
function has_build_dependency() {
    local -r dep="${1:?no crate sent into has_build_dependency()!}"

    local cargo_toml
    cargo_toml=$(get_cargo_toml) || return 1

    local section_content
    section_content=$(echo "$cargo_toml" | _extract_toml_section "build-dependencies")

    if _has_toml_key "$section_content" "$dep"; then
        return 0
    else
        return 1
    fi
}

# has_dependency_anywhere <dep>
#
# Validates that `dep` exists in any dependency section
# of Cargo.toml (dependencies, dev-dependencies, or build-dependencies).
function has_dependency_anywhere() {
    local -r dep="${1:?no crate sent into has_dependency_anywhere()!}"

    if has_dependency "$dep" || has_dev_dependency "$dep" || has_build_dependency "$dep"; then
        return 0
    else
        return 1
    fi
}

# crates_not_installed <crate1> [crate2] ... OR crates_not_installed <array_name>
#
# Receives a list of crate names and returns only those which are not
# already in the project's Cargo.toml (checking dependencies,
# dev-dependencies, and build-dependencies).
#
# NOTE: Crate list can be passed in _by ref_ (array name) or _by value_ (direct args)
#   - By reference: modifies the array IN-PLACE to contain only not-installed crates
#   - By value: outputs not-installed crates to stdout (newline-separated)
#
# Examples:
#   # By value - capture output
#   result=$(crates_not_installed "serde" "tokio" "clap")
#
#   # By reference - modifies array in-place
#   my_crates=("serde" "tokio" "clap")
#   crates_not_installed my_crates
#   echo "${my_crates[@]}"  # Only contains crates not in Cargo.toml
function crates_not_installed() {
    local first_arg="${1:-}"

    # No arguments - return empty
    if [[ -z "$first_arg" ]]; then
        return 0
    fi

    # Check if first arg is an array name (pass-by-reference)
    # We detect this by: single argument that is a declared array
    if [[ $# -eq 1 ]] && declare -p "$first_arg" 2>/dev/null | grep -q '^declare -a'; then
        # It's an array reference - modify in-place using eval for Bash 3.x compatibility
        local not_installed=()
        local crate

        eval 'for crate in "${'"$first_arg"'[@]}"; do
            if ! has_dependency_anywhere "$crate"; then
                not_installed+=("$crate")
            fi
        done'

        # Modify the original array in-place using eval
        eval "$first_arg"'=("${not_installed[@]}")'
    else
        # Direct arguments (pass-by-value) - output to stdout
        local crate
        for crate in "$@"; do
            if ! has_dependency_anywhere "$crate"; then
                echo "$crate"
            fi
        done
    fi

    return 0
}

# get_rs_linter_by_config()
#
# Attempts to determine the linter being used on a Rust project
# by looking for the associated configuration file(s).
# Checks CWD first, then repo root if in a git repository.
# Priority order: clippy > dylint
function get_rs_linter_by_config() {
    source "${UTILS}/detection.sh"

    # Helper to check if any file from a list exists in a directory
    _check_config() {
        local search_dir="$1"
        shift
        local config_files=("$@")

        local cfg
        for cfg in "${config_files[@]}"; do
            if [[ -f "${search_dir}/${cfg}" ]]; then
                return 0
            fi
        done
        return 1
    }

    # Clippy config files
    local clippy_configs=("clippy.toml" ".clippy.toml")

    # Dylint config files
    local dylint_configs=("dylint.toml")

    # Directories to check: CWD first, then repo root if different
    local dirs_to_check=(".")
    local root
    if root=$(repo_root "." 2>/dev/null); then
        # Only add repo root if it's different from CWD
        if [[ "$(cd . && pwd)" != "${root}" ]]; then
            dirs_to_check+=("${root}")
        fi
    fi

    # Check each directory in order (CWD first, then repo root)
    local check_dir
    for check_dir in "${dirs_to_check[@]}"; do
        # Check in priority order: clippy > dylint
        if _check_config "${check_dir}" "${clippy_configs[@]}"; then
            echo "clippy"
            unset -f _check_config
            return 0
        fi

        if _check_config "${check_dir}" "${dylint_configs[@]}"; then
            echo "dylint"
            unset -f _check_config
            return 0
        fi
    done

    unset -f _check_config
    return 1
}

# get_rs_formatter_by_config()
#
# Attempts to determine the formatter being used on a Rust project
# by looking for the associated configuration file(s).
# Checks CWD first, then repo root if in a git repository.
function get_rs_formatter_by_config() {
    source "${UTILS}/detection.sh"

    # Helper to check if any file from a list exists in a directory
    _check_config() {
        local search_dir="$1"
        shift
        local config_files=("$@")

        local cfg
        for cfg in "${config_files[@]}"; do
            if [[ -f "${search_dir}/${cfg}" ]]; then
                return 0
            fi
        done
        return 1
    }

    # Rustfmt config files
    local rustfmt_configs=("rustfmt.toml" ".rustfmt.toml")

    # Directories to check: CWD first, then repo root if different
    local dirs_to_check=(".")
    local root
    if root=$(repo_root "." 2>/dev/null); then
        # Only add repo root if it's different from CWD
        if [[ "$(cd . && pwd)" != "${root}" ]]; then
            dirs_to_check+=("${root}")
        fi
    fi

    # Check each directory in order (CWD first, then repo root)
    local check_dir
    for check_dir in "${dirs_to_check[@]}"; do
        if _check_config "${check_dir}" "${rustfmt_configs[@]}"; then
            echo "rustfmt"
            unset -f _check_config
            return 0
        fi
    done

    unset -f _check_config
    return 1
}

# is_cargo_workspace()
#
# Checks if the current project is a Cargo workspace by looking for
# a [workspace] section in Cargo.toml.
# Checks CWD first, then repo root if in a git repository.
function is_cargo_workspace() {
    source "${UTILS}/detection.sh"

    local cargo_toml

    # Try CWD first
    if [[ -f "./Cargo.toml" ]]; then
        cargo_toml=$(cat "./Cargo.toml")
        if echo "$cargo_toml" | grep -qE '^\[workspace\]'; then
            return 0
        fi
    fi

    # Try repo root if in a git repo
    if is_git_repo "."; then
        local root
        root=$(repo_root ".")
        if [[ -f "${root}/Cargo.toml" ]]; then
            cargo_toml=$(cat "${root}/Cargo.toml")
            if echo "$cargo_toml" | grep -qE '^\[workspace\]'; then
                return 0
            fi
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
