#!/usr/bin/env bash
# Mock infrastructure for testing install utilities
#
# This file provides mock implementations of package managers and utility functions
# to enable testing install logic without actually installing anything.
#
# Usage:
#   source install-mocks.sh
#   mock_available_commands "brew" "nix-env"  # Make only these commands "available"
#   mock_package_exists "brew:jq" "nix:ripgrep"  # Make these packages "exist"
#   mock_installed_packages "brew:jq" "cargo:ripgrep" # Make these packages "installed"
#   source ../utils/install.sh
#   install_on_macos jq
#   echo "Calls: ${MOCK_CALLS[*]}"

# Track all mock function calls
declare -a MOCK_CALLS=()

# Commands that should appear "available" (set via mock_available_commands)
declare -a MOCK_AVAILABLE_COMMANDS=()

# Packages that should "exist" in package managers (format: "manager:package")
declare -a MOCK_EXISTING_PACKAGES=()

# Packages that should appear "installed" (format: "manager:package")
declare -a MOCK_INSTALLED_PACKAGES=()

# Package that should "succeed" when installed (format: "manager:package")
# If not set, all installs succeed
declare -a MOCK_INSTALL_SUCCESS=()

# Whether to log mock activity
MOCK_DEBUG="${MOCK_DEBUG:-false}"

# mock_available_commands <cmd1> [<cmd2>] ...
#
# Set which commands should appear "available" via has_command
mock_available_commands() {
    MOCK_AVAILABLE_COMMANDS=($@)
    if [[ "$MOCK_DEBUG" == "true" ]]; then
        echo "MOCK: available commands = ${MOCK_AVAILABLE_COMMANDS[*]}" >&2
    fi
}

# mock_package_exists <manager:pkg> [<manager:pkg>] ...
#
# Set which packages should "exist" in package managers
# Format: "brew:jq" means jq exists in brew
mock_package_exists() {
    MOCK_EXISTING_PACKAGES=($@)
    if [[ "$MOCK_DEBUG" == "true" ]]; then
        echo "MOCK: existing packages = ${MOCK_EXISTING_PACKAGES[*]}" >&2
    fi
}

# mock_installed_packages <manager:pkg> [<manager:pkg>] ...
mock_installed_packages() {
    MOCK_INSTALLED_PACKAGES=($@)
}

# mock_install_succeeds <manager:pkg> [<manager:pkg>] ...
#
# Set which package:manager combinations should succeed when installed
# If this is empty, all installs succeed by default
mock_install_succeeds() {
    MOCK_INSTALL_SUCCESS=($@)
}

# reset_mocks
#
# Clear all mock state
reset_mocks() {
    MOCK_CALLS=()
    MOCK_AVAILABLE_COMMANDS=()
    MOCK_EXISTING_PACKAGES=()
    MOCK_INSTALLED_PACKAGES=()
    MOCK_INSTALL_SUCCESS=()
}

# get_mock_calls [filter]
#
# Get recorded mock calls, optionally filtered by prefix
get_mock_calls() {
    local filter="${1:-}"
    for call in "${MOCK_CALLS[@]}"; do
        if [[ -z "$filter" ]] || [[ "$call" == "$filter"* ]]; then
            echo "$call"
        fi
    done
}

# _mock_record <call>
#
# Record a mock function call
_mock_record() {
    MOCK_CALLS+=("$1")
    if [[ "$MOCK_DEBUG" == "true" ]]; then
        echo "MOCK CALL: $1" >&2
    fi
}

# _mock_has_package <manager> <package>
#
# Check if a package "exists" in a package manager
_mock_has_package() {
    local manager="$1"
    local pkg="$2"
    local lookup="${manager}:${pkg}"

    for existing in "${MOCK_EXISTING_PACKAGES[@]}"; do
        if [[ "$existing" == "$lookup" ]]; then
            return 0
        fi
    done
    return 1
}

# _mock_list_installed <manager> <output_format_func>
#
# Helper to list installed packages for a manager
_mock_list_installed() {
    local manager="$1"
    local formatter="$2" # Function name to format the output

    for item in "${MOCK_INSTALLED_PACKAGES[@]}"; do
        if [[ "$item" == "${manager}:"* ]]; then
            local pkg="${item#${manager}:}"
            $formatter "$pkg"
        fi
    done
}

