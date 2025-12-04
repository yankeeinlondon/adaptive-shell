#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__LANG_JS_SH_LOADED:-}" ]] && declare -f "file_exists" > /dev/null && return
__LANG_JS_SH_LOADED=1

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

# get_package_json()
#
# attempts to read in content from package.json from current working
# directory and if that fails but the cwd is a repo then it will look
# for the package.json in the repo's root.
function get_package_json() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/filesystem.sh"
    local content
    if [[ -f "./package.json" ]]; then
        content=$(get_file "./package.json")
    elif [[ -f "$(repo_root ".")/package.json" ]]; then
        content=$(get_file "$(repo_root ".")/package.json")
    else
        return 1
    fi

    echo "${content}"
    return 0
}

# has_dev_dependency <dep>
#
# Validates that `dep` exists in the "devDependencies" section
# of `package.json`.
function has_dev_dependency() {
    local -r dep="${1:?no package sent into has_dev_dependency()!}"

    source "${UTILS}/install.sh"
    ensure_install "jq" "install_jq"

    local pkg_json
    pkg_json=$(get_package_json) || return 1

    if echo "${pkg_json}" | jq -e ".devDependencies | has(\"${dep}\")" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# has_dependency <dep>
#
# Validates that `dep` exists in the "dependencies" section
# of `package.json`.
function has_dependency() {
    local -r dep="${1:?no package sent into has_dependency()!}"

    source "${UTILS}/install.sh"
    ensure_install "jq" "install_jq"

    local pkg_json
    pkg_json=$(get_package_json) || return 1

    if echo "${pkg_json}" | jq -e ".dependencies | has(\"${dep}\")" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# has_peer_dependency <dep>
#
# Validates that `dep` exists in the "peerDependencies" section
# of `package.json`.
function has_peer_dependency() {
    local -r dep="${1:?no package sent into has_peer_dependency()!}"

    source "${UTILS}/install.sh"
    ensure_install "jq" "install_jq"

    local pkg_json
    pkg_json=$(get_package_json) || return 1

    if echo "${pkg_json}" | jq -e ".peerDependencies | has(\"${dep}\")" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

function has_dependency_anywhere() {
    local -r dep="${1:?no package sent into has_dependency_anywhere()!}"

    if has_dependency "${dep}" || has_dev_dependency "${dep}" || has_peer_dependency "${dep}"; then
        return 0;
    else
        return 1;
    fi
}

# get_js_linter_by_dep()
#
# attempts to determine the linter being used on a JS/TS
# project by looking in the devDependencies.
function get_js_linter_by_dep() {
    source "${UTILS}/logging.sh"

    # Priority: oxlint > eslint > tsslint > biome > tslint
    if has_dev_dependency "oxlint"; then
        echo "oxlint"
        return 0
    elif has_dev_dependency "eslint"; then
        echo "eslint"
        return 0
    elif has_dev_dependency "tsslint"; then
        echo "tsslint"
        return 0
    elif has_dev_dependency "@biomejs/biome" || has_dev_dependency "biome"; then
        echo "biome"
        return 0
    elif has_dev_dependency "tslint"; then
        echo "tslint"
        return 0
    elif has_dependency "oxlint"; then
        logc "{{BOLD}}{{YELLOW}}WARN:{{RESET}} found {{BLUE}}oxlint{{RESET}} in dependencies! This is probably a mistake, consider moving to {{BLUE}}devDependencies{{RESET}} instead."
        echo "oxlint"
        return 0
    elif has_dependency "eslint"; then
        logc "{{BOLD}}{{YELLOW}}WARN:{{RESET}} found {{BLUE}}eslint{{RESET}} in dependencies! This is probably a mistake, consider moving to {{BLUE}}devDependencies{{RESET}} instead."
        echo "eslint"
        return 0
    elif has_dependency "tsslint"; then
        logc "{{BOLD}}{{YELLOW}}WARN:{{RESET}} found {{BLUE}}tsslint{{RESET}} in dependencies! This is probably a mistake, consider moving to {{BLUE}}devDependencies{{RESET}} instead."
        echo "tsslint"
        return 0
    elif has_dependency "@biomejs/biome" || has_dependency "biome"; then
        logc "{{BOLD}}{{YELLOW}}WARN:{{RESET}} found {{BLUE}}@biomejs/biome{{RESET}} in dependencies! This is probably a mistake, consider moving to {{BLUE}}devDependencies{{RESET}} instead."
        echo "biome"
        return 0
    elif has_dependency "tslint"; then
        logc "{{BOLD}}{{YELLOW}}WARN:{{RESET}} found {{BLUE}}tslint{{RESET}} in dependencies! This is probably a mistake, consider moving to {{BLUE}}devDependencies{{RESET}} instead."
        echo "tslint"
        return 0
    else
        return 1
    fi
}

# get_js_linter_by_config_file()
#
# attempts to determine the linter being used on a JS/TS
# project by looking for the associated configuration file(s).
# Checks CWD first, then repo root if in a git repository.
# Priority order: oxlint > eslint > biome > tsslint > tslint
function get_js_linter_by_config_file() {
    source "${UTILS}/detection.sh"

    # Helper to check if any file from a list exists in a directory
    _check_linter_config() {
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

    # ESLint config files (flat config + legacy)
    local eslint_configs=(
        "eslint.config.js" "eslint.config.mjs" "eslint.config.cjs"
        "eslint.config.ts" "eslint.config.mts" "eslint.config.cts"
        ".eslintrc.js" ".eslintrc.cjs" ".eslintrc.yaml" ".eslintrc.yml"
        ".eslintrc.json" ".eslintrc"
    )

    # Oxlint config files
    local oxlint_configs=(".oxlintrc.json" "oxlint.json")

    # Biome config files
    local biome_configs=("biome.json" "biome.jsonc")

    # TSSLint config files
    local tsslint_configs=("tsslint.config.ts" "tsslint.config.js")

    # TSLint config files (deprecated)
    local tslint_configs=("tslint.json" "tslint.yaml" "tslint.yml")

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
        # Check in priority order: oxlint > eslint > biome > tsslint > tslint
        if _check_linter_config "${check_dir}" "${oxlint_configs[@]}"; then
            echo "oxlint"
            unset -f _check_linter_config
            return 0
        fi

        if _check_linter_config "${check_dir}" "${eslint_configs[@]}"; then
            echo "eslint"
            unset -f _check_linter_config
            return 0
        fi

        if _check_linter_config "${check_dir}" "${biome_configs[@]}"; then
            echo "biome"
            unset -f _check_linter_config
            return 0
        fi

        if _check_linter_config "${check_dir}" "${tsslint_configs[@]}"; then
            echo "tsslint"
            unset -f _check_linter_config
            return 0
        fi

        if _check_linter_config "${check_dir}" "${tslint_configs[@]}"; then
            echo "tslint"
            unset -f _check_linter_config
            return 0
        fi
    done

    unset -f _check_linter_config
    return 1
}

# packages_not_installed <pkg1> [pkg2] ... OR packages_not_installed <array_name>
#
# Receives a list of package names and returns only those which are not
# already installed in the project's package.json (checking dependencies,
# devDependencies, and peerDependencies).
#
# NOTE: Package list can be passed in _by ref_ (array name) or _by value_ (direct args)
#   - By reference: modifies the array IN-PLACE to contain only not-installed packages
#   - By value: outputs not-installed packages to stdout (newline-separated)
#
# Examples:
#   # By value - capture output
#   result=$(packages_not_installed "lodash" "express" "react")
#
#   # By reference - modifies array in-place
#   my_pkgs=("lodash" "express" "react")
#   packages_not_installed my_pkgs
#   echo "${my_pkgs[@]}"  # Only contains packages not in package.json
function packages_not_installed() {
    local first_arg="${1:-}"

    # No arguments - return empty
    if [[ -z "$first_arg" ]]; then
        return 0
    fi

    # Check if first arg is an array name (pass-by-reference)
    # We detect this by: single argument that is a declared array
    if [[ $# -eq 1 ]] && declare -p "$first_arg" 2>/dev/null | grep -q '^declare -a'; then
        # It's an array reference - modify in-place
        local -n arr_ref="$first_arg"
        local not_installed=()
        local pkg

        for pkg in "${arr_ref[@]}"; do
            if ! has_dependency_anywhere "$pkg"; then
                not_installed+=("$pkg")
            fi
        done

        # Modify the original array in-place
        arr_ref=("${not_installed[@]}")
    else
        # Direct arguments (pass-by-value) - output to stdout
        local pkg
        for pkg in "$@"; do
            if ! has_dependency_anywhere "$pkg"; then
                echo "$pkg"
            fi
        done
    fi

    return 0
}


# js_package_manager
#
# Returns the JS/TS package being used in this repo:
#   - returns error code if this is NOT a JS/TS project directory
#   - on success returns "npm", "yarn", "pnpm", "bun", or "deno"
#   - if unable to determine (but it IS a JS/TS project directory) then will nothing but
#     exit code will be successful
function js_package_manager() {
    source "${UTILS}/detection.sh"

    if looks_like_js_project; then
        if [[ -f "./package.json" ]]; then
            if [[ -f "./pnpm-lock.yaml" ]] ||  [[ -f "./pnpm-workspace.yaml" ]]; then
                echo "pnpm"
                return 0
            elif [[ -f "./package-lock.json" ]]; then
                echo "npm"
                return 0
            elif [[ -f "./yarn.lock" ]]; then
                echo "yarn"
                return 0
            elif [[ -f "./bun.lockb" ]]; then
                echo "bun"
                return 0
            elif [[ -f "./deno.lock" ]]; then
                echo "deno"
                return 0
            else
                return 0
            fi
        else
            # repo root must be in parent dir
            local -r dir="$(repo_root ".")"
            if [[ -f "${dir}/pnpm-lock.yaml" ]] ||  [[ -f "${dir}/pnpm-workspace.yaml" ]]; then
                echo "pnpm"
                return 0
            elif [[ -f "${dir}/package-lock.json" ]]; then
                echo "npm"
                return 0
            elif [[ -f "${dir}/yarn.lock" ]]; then
                echo "yarn"
                return 0
            elif [[ -f "${dir}/bun.lockb" ]]; then
                echo "bun"
                return 0
            elif [[ -f "${dir}/deno.lock" ]]; then
                echo "deno"
                return 0
            else
                return 0
            fi
        fi
    else
        return 1
    fi
}

# install_js_linter_config() <[linter]>
#
# Copies a linter configuration template from the "resources" directory
# to the project directory (where package.json is located) if:
# 1. A supported linter is detected or specified
# 2. No configuration file for that linter currently exists
#
# Supported linters: eslint, oxlint, biome, tsslint
# (tslint is deprecated and not supported)
#
# NOTE: if the linter name is passed as a parameter it will be used,
# otherwise it will be detected via get_js_linter_by_dep().
function install_js_linter_config() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/filesystem.sh"
    source "${UTILS}/detection.sh"

    local linter="${1:-}"
    local target_dir=""
    local template_file=""
    local config_file=""

    # Detect linter if not provided
    if [[ -z "${linter}" ]]; then
        if ! linter=$(get_js_linter_by_dep); then
            debug "install_js_linter_config" "No linter detected in dependencies"
            return 1
        fi
    fi

    # Determine target directory (where package.json is)
    if [[ -f "./package.json" ]]; then
        target_dir="."
    elif is_git_repo "." && [[ -f "$(repo_root ".")/package.json" ]]; then
        target_dir="$(repo_root ".")"
    else
        debug "install_js_linter_config" "No package.json found"
        return 1
    fi

    # Map linter to template and config file names
    case "${linter}" in
        eslint)
            template_file="${ROOT}/resources/eslint.config.ts"
            config_file="eslint.config.ts"
            ;;
        oxlint)
            template_file="${ROOT}/resources/oxlint.json"
            config_file="oxlint.json"
            ;;
        biome)
            template_file="${ROOT}/resources/biome.jsonc"
            config_file="biome.jsonc"
            ;;
        tsslint)
            template_file="${ROOT}/resources/tsslint.config.ts"
            config_file="tsslint.config.ts"
            ;;
        tslint)
            debug "install_js_linter_config" "tslint is deprecated and not supported"
            return 1
            ;;
        *)
            debug "install_js_linter_config" "Unknown linter: ${linter}"
            return 1
            ;;
    esac

    # Check if a config for this linter already exists
    local existing_config
    if existing_config=$(get_js_linter_by_config_file 2>/dev/null); then
        if [[ "${existing_config}" == "${linter}" ]]; then
            debug "install_js_linter_config" "Config for ${linter} already exists"
            return 0
        fi
        # Different linter config exists - proceed with installation
    fi

    # Verify template exists
    if [[ ! -f "${template_file}" ]]; then
        debug "install_js_linter_config" "Template not found: ${template_file}"
        return 1
    fi

    # Copy template to target directory
    if cp "${template_file}" "${target_dir}/${config_file}"; then
        logc "{{GREEN}}Installed{{RESET}} {{BLUE}}${config_file}{{RESET}} configuration"
        return 0
    else
        debug "install_js_linter_config" "Failed to copy template"
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
