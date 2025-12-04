#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__DETECTION_SH_LOADED:-}" ]] && declare -f "get_shell" > /dev/null && return
__DETECTION_SH_LOADED=1

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

# shellcheck source="./logging.sh" extended-analysis=false
source "${UTILS}/logging.sh"
# shellcheck source="./os.sh" extended-analysis=false
source "${UTILS}/os.sh"
# shellcheck source="./text.sh" extended-analysis=false
source "${UTILS}/text.sh"
# shellcheck source="./empty.sh" extended-analysis=false
source "${UTILS}/empty.sh"

# get_shell
#
# Return the *name* of the current interactive shell (not a path).
function get_shell() {
  # Prefer version vars (fast, reliable)
  if [ -n "${ZSH_VERSION-}" ];  then printf '%s\n' zsh;  return; fi
  if [ -n "${BASH_VERSION-}" ]; then printf '%s\n' bash; return; fi
  if [ -n "${FISH_VERSION-}" ]; then printf '%s\n' fish; return; fi

  # Fallback to $SHELL or the process name
  if [ -n "${SHELL-}" ]; then
    printf '%s\n' "$(basename -- "$SHELL")"; return
  fi

  # POSIX-ish fallback
  if command -v ps >/dev/null 2>&1; then
    ps -p $$ -o comm= 2>/dev/null | awk -F/ '{print $NF}' | sed 's/^-*//'
    return
  fi

  printf '%s\n' sh
}

# is_pve_host
#
# Returns an exit code which indicates whether the given machine is
# a PVE host or not.
function is_pve_host() {
    if has_command "pveversion"; then
        debug "is_pve_host" "is a pve node"
        return 0
    else
        debug "is_pve_host" "is NOT a pve node"
        return 1
    fi
}

# is_pve_container
#
# Test whether current host is an LXC container or VM
# running on Proxmox VE with API access available.
# Returns 0 if true, 1 if false.
function is_pve_container() {
    # Must be running in a container or VM
    if ! is_lxc && ! is_vm; then
        # shellcheck disable=SC2086
        return ${EXIT_FALSE}
    fi

    # Must have API key access
    has_pve_api_key
}

# is_pve_aware
#
# returns true when a non PVE host or container has set the
# PVE_API_TOKEN
function is_pve_aware() {
    if ! is_pve_container && ! is_pve_host; then
        if is_empty "${PVE_API_TOKEN:-}"; then
            return 1
        else
            return 0
        fi
    else
        return 1
    fi
}


# is_zsh()
#
# returns true/false based on whether the current shell is zsh.
function is_zsh() {
    [ -n "${ZSH_VERSION-}" ];
}

# is_bash()
#
# returns true/false based on whether the current shell is zsh.
function is_bash() {
    # Fast path: check for Bash-specific variable
    [ -n "${BASH_VERSION-}" ] && return 0

    # Fallback using normalized get_shell
    [[ "$(get_shell)" == "bash" ]]
}

# is_fish()
#
# returns true/false based on whether the current shell is zsh.
function is_fish() {
    # Fast path: check for Fish-specific variable
    [ -n "${FISH_VERSION-}" ] && return 0

    # Fallback using normalized get_shell
    [[ "$(get_shell)" == "fish" ]]
}

# is_nushell()
#
# returns true/false based on whether the current shell is nushell
is_nushell()   { [[ "$(get_shell)" == "nu" ]]; }

# is_xonsh()
#
# returns true/false based on whether the current shell is xonsh ("conch shell" a
# based shell.)
is_xonsh(){ [[ "$(get_shell)" == "xonsh" ]]; }

# is_docker()
#
# Check for Docker container
is_docker() {
    # Check common Docker indicators
    if [ -f /.dockerenv ] ||
       { [ -f /proc/1/cgroup ] && grep -qi "docker\|kubepods" /proc/1/cgroup; }; then
        return 0
    fi
    return 1
}

# Check for LXC container
is_lxc() {
    # Check common LXC indicators
    if grep -q 'container=lxc' /proc/1/environ 2>/dev/null ||
       [ -f /run/.containerenv ] ||
       ( [ -f /proc/1/cgroup ] && grep -qi 'lxc' /proc/1/cgroup ); then
        return 0
    fi
    return 1
}

# is_vm
#
# Check for VM (any hypervisor)
is_vm() {
    # Check common VM indicators
    if grep -q 'hypervisor' /proc/cpuinfo 2>/dev/null ||
       ( [ -f /sys/class/dmi/id/product_name ] &&
         grep -qi -e 'qemu' -e 'kvm' /sys/class/dmi/id/product_name ); then
        return 0
    fi
    return 1
}

# is_kvm_vm
#
# Check if running in a KVM/QEMU VM specifically.
# This is the virtualization technology used by Proxmox VE,
# but also by other hypervisors (libvirt, oVirt, OpenStack, etc.)
is_kvm_vm() {
    # Method 1: Use systemd-detect-virt if available (most reliable)
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt_type
        virt_type=$(systemd-detect-virt --vm 2>/dev/null)
        if [[ "$virt_type" == "kvm" || "$virt_type" == "qemu" ]]; then
            return 0
        fi
    fi

    # Method 2: Check DMI/SMBIOS for QEMU manufacturer
    if [ -f /sys/class/dmi/id/sys_vendor ]; then
        if grep -qi 'qemu' /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            return 0
        fi
    fi

    # Method 3: Check product name for KVM
    if [ -f /sys/class/dmi/id/product_name ]; then
        if grep -qi -e 'kvm' -e 'qemu' /sys/class/dmi/id/product_name 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# using_bash_3
#
# tests whether the host OS has bash version 3 installed
function using_bash_3() {
    local -r version=$(bash_version)

    if starts_with "3" "${version}"; then
        debug "using_bash_3" "IS version 3 variant!"
        return 0
    else
        debug "using_bash_3" "is not version 3 variant"
        return 1
    fi
}

# bash_version()
#
# returns the version number of bash for the host OS
function bash_version() {
    local version
    version=$(bash --version)
    version=$(strip_after "(" "$version")
    version=$(strip_before "version " "$version")

    echo "$version"
}


# get_arch()
#
# Gets the system architecture in standardized format
function get_arch() {
    case $(os) in
        linux|macos)
            local arch
            arch=$(uname -m)
            # Normalize architecture names
            case $arch in
                x86_64)    echo "x86_64" ;;
                aarch64)   echo "arm64" ;;
                armv7l)    echo "armv7" ;;
                armv6l)    echo "armv6" ;;
                *)         echo "$arch" ;;
            esac
            ;;
        windows)
            # Check environment variables first
            if [ -n "$PROCESSOR_ARCHITECTURE" ]; then
                case "$PROCESSOR_ARCHITECTURE" in
                    AMD64) echo "x86_64" ;;
                    ARM64) echo "arm64" ;;
                    *)     echo "$PROCESSOR_ARCHITECTURE" ;;
                esac
            else
                # Fallback to PowerShell command
                powershell.exe -Command "[System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLower()"
            fi
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}


# has_command <cmd>
#
# Checks whether a particular program passed in via $1 is installed
# on the OS or not (at least within the $PATH). This function explicitly
# excludes shell functions from detection, allowing wrapper functions
# to exist without being mistakenly identified as the real command.
function has_command() {
    local -r cmd="${1:?cmd is missing}"

    # Check for actual executable in PATH (not functions or aliases)
    # Use shell-specific methods since type -P is bash-only
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # Zsh: use whence -p (finds executables in PATH only)
        if whence -p "${cmd}" &> /dev/null; then
            return 0
        fi
        # Also accept shell builtins
        local cmd_type
        cmd_type="$(whence -w "${cmd}" 2>/dev/null)"
        if [[ "${cmd_type}" == *": builtin" ]]; then
            return 0
        fi
    else
        # Bash: use type -P (finds executables in PATH only)
        if type -P "${cmd}" &> /dev/null; then
            return 0
        fi
        # Also accept shell builtins
        if [[ "$(type -t "${cmd}" 2>/dev/null)" == "builtin" ]]; then
            return 0
        fi
    fi

    return 1
}

# has_function <name>
#
# Checks whether a shell function with the given name is defined.
# Returns true only for functions, not for executables, aliases, or builtins.
function has_function() {
    local -r name="${1:?function name is missing}"

    if [[ -n "${ZSH_VERSION:-}" ]]; then
        # Zsh: whence -w outputs "name: function" for functions
        [[ "$(whence -w "${name}" 2>/dev/null)" == *": function" ]]
    else
        # Bash: type -t outputs "function" for functions
        [[ "$(type -t "${name}" 2>/dev/null)" == "function" ]]
    fi
}

function is_keyword() {
    local _var=${1:?no parameter passed into is_array}
    local declaration=""
    # shellcheck disable=SC2086
    declaration=$(LC_ALL=C type -t $1)

    if [[ "$declaration" == "keyword" ]]; then
        return 0
    else
        return 1
    fi
}

# is_git_repo <path || CWD>
#
# Tests whether the given path is inside a git repository.
# Returns 0 if inside a git repo, 1 otherwise.
function is_git_repo() {
    local path="${1:-${PWD}}"

    # Handle non-existent paths
    if [[ ! -e "${path}" ]]; then
        return 1
    fi

    # If path is a file, use its directory
    if [[ -f "${path}" ]]; then
        path="$(dirname "${path}")"
    fi

    # Check if inside a git work tree
    git -C "${path}" rev-parse --is-inside-work-tree &>/dev/null
}

# repo_is_dirty <path || CWD>
#
# Tests whether the git repository has uncommitted changes.
# Returns 0 if dirty (has changes), 1 if clean or not a git repo.
function repo_is_dirty() {
    local path="${1:-${PWD}}"

    # Handle non-existent paths
    if [[ ! -e "${path}" ]]; then
        return 1
    fi

    # If path is a file, use its directory
    if [[ -f "${path}" ]]; then
        path="$(dirname "${path}")"
    fi

    # Must be a git repo
    if ! is_git_repo "${path}"; then
        return 1
    fi

    # Check for any changes (staged, unstaged, or untracked)
    local status
    status="$(git -C "${path}" status --porcelain 2>/dev/null)"

    # If status output is non-empty, repo is dirty
    [[ -n "${status}" ]]
}

# repo_root <path || CWD>
#
# Finds the root directory of a git repository.
# Outputs the absolute path to the repo root on success.
# Returns 0 on success, 1 if not a git repo or path doesn't exist.
function repo_root() {
    local path="${1:-${PWD}}"

    # Handle non-existent paths
    if [[ ! -e "${path}" ]]; then
        return 1
    fi

    # If path is a file, use its directory
    if [[ -f "${path}" ]]; then
        path="$(dirname "${path}")"
    fi

    # Must be a git repo
    if ! is_git_repo "${path}"; then
        return 1
    fi

    # Get the repo root
    git -C "${path}" rev-parse --show-toplevel 2>/dev/null
}

# is_monorepo <path || $CWD>
#
# Tests whether the repository is a monorepo (contains multiple packages/workspaces).
# Checks for: pnpm-workspace.yaml, lerna.json, or workspaces field in package.json.
# Returns 0 if monorepo, 1 otherwise.
function is_monorepo() {
    local path="${1:-${PWD}}"
    local root

    # Get repo root (or use path directly if not a git repo)
    if is_git_repo "${path}"; then
        root="$(repo_root "${path}")"
    else
        # Not a git repo - check the path directly
        if [[ -d "${path}" ]]; then
            root="${path}"
        else
            return 1
        fi
    fi

    # Check for pnpm workspaces
    if [[ -f "${root}/pnpm-workspace.yaml" ]]; then
        return 0
    fi

    # Check for Lerna
    if [[ -f "${root}/lerna.json" ]]; then
        return 0
    fi

    # Check for npm/yarn workspaces in package.json
    if [[ -f "${root}/package.json" ]]; then
        if grep -q '"workspaces"' "${root}/package.json" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# has_package_json <path || CWD>
#
# Checks if a `package.json` file can be found in the path or repo root.
# Returns 0 if found, 1 otherwise.
function has_package_json() {
    local path="${1:-${PWD}}"

    # Handle non-existent paths
    if [[ ! -e "${path}" ]]; then
        return 1
    fi

    # If path is a file, use its directory
    if [[ -f "${path}" ]]; then
        path="$(dirname "${path}")"
    fi

    # Check directly in path
    if [[ -f "${path}/package.json" ]]; then
        return 0
    fi

    # Check in repo root if in a git repo
    if is_git_repo "${path}"; then
        local root
        root="$(repo_root "${path}")"
        if [[ -f "${root}/package.json" ]]; then
            return 0
        fi
    fi

    return 1
}

# has_typescript_files <path || CWD>
#
# Looks for TypeScript files (.ts, .tsx) in the path, repo root, and src/ subdirectory.
# Returns 0 if found, 1 otherwise.
function has_typescript_files() {
    local path="${1:-${PWD}}"
    local root
    local found

    # Handle non-existent paths
    if [[ ! -e "${path}" ]]; then
        return 1
    fi

    # If path is a file, use its directory
    if [[ -f "${path}" ]]; then
        path="$(dirname "${path}")"
    fi

    # Determine root directory to search
    if is_git_repo "${path}"; then
        root="$(repo_root "${path}")"
    else
        root="${path}"
    fi

    # Check in path directly (with limited depth for performance)
    # Use -quit for efficiency and capture result to avoid pipefail issues
    found="$(find "${path}" -maxdepth 3 \( -name '*.ts' -o -name '*.tsx' \) -print -quit 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
        return 0
    fi

    # Check in repo root if different from path
    if [[ "${root}" != "${path}" ]]; then
        found="$(find "${root}" -maxdepth 3 \( -name '*.ts' -o -name '*.tsx' \) -print -quit 2>/dev/null || true)"
        if [[ -n "${found}" ]]; then
            return 0
        fi
    fi

    # Check in src/ subdirectory
    if [[ -d "${root}/src" ]]; then
        found="$(find "${root}/src" -maxdepth 3 \( -name '*.ts' -o -name '*.tsx' \) -print -quit 2>/dev/null || true)"
        if [[ -n "${found}" ]]; then
            return 0
        fi
    fi

    return 1
}

# looks_like_js_project
#
# Looks for files in the current directory which indicate
# this is a JavaScript/TypeScript project.
# Returns 0 if JS/TS project detected, 1 otherwise.
function looks_like_js_project() {
    local found

    # Primary indicator: package.json
    if [[ -f "./package.json" ]]; then
        return 0
    fi

    # Check repo root if in a git repo
    if is_git_repo "."; then
        local root
        root="$(repo_root ".")"
        if [[ -f "${root}/package.json" ]]; then
            return 0
        fi
    fi

    # Fallback: look for JS/TS files in current directory
    found="$(find . -maxdepth 2 \( -name '*.js' -o -name '*.ts' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.jsx' -o -name '*.tsx' \) -print -quit 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
        return 0
    fi

    return 1
}

# js_package_manager
#
# Returns the JS/TS package being used in this repo:
#   - returns error code if this is NOT a JS/TS project directory
#   - on success returns "npm", "yarn", "pnpm", "bun", or "deno"
#   - if unable to determine (but it IS a JS/TS project directory) then will nothing but
#     exit code will be successful
function js_package_manager() {
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

# looks_like_rust_project
#
# Looks for files in the current directory which indicate
# this is a Rust project.
# Returns 0 if Rust project detected, 1 otherwise.
function looks_like_rust_project() {
    local found

    # Primary indicator: Cargo.toml
    if [[ -f "./Cargo.toml" ]]; then
        return 0
    fi

    # Check repo root if in a git repo
    if is_git_repo "."; then
        local root
        root="$(repo_root ".")"
        if [[ -f "${root}/Cargo.toml" ]]; then
            return 0
        fi
    fi

    # Fallback: look for .rs files
    found="$(find . -maxdepth 2 -name '*.rs' -print -quit 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
        return 0
    fi

    return 1
}

# looks_like_python_project
#
# Looks for files in the current directory which indicate
# this is a Python project.
# Returns 0 if Python project detected, 1 otherwise.
function looks_like_python_project() {
    local root="."
    local found

    # Check repo root if in a git repo
    if is_git_repo "."; then
        root="$(repo_root ".")"
    fi

    # Primary indicators: Python project files
    if [[ -f "${root}/pyproject.toml" ]] ||
       [[ -f "${root}/requirements.txt" ]] ||
       [[ -f "${root}/setup.py" ]] ||
       [[ -f "${root}/setup.cfg" ]] ||
       [[ -f "${root}/Pipfile" ]]; then
        return 0
    fi

    # Fallback: look for .py files
    found="$(find "${root}" -maxdepth 2 -name '*.py' -print -quit 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
        return 0
    fi

    return 1
}

# in_package_json <find>
#
# tests whether a given string exists in the package.json file
# located in the current directory.
function in_package_json() {
    # shellcheck source="./text.sh"
    source "${UTILS}/text.sh"
    # shellcheck source="./filesystem.sh"
    source "${UTILS}/filesystem.sh"

    local find="${1:?find string missing in call to in_package_json}"
    local -r pkg="$(get_file "./package.json")"

    if contains "${find}" "${pkg}"; then
        return 0;
    else
        return 1;
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