# Formatters for _mock_list_installed
_fmt_simple() { echo "$1"; }
_fmt_cargo() { echo "$1 v1.0.0:"; echo "    bin"; }
_fmt_npm() { echo "/usr/lib/node_modules/$1"; }
_fmt_pip() { echo "$1 1.0.0"; }
_fmt_gem() { echo "$1 (1.0.0)"; }
_fmt_apt() { echo "$1/stable,now 1.0.0 amd64 [installed]"; }
_fmt_dnf() { echo "$1.x86_64"; }
_fmt_uv() { echo "$1 v1.0.0"; echo "- $1"; }
_fmt_bun() { echo "└── $1@1.0.0"; }
_fmt_pnpm() { echo "$1 1.0.0"; }


# _mock_install_succeeds <manager> <package>
#
# Check if an install should succeed
_mock_install_succeeds() {
    local manager="$1"
    local pkg="$2"

    # If no success list specified, all succeed
    if [[ ${#MOCK_INSTALL_SUCCESS[@]} -eq 0 ]]; then
        return 0
    fi

    local lookup="${manager}:${pkg}"
    for success in "${MOCK_INSTALL_SUCCESS[@]}"; do
        if [[ "$success" == "$lookup" ]]; then
            return 0
        fi
    done
    return 1
}

# Override has_command to use mock configuration
has_command() {
    local cmd="$1"
    _mock_record "has_command:$cmd"

    for available in "${MOCK_AVAILABLE_COMMANDS[@]}"; do
        if [[ "$available" == "$cmd" ]]; then
            return 0
        fi
    done
    return 1
}

# Suppress logc output during tests (or capture it)
logc() {
    _mock_record "logc:$*"
    # Silent during tests
}

# Mock link function (used in installed_*) 
link() {
    echo -e "\033]8;;$2\007$1\033]8;;\007"
}

# Mock brew
brew() {
    local subcmd="$1"
    shift
    _mock_record "brew:$subcmd:$*"

    case "$subcmd" in
        info)
            if _mock_has_package "brew" "$1"; then
                return 0
            fi
            return 1
            ;; 
        install)
            if _mock_install_succeeds "brew" "$1"; then
                return 0
            fi
            return 1
            ;; 
        list)
            if [[ "$1" == "--formula" ]]; then
                 _mock_list_installed "brew" _fmt_simple
            elif [[ "$1" == "--cask" ]]; then
                 _mock_list_installed "cask" _fmt_simple
            fi
            return 0
            ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock port (MacPorts)
port() {
    local subcmd="$1"
    shift
    _mock_record "port:$subcmd:$*"

    case "$subcmd" in
        search)
            if _mock_has_package "port" "$2"; then
                echo "$2"
                return 0
            fi
            return 1
            ;; 
        install)
            if _mock_install_succeeds "port" "$1"; then
                return 0
            fi
            return 1
            ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock fink
fink() {
    local subcmd="$1"
    shift
    _mock_record "fink:$subcmd:$*"

    case "$subcmd" in
        list)
            if _mock_has_package "fink" "$2"; then
                echo "$2"
                return 0
            fi
            return 1
            ;; 
        install)
            if _mock_install_succeeds "fink" "$1"; then
                return 0
            fi
            return 1
            ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock apt
apt() {
    local subcmd="$1"
    shift
    _mock_record "apt:$subcmd:$*"

    case "$subcmd" in
        info)
            if _mock_has_package "apt" "$1"; then
                return 0
            fi
            return 1
            ;; 
        install)
            if _mock_install_succeeds "apt" "$1"; then
                return 0
            fi
            return 1
            ;; 
        list)
            if [[ "$1" == "--installed" ]]; then
                _mock_list_installed "apt" _fmt_apt
            fi
            return 0
            ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock nala
nala() {
    local subcmd="$1"
    shift
    _mock_record "nala:$subcmd:$*"

    case "$subcmd" in
        install)
            if _mock_install_succeeds "nala" "$1"; then
                return 0
            fi
            return 1
            ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock dnf
dnf() {
    local subcmd="$1"
    shift
    _mock_record "dnf:$subcmd:$*"

    case "$subcmd" in
        info)
            if _mock_has_package "dnf" "$1"; then
                return 0
            fi
            return 1
            ;; 
        install)
            if _mock_install_succeeds "dnf" "$1"; then
                return 0
            fi
            return 1
            ;; 
        list)
            if [[ "$1" == "installed" ]]; then
                 echo "Installed Packages"
                 _mock_list_installed "dnf" _fmt_dnf
            fi
            return 0
            ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock yum
yum() {
    local subcmd="$1"
    shift
    _mock_record "yum:$subcmd:$*"

    case "$subcmd" in
        info)
            if _mock_has_package "yum" "$1"; then
                return 0
            fi
            return 1
            ;; 
        install)
            if _mock_install_succeeds "yum" "$1"; then
                return 0
            fi
            return 1
            ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock apk (Alpine)
apk() {
    local subcmd="$1"
    shift
    _mock_record "apk:$subcmd:$*"

    case "$subcmd" in
        search)
            if _mock_has_package "apk" "$2"; then
                echo "$2"
                return 0
            fi
            return 1
            ;; 
        add)
            if _mock_install_succeeds "apk" "$1"; then
                return 0
            fi
            return 1
            ;; 
        info)
            _mock_list_installed "apk" _fmt_simple
            return 0
            ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock pacman (Arch)
pacman() {
    local subcmd="$1"
    shift
    _mock_record "pacman:$subcmd:$*"

    case "$subcmd" in
        -Si)
            if _mock_has_package "pacman" "$1"; then
                return 0
            fi
            return 1
            ;; 
        -S)
            local pkg=""
            for arg in "$@"; do
                if [[ "$arg" != "--noconfirm" ]]; then
                    pkg="$arg"
                    break
                fi
            done
            if _mock_install_succeeds "pacman" "$pkg"; then
                return 0
            fi
            return 1
            ;; 
        -Qq)
             _mock_list_installed "pacman" _fmt_simple
             return 0
             ;; 
        *)
            return 0
            ;; 
    esac
}

# Mock yay (Arch AUR)
yay() {
    local subcmd="$1"
    shift
    _mock_record "yay:$subcmd:$*"
    # ... (existing)
    return 0
}

# Mock paru (Arch AUR)
paru() {
    local subcmd="$1"
    shift
    _mock_record "paru:$subcmd:$*"
    # ... (existing)
    return 0
}

# Mock nix-env
nix-env() {
    _mock_record "nix-env:$*"

    if [[ "$1" == "-qa" ]]; then
        local pkg="$2"
        if _mock_has_package "nix" "$pkg"; then
            echo "$pkg"
            return 0
        fi
        return 1
    elif [[ "$1" == "-iA" ]]; then
        local pkg="${2#nixpkgs.}"  # Remove nixpkgs. prefix
        if _mock_install_succeeds "nix" "$pkg"; then
            return 0
        fi
        return 1
    elif [[ "$1" == "-q" ]]; then
        _mock_list_installed "nix" _fmt_simple
        return 0
    fi
    return 0
}

# Mock cargo
cargo() {
    _mock_record "cargo:$*"

    if [[ "$1" == "search" ]]; then
        local pkg="$4"
        if _mock_has_package "cargo" "$pkg"; then
            echo "$pkg = \"1.0.0\"  # Package description"
            return 0
        fi
        return 1
    elif [[ "$1" == "install" ]]; then
        if [[ "$2" == "--list" ]]; then
            _mock_list_installed "cargo" _fmt_cargo
            return 0
        fi
        local pkg="$2"
        if _mock_install_succeeds "cargo" "$pkg"; then
            return 0
        fi
        return 1
    fi
    return 0
}

# Mock npm
npm() {
    _mock_record "npm:$*"
    if [[ "$1" == "list" ]]; then
        # Assumes args: list -g --depth=0 --parseable
        _mock_list_installed "npm" _fmt_npm
        return 0
    fi
    return 0
}

# Mock pip
pip() {
    _mock_record "pip:$*"
    if [[ "$1" == "list" ]]; then
         echo "Package Version"
         echo "------- ------- "
         _mock_list_installed "pip" _fmt_pip
         return 0
    fi
    return 0
}

# Mock gem
gem() {
    _mock_record "gem:$*"
    if [[ "$1" == "list" ]]; then
        _mock_list_installed "gem" _fmt_gem
        return 0
    fi
    return 0
}

# Mock uv
uv() {
    _mock_record "uv:$*"
    if [[ "$1" == "tool" && "$2" == "list" ]]; then
        _mock_list_installed "uv" _fmt_uv
        return 0
    fi
    return 0
}

# Mock pnpm
pnpm() {
    _mock_record "pnpm:$*"
    if [[ "$1" == "list" ]]; then
        # Args: list -g --depth=0
        echo "Legend: production dependency"
        echo ""
        echo "/mock/pnpm/global"
        echo ""
        echo "dependencies:"
        _mock_list_installed "pnpm" _fmt_pnpm
        return 0
    fi
    return 0
}

# Mock bun
bun() {
    _mock_record "bun:$*"
    if [[ "$1" == "pm" && "$2" == "ls" ]]; then
        # Args: pm ls -g
        echo "/mock/global node_modules"
        _mock_list_installed "bun" _fmt_bun
        return 0
    fi
    return 0
}

# Disable SUDO during tests
SUDO=""