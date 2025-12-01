#!/usr/bin/env bash

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

# shellcheck source="./logging.sh"
source "${UTILS}/logging.sh"
# shellcheck source="./interactive.sh"
source "${UTILS}/interactive.sh"
# shellcheck source="./detection.sh"
source "${UTILS}/detection.sh"

# _try_cargo_install <pkg1> [<pkg2>] ...
#
# Attempts to install packages using cargo. Returns 0 on success, 1 on failure.
# Note: cargo install builds from source, which takes longer than pre-built binaries.
function _try_cargo_install() {
    local -r pkg_names=("$@")

    if ! has_command "cargo"; then
        return 1
    fi

    for pkg in "${pkg_names[@]}"; do
        # Check if package exists on crates.io
        if cargo search --limit 1 "${pkg}" 2>/dev/null | grep -q "^${pkg} = "; then
            logc "- building {{GREEN}}${pkg}{{RESET}} from source using {{BOLD}}cargo{{RESET}}"
            cargo install "${pkg}" && return 0
            logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to build {{GREEN}}${pkg}{{RESET}} package!"
            return 1
        else
            logc "- {{BOLD}}cargo{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
        fi
    done

    return 1
}

# _try_nix_install <pkg1> [<pkg2>] ...
#
# Attempts to install packages using nix-env. Returns 0 on success, 1 on failure.
function _try_nix_install() {
    local -r pkg_names=("$@")

    if ! has_command "nix-env"; then
        return 1
    fi

    for pkg in "${pkg_names[@]}"; do
        if nix-env -qa "${pkg}" 2>/dev/null | grep -q .; then
            logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nix{{RESET}}"
            nix-env -iA "nixpkgs.${pkg}" && return 0
            logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
            return 1
        else
            logc "- {{BOLD}}nix{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
        fi
    done

    return 1
}



# install_on_macos [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on macOS. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_macos() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_macos()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try brew with each package name variant
    if has_command "brew"; then
        for pkg in "${pkg_names[@]}"; do
            if brew info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}brew{{RESET}}"
                brew install "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}brew{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try port with each package name variant
    if has_command "port"; then
        for pkg in "${pkg_names[@]}"; do
            if port search --exact "${pkg}" 2>/dev/null | grep -q .; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}port{{RESET}}"
                port install "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}port{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try fink with each package name variant
    if has_command "fink"; then
        for pkg in "${pkg_names[@]}"; do
            if fink list -t "${pkg}" 2>/dev/null | grep -q "^${pkg}"; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}fink{{RESET}}"
                fink install "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}fink{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this macOS system"
    return 1
}

# install_on_debian [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on Debian/Ubuntu. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_debian() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_debian()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try nala (preferred over apt) with each package name variant
    if has_command "nala"; then
        for pkg in "${pkg_names[@]}"; do
            if apt info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}nala{{RESET}}"
                ${SUDO} nala install -y "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}nala{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try apt with each package name variant
    if has_command "apt"; then
        for pkg in "${pkg_names[@]}"; do
            if apt info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}apt{{RESET}}"
                ${SUDO} apt install -y "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}apt{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this Debian system"
    return 1
}

# install_on_fedora [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on Fedora/RHEL/CentOS. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_fedora() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_fedora()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try dnf with each package name variant
    if has_command "dnf"; then
        for pkg in "${pkg_names[@]}"; do
            if dnf info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}dnf{{RESET}}"
                ${SUDO} dnf install -y "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}dnf{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try yum with each package name variant
    if has_command "yum"; then
        for pkg in "${pkg_names[@]}"; do
            if yum info "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}yum{{RESET}}"
                ${SUDO} yum install -y "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}yum{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this Fedora system"
    return 1
}


# _construct_pkg_url <prefix> <suffix> <pkg>
#
# Helper to construct the package URL, handling {{PKG}} template substitution.
function _construct_pkg_url() {
    local prefix="$1"
    local suffix="$2"
    local pkg="$3"
    if [[ "$prefix" == *"{{PKG}}"* ]]; then
        echo "${prefix//\{\{PKG\}\}/$pkg}"
    else
        echo "${prefix}${pkg}${suffix}"
    fi
}

# _filter_and_link <manager_label> <url_prefix> <url_suffix> [filters...]
#
# Helper function to filter and link packages from stdin.
# Reads package names from stdin, filters them using grep (OR logic),
# and prints them with links in a grouped, horizontal layout.
function _filter_and_link() {
    # Run in subshell with stderr silenced to suppress any debug/xtrace noise
    (
        # Explicitly disable trace in case XTRACE_FD is redirected to stdout
        set +x
        set +v

        local -r label="${1}"
        local -r url_prefix="${2}"
        local -r url_suffix="${3}"
        shift 3
        local -r filters=("$@")

        local grep_pattern=""
        if [[ ${#filters[@]} -gt 0 ]]; then
            local first=true
            for f in "${filters[@]}"; do
                if $first; then first=false; else grep_pattern+="|"; fi
                grep_pattern+="$f"
            done
        fi

        # Determine terminal width
        local term_cols
        if [[ -n "${COLUMNS:-}" ]]; then
            term_cols="${COLUMNS}"
        elif command -v tput >/dev/null 2>&1; then
            term_cols=$(tput cols)
        else
            term_cols=80
        fi
        # Subtract a bit for safety/padding
        local -i max_width=$((term_cols - 5))
        if [[ $max_width -lt 20 ]]; then max_width=20; fi

        local -a pkgs=()
        # Read all matching packages
        while read -r pkg; do
            if [[ -z "$pkg" ]]; then continue; fi

            if [[ -z "$grep_pattern" ]] || echo "$pkg" | grep -q -i -E "$grep_pattern"; then
                 pkgs+=("$pkg")
            fi
        done

        # If we have packages, print them with wrapping
        if [[ ${#pkgs[@]} -gt 0 ]]; then
            # Ensure colors are set up
            if [[ "$(colors_not_setup)" == "0" ]]; then
                setup_colors
            fi

            # Print Header
            local -r heading="$(tangerine "${label}")"
            printf "\n%s\n" "${heading}"

            local current_line=""
            local -i current_len=0

            for pkg in "${pkgs[@]}"; do
                local -i pkg_len=${#pkg}

                # Check if adding this package would exceed width
                # We add 2 spaces padding if line is not empty
                local -i added_len=$pkg_len
                if [[ $current_len -gt 0 ]]; then
                    added_len=$((pkg_len + 2))
                fi

                if [[ $((current_len + added_len)) -gt $max_width ]]; then
                    # Flush current line
                    echo "$current_line"
                    current_line="$(link "$pkg" "$(_construct_pkg_url "$url_prefix" "$url_suffix" "$pkg")")"
                    current_len=$pkg_len
                else
                    if [[ -z "$current_line" ]]; then
                        current_line="$(link "$pkg" "$(_construct_pkg_url "$url_prefix" "$url_suffix" "$pkg")")"
                        current_len=$pkg_len
                    else
                        current_line="${current_line}  $(link "$pkg" "$(_construct_pkg_url "$url_prefix" "$url_suffix" "$pkg")")"
                        current_len=$((current_len + added_len))
                    fi
                fi
            done

            # Flush remaining
            if [[ -n "$current_line" ]]; then
                echo "$current_line"
            fi
        fi
    ) 2>/dev/null
}

# installed_cargo [filters...]
function installed_cargo() {
    if ! has_command "cargo"; then return; fi
    cargo install --list 2>/dev/null | grep -E '^[a-z0-9_-]+ v' | cut -d' ' -f1 | \
        _filter_and_link "cargo" "https://crates.io/crates/{{PKG}}" "" "$@"
}

# installed_brew [filters...]
function installed_brew() {
    if ! has_command "brew"; then return; fi
    # Formulae
    brew list --formula -1 2>/dev/null | \
        _filter_and_link "brew" "https://formulae.brew.sh/formula/{{PKG}}" "" "$@"
    # Casks
    brew list --cask -1 2>/dev/null | \
        _filter_and_link "brew > cask" "https://formulae.brew.sh/cask/{{PKG}}" "" "$@"
}

# installed_npm [filters...]
function installed_npm() {
    if ! has_command "npm"; then return; fi
    # parseable returns /path/to/package. We split by "/node_modules/" to get the package name,
    # which preserves scopes (e.g. @org/pkg). Fallback to basename if node_modules not found.
    npm list -g --depth=0 --parseable 2>/dev/null | \
        tail -n +2 | \
        awk -F'/node_modules/' '{if (NF>1) print $NF; else { n=split($0, a, "/"); print a[n] }}' | \
        _filter_and_link "npm" "https://www.npmjs.com/package/{{PKG}}" "" "$@"
}

# installed_pip [filters...]
function installed_pip() {
    if ! has_command "pip"; then return; fi
    pip list --format=columns 2>/dev/null | tail -n +3 | awk '{print $1}' | \
        _filter_and_link "pip" "https://pypi.org/project/{{PKG}}" "" "$@"
}

# installed_gem [filters...]
function installed_gem() {
    if ! has_command "gem"; then return; fi
    gem list 2>/dev/null | cut -d' ' -f1 | \
        _filter_and_link "gem" "https://rubygems.org/gems/{{PKG}}" "" "$@"
}

# installed_nix [filters...]
function installed_nix() {
    if ! has_command "nix-env"; then return; fi
    nix-env -q 2>/dev/null | \
        sed 's/-[0-9].*//' | \
        _filter_and_link "nix" "https://search.nixos.org/packages?channel=unstable&show={{PKG}}&query={{PKG}}" "" "$@"
}

# installed_apt [filters...]
function installed_apt() {
    if ! has_command "dpkg-query"; then return; fi

    # Use dpkg-query for stable, scriptable output of installed packages
    dpkg-query -f '${Package}\n' -W 2>/dev/null | \
        _filter_and_link "apt" "https://packages.debian.org/search?keywords={{PKG}}" "" "$@"
}

# installed_apk [filters...]
function installed_apk() {
    if ! has_command "apk"; then return; fi
    apk info 2>/dev/null | \
        _filter_and_link "apk" "https://pkgs.alpinelinux.org/packages?name={{PKG}}" "" "$@"
}

# installed_pacman [filters...]
function installed_pacman() {
    if ! has_command "pacman"; then return; fi
    pacman -Qq 2>/dev/null | \
        _filter_and_link "pacman" "https://archlinux.org/packages/?q={{PKG}}" "" "$@"
}

# installed_dnf [filters...]
function installed_dnf() {
    if ! has_command "dnf"; then return; fi
    dnf list installed 2>/dev/null | tail -n +2 | awk '{print $1}' | cut -d. -f1 | \
        _filter_and_link "dnf" "https://packages.fedoraproject.org/pkgs/{{PKG}}" "" "$@"
}

# installed [filters...]
#
# Lists installed packages from all detected package managers.
# Accepts optional arguments as filters (OR condition).
function show_installed() {
    local -r filters=("$@")

    installed_brew "${filters[@]}"
    installed_cargo "${filters[@]}"
    installed_npm "${filters[@]}"
    installed_pip "${filters[@]}"
    installed_gem "${filters[@]}"
    installed_nix "${filters[@]}"
    installed_apt "${filters[@]}"
    installed_apk "${filters[@]}"
    installed_pacman "${filters[@]}"
    installed_dnf "${filters[@]}"
}


# install_on_alpine [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on Alpine Linux. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_alpine() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_alpine()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try apk with each package name variant
    if has_command "apk"; then
        for pkg in "${pkg_names[@]}"; do
            if apk search -e "${pkg}" 2>/dev/null | grep -q .; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}apk{{RESET}}"
                ${SUDO} apk add "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}apk{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this Alpine system"
    return 1
}

# install_on_arch [--prefer-nix] [--prefer-cargo] <pkg> [<pkg2>] [<pkg3>] ...
#
# Attempts to install a named package on Arch Linux. Accepts multiple package name
# variants which are tried in order with each package manager until one succeeds.
# Use --prefer-nix to try nix-env first, --prefer-cargo to try cargo first.
function install_on_arch() {
    local prefer_nix=false
    local prefer_cargo=false
    local pkg_names=()

    # Parse flags from arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefer-nix)
                prefer_nix=true
                shift
                ;;
            --prefer-cargo)
                prefer_cargo=true
                shift
                ;;
            *)
                pkg_names+=("$1")
                shift
                ;;
        esac
    done

    if [[ ${#pkg_names[@]} -eq 0 ]]; then
        logc "{{RED}}ERROR{{RESET}}: no package provided to install_on_arch()!"
        return 1
    fi

    # Try cargo first if preferred
    if [[ "$prefer_cargo" == true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Try nix first if preferred
    if [[ "$prefer_nix" == true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try pacman (official repos) with each package name variant
    if has_command "pacman"; then
        for pkg in "${pkg_names[@]}"; do
            if pacman -Si "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}pacman{{RESET}}"
                ${SUDO} pacman -S --noconfirm "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}pacman{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try yay (AUR) with each package name variant
    if has_command "yay"; then
        for pkg in "${pkg_names[@]}"; do
            if yay -Si "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}yay{{RESET}} (AUR)"
                yay -S --noconfirm "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}yay{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try paru (AUR) with each package name variant
    if has_command "paru"; then
        for pkg in "${pkg_names[@]}"; do
            if paru -Si "${pkg}" &>/dev/null; then
                logc "- installing {{GREEN}}${pkg}{{RESET}} using {{BOLD}}paru{{RESET}} (AUR)"
                paru -S --noconfirm "${pkg}" && return 0
                logc "{{BOLD}}{{RED}}ERROR{{RESET}}: failed to install {{GREEN}}${pkg}{{RESET}} package!"
                return 1
            else
                logc "- {{BOLD}}paru{{RESET}} does not have package {{GREEN}}${pkg}{{RESET}}"
            fi
        done
    fi

    # Try nix-env (if not already tried as preferred)
    if [[ "$prefer_nix" != true ]]; then
        _try_nix_install "${pkg_names[@]}" && return 0
    fi

    # Try cargo (if not already tried as preferred)
    if [[ "$prefer_cargo" != true ]]; then
        _try_cargo_install "${pkg_names[@]}" && return 0
    fi

    # Nothing worked
    logc "- unsure how to install any of '${pkg_names[*]}' on this Arch system"
    return 1
}

function install_openssh() {
    if has_command "ssh-keygen"; then
        logc "- {{BOLD}}{{BLUE}}openssh{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "openssh"
    elif is_debian || is_ubuntu; then
        install_on_debian "openssh-server"
    elif is_alpine; then
        install_on_alpine "openssh"
    elif is_fedora; then
        install_on_fedora "openssh" "openssh-server"
    elif is_arch; then
        install_on_arch "openssh" "openssh-server"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}jq{{RESET}}, go to {{GREEN}}https://jqlang.org/download/{{RESET}} and download manually"
        return 1
    fi
}

function install_curl() {
    if has_command "curl"; then
        logc "- {{BOLD}}{{BLUE}}curl{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "curl"
    elif is_debian || is_ubuntu; then
        install_on_debian "curl"
    elif is_alpine; then
        install_on_alpine "curl"
    elif is_fedora; then
        install_on_fedora "curl"
    elif is_arch; then
        install_on_arch "curl"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}curl{{RESET}}"
        return 1
    fi
}

function install_wget() {
    if has_command "wget"; then
        logc "- {{BOLD}}{{BLUE}}wget{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "wget"
    elif is_debian || is_ubuntu; then
        install_on_debian "wget"
    elif is_alpine; then
        install_on_alpine "wget"
    elif is_fedora; then
        install_on_fedora "wget"
    elif is_arch; then
        install_on_arch "wget"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}wget{{RESET}}"
        return 1
    fi
}

function install_gh() {
    if has_command "gh"; then
        logc "- {{BOLD}}{{BLUE}}gh{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "gh"
    elif is_debian || is_ubuntu; then
        install_on_debian "gh"
    elif is_alpine; then
        install_on_alpine "gh"
    elif is_fedora; then
        install_on_fedora "gh"
    elif is_arch; then
        install_on_arch "gh"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}gh{{RESET}}"
        return 1
    fi
}

function install_bat() {
    if has_command "gh"; then
        logc "- {{BOLD}}{{BLUE}}gh{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "gh"
    elif is_debian || is_ubuntu; then
        install_on_debian "gh"
    elif is_alpine; then
        install_on_alpine "gh"
    elif is_fedora; then
        install_on_fedora "gh"
    elif is_arch; then
        install_on_arch "gh"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}gh{{RESET}}"
        return 1
    fi
}

function install_build_tools() {
    :
}

function install_delta() {
    if has_command "delta"; then
        logc "- {{BOLD}}{{BLUE}}delta{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "delta"
    elif is_debian || is_ubuntu; then
        install_on_debian "delta"
    elif is_alpine; then
        install_on_alpine "delta"
    elif is_fedora; then
        install_on_fedora "delta"
    elif is_arch; then
        install_on_arch "delta"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}delta{{RESET}}"
        return 1
    fi
}

function install_fzf() {
    if has_command "fzf"; then
        logc "- {{BOLD}}{{BLUE}}fzf{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "fzf"
    elif is_debian || is_ubuntu; then
        install_on_debian "fzf"
    elif is_alpine; then
        install_on_alpine "fzf"
    elif is_fedora; then
        install_on_fedora "fzf"
    elif is_arch; then
        install_on_arch "fzf"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}fzf{{RESET}}"
        return 1
    fi
}

function install_just() {
    if has_command "just"; then
        logc "- {{BOLD}}{{BLUE}}just{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "just"
    elif is_debian || is_ubuntu; then
        install_on_debian "just"
    elif is_alpine; then
        install_on_alpine "just"
    elif is_fedora; then
        install_on_fedora "just"
    elif is_arch; then
        install_on_arch "just"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}just{{RESET}}"
        return 1
    fi
}

function install_qemu_guest_agent() {
    :
}

function install_gpg() {
    if has_command "gpg"; then
        logc "- {{BOLD}}{{BLUE}}gpg{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "gpg"
    elif is_debian || is_ubuntu; then
        install_on_debian "gpg"
    elif is_alpine; then
        install_on_alpine "gpg"
    elif is_fedora; then
        install_on_fedora "gpg"
    elif is_arch; then
        install_on_arch "gpg"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}gpg{{RESET}}"
        return 1
    fi
}

function install_xclip() {
    :
}

function install_atuin() {
    if has_command "atuin"; then
        logc "- {{BOLD}}{{BLUE}}atuin{{RESET}} is already installed"
        return 0
    fi
    logc "- installing {{BOLD}}{{BLUE}}atuin{{RESET}}"
    bash -e <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh) || error "failed to install Atuin!" 1
    logc "- {{BOLD}}{{BLUE}}atuin{{RESET}} installed"
}

function install_nala() {
    :
}

function install_stylua() {

    if has_command "stylua"; then
        logc "- {{BOLD}}{{BLUE}}stylua{{RESET}} is already installed"
        return 0
    else
        if wget https://github.com/JohnnyMorganz/StyLua/releases/download/v2.0.2/stylua-linux-x86_64.zip; then
            unzip stylua-linux-x86.zip
            if mv "stylua-linux-x86.zip" "/usr/local/bin"; then
                log "- installed ${BLUE}${BOLD}stylua${RESET} linter into /usr/local/bin"
                rm stylua-linux-x86_64.zip &>/dev/null
            fi
        fi
    fi
}

function install_jq() {
    if has_command "jq"; then
        logc "- {{BOLD}}{{BLUE}}jq{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "jq"
    elif is_debian || is_ubuntu; then
        install_on_debian "jq"
    elif is_alpine; then
        install_on_alpine "jq"
    elif is_fedora; then
        install_on_fedora "jq"
    elif is_arch; then
        install_on_arch "jq"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}jq{{RESET}}, go to {{GREEN}}https://jqlang.org/download/{{RESET}} and download manually"
        return 1
    fi
}

function install_neovim() {
    if has_command "nvim"; then
        logc "- {{BOLD}}{{BLUE}}neovim{{RESET}} is already installed"
        return 0
    fi
    logc "- installing {{BOLD}}{{BLUE}}neovim{{RESET}}"
    if is_mac; then
        install_on_macos "neovim"
    elif is_debian || is_ubuntu; then
        install_on_debian "neovim"
    elif is_alpine; then
        install_on_alpine "neovim"
    elif is_fedora; then
        install_on_fedora "neovim"
    else
        logc "- {{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}neovim{{RESET}}"
        return 1
    fi
}

# installs `eza` if it can but if not then it will try `exa`
function install_eza() {
    if has_command "eza" || has_command "exa"; then
        if has_command "eza"; then
            logc "- {{BOLD}}{{BLUE}}eza{{RESET}} is already installed"
        else
            logc "- {{BOLD}}{{BLUE}}exa{{RESET}} is installed ({{ITALIC}}{{DIM}}indicating eza is not yet avail{{RESET}})"
        fi
        return 0
    fi
    logc "- installing {{BOLD}}{{BLUE}}eza{{RESET}}"
    if is_mac; then
        install_on_macos "eza"
    elif is_debian || is_ubuntu; then
        install_on_debian "eza"
    elif is_alpine; then
        install_on_alpine "eza"
    elif is_fedora; then
        install_on_fedora "eza"
    else
        if is_mac; then
            install_on_macos "exa"
        elif is_debian || is_ubuntu; then
            install_on_debian "exa"
        elif is_alpine; then
            install_on_alpine "exa"
        elif is_fedora; then
            install_on_fedora "exa"
        else
            logc "- {{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}eza{{RESET}}"
        return 1
        fi
    fi

}

function install_dust() {
    if has_command "dust"; then
        logc "- {{BOLD}}{{BLUE}}dust{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "dust" "du-dust"
    elif is_debian || is_ubuntu; then
        install_on_debian "du-dust" "dust"
    elif is_alpine; then
        install_on_alpine "du-dust" "dust"
    elif is_fedora; then
        install_on_fedora "du-dust" "dust"
    elif is_arch; then
        install_on_arch "du-dust" "dust"

    else
        logc "{{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}dust{{RESET}}"
        return 1
    fi
}

function install_deno() {
    if has_command "deno"; then
        logc "- {{BOLD}}{{BLUE}}Deno{{RESET}} is already installed"
        return 0
    fi
}

function install_rust() {
    if has_command "rustc"; then
        logc "- {{BOLD}}{{BLUE}}Rust{{RESET}} is already installed"
        return 0
    fi
}


function install_bun() {
    if has_command "bun"; then
        logc "- {{BOLD}}{{BLUE}}Bun{{RESET}} is already installed"
        return 0
    fi

    logc "- installing {{BOLD}}{{BLUE}}Bun{{RESET}}"
    log ""
    curl -fsSL https://bun.sh/install | bash
    log ""
    logc "- {{BOLD}}{{BLUE}}Bun{{RESET}} installed"
    log ""
}

function install_uv() {
    if has_command "uv"; then
        logc "- {{BOLD}}{{BLUE}}uv{{RESET}} is already installed"
        return 0
    fi

    if is_windows; then
        powershell -c "irm https://astral.sh/uv/install.ps1 | more" || (error "Failed to install ev!" 1)
    else
        logc "- installing {{BOLD}}{{BLUE}}uv{{RESET}}"
        curl -LsSf https://astral.sh/uv/install.sh | sh || (error "Failed to install uv!" 1)
    fi
    logc "- {{BOLD}}{{BLUE}}uv{{RESET}} installed"

}

install_ripgrep() {
    if has_command "rg"; then
        logc "- {{BOLD}}{{BLUE}}ripgrep{{RESET}} is already installed"
        return 0
    fi
    logc "- installing {{BOLD}}{{BLUE}}ripgrep{{RESET}}"
    if is_mac; then
        install_on_macos "ripgrep"
    elif is_debian || is_ubuntu; then
        install_on_debian "ripgrep"
    elif is_alpine; then
        install_on_alpine "ripgrep"
    elif is_fedora; then
        install_on_fedora "ripgrep"
    else
        logc "- {{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}ripgrep{{RESET}}"
        return 1
    fi
}

install_nvm() {
    logc "\nInstalling {{BOLD}}{{BLUE}}neovim{{RESET}}"

    if ! has_command "curl"; then
        logc "{{BOLD}}{{BLUE}}curl{{RESET}} is required to install {{BOLD}}{{BLUE}}nvm{{RESET}}."
        if confirm "Install curl now?"; then
            if ! install_curl; then
                error "Failed to install {{BOLD}}{{BLUE}}jq{{RESET}}" "${EXIT_API}"
            fi
        else
            logc "Ok. Quitting for now, you can install {{BOLD}}{{BLUE}}jq{{RESET}} and then run this command again.\n"
            # shellcheck disable=SC2086
            return ${EXIT_CONFIG}
        fi
    fi

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
}

install_yazi() {
    if has_command "yazi"; then
        logc "- {{BOLD}}{{BLUE}}yazi{{RESET}} is already installed"
        return 0
    fi

    logc "- installing {{BOLD}}{{BLUE}}yazi{{RESET}}"
    if is_mac; then
        install_on_macos "yazi"
    elif is_debian || is_ubuntu; then
        install_on_debian "yazi"
    elif is_alpine; then
        install_on_alpine "yazi"
    elif is_fedora; then
        install_on_fedora "yazi"
    else
        logc "- {{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}yazi{{RESET}}"
        return 1
    fi
}

install_claude_code() {
    if has_command "claude"; then
        logc "- {{BOLD}}{{BLUE}}Claude Code{{RESET}} is already installed"
        return 0
    fi

    logc "- installing {{BOLD}}{{BLUE}}Claude Code{{RESET}}"
    if is_windows; then
        irm https://claude.ai/install.ps1 | iex
    else
        curl -fsSL https://claude.ai/install.sh | bash || (error "failed to install Claude Code" 1)
    fi
}

install_gemini_cli() {
    if has_command "gemini"; then
        logc "- {{BOLD}}{{BLUE}}Gemini CLI{{RESET}} is already installed"
        return 0
    fi

    logc "- installing {{BOLD}}{{BLUE}}Gemini CLI{{RESET}}"
    if has_command "npm"; then
        npm install -g @google/gemini-cli || error "Failed to install Gemini CLI using npm" 1
        logc "- {{BOLD}}{{BLUE}}Gemini CLI{{RESET}} installed"
    elif has_command "nix-env"; then
        _try_nix_install "gemini-cli" || error "Failed to install Gemini CLI using nix"
    else
        logc "- the most common means of installing Gemini CLI is with {{BOLD}}{{BLUE}}npm{{RESET}} but {{BOLD}}{{BLUE}}npm{{RESET}} is not currently installed."
        if confirm "Install node and npm?"; then
            install_node
            if ! has_command "npm"; then
                install_npm
            fi
        else
            logc "Ok. Gemini CLI was {{RED}}not installed{{RESET}}. Install manually or rerun this command.\n"
        fi
    fi
}

install_npm() {
    if has_command "npm"; then
        logc "- {{BOLD}}{{BLUE}}npm CLI{{RESET}} is already installed"
        return 0
    fi
    if is_mac; then
        install_on_macos "npm"
    elif is_debian || is_ubuntu; then
        install_on_debian "npm"
    elif is_alpine; then
        install_on_alpine "npm"
    elif is_fedora; then
        install_on_fedora "npm"
    else
        logc "- {{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}npm{{RESET}}"
        return 1
    fi

}

install_node() {
    if has_command "node"; then
        logc "- {{BOLD}}{{BLUE}}node{{RESET}} is already installed"
        return 0
    fi

    logc "- installing {{BOLD}}{{BLUE}}node{{RESET}}"
    if is_mac; then
        install_on_macos "node" "nodejs_24"
    elif is_debian || is_ubuntu; then
        install_on_debian "nodejs" "nodejs_24"
    elif is_alpine; then
        install_on_alpine "nodejs" "nodejs_24"
    elif is_fedora; then
        install_on_fedora "nodejs" "node" "nodejs_24"
    else
        logc "- {{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}node{{RESET}}"
        return 1
    fi
}

install_cloudflared() {
    if is_debian; then
        # Add cloudflare gpg key
        ${SUDO} mkdir -p --mode=0755 /usr/share/keyrings
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | ${SUDO} tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

        # Add this repo to your apt repositories
        echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | ${SUDO} tee /etc/apt/sources.list.d/cloudflared.list

        # install cloudflared
        ${SUDO} apt-get update && ${SUDO} apt-get install cloudflared
    fi
}

install_git() {
    if has_command "git"; then
        logc "- {{BOLD}}{{BLUE}}git{{RESET}} is already installed"
        return 0
    else
        logc "- installing {{BOLD}}{{BLUE}}git{{RESET}}"
        if is_mac; then
            install_on_macos "git"
        elif is_debian || is_ubuntu; then
            install_on_debian "git"
        elif is_alpine; then
            install_on_alpine "git"
        elif is_fedora; then
            install_on_fedora "git"
        else
            logc "- {{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}git{{RESET}}"
            return 1
        fi
    fi
}

install_btop() {
    if has_command "btop"; then
        logc "- {{BOLD}}{{BLUE}}btop{{RESET}} is already installed"
        return 0
    fi

    logc "- installing {{BOLD}}{{BLUE}}yazi{{RESET}}"
    if is_mac; then
        install_on_macos "btop" "btopjs_24"
    elif is_debian || is_ubuntu; then
        install_on_debian "btop"
    elif is_alpine; then
        install_on_alpine "btop"
    elif is_fedora; then
        install_on_fedora "btop"
    else
        logc "- {{RED}}ERROR:{{RESET}}Unable to automate the install of {{BOLD}}{{BLUE}}btop{{RESET}}"
        return 1
    fi
}

install_starship() {
    if has_command "starship"; then
        logc "- {{BOLD}}{{BLUE}}starship{{RESET}} is already installed"
        return 0
    fi


    if is_linux || is_macos; then
        log "- installing ${BOLD}Starship${RESET} prompt"
        log ""
        curl -sS https://starship.rs/install.sh | sh
        log ""
        log "- ${ITALIC}source${RESET} your ${BOLD}${YELLOW}rc${RESET} file to start the prompt"
    else
        log "- please check the website on how to install ${BOLD}Starship${RESET}"
        log "  on your OS."
        log ""
        log "- https://starship.rs/installing/"
        log ""
    fi
}

# update_packages
#
# Updates package manager indexes/databases for all detected
# package managers on the system. Returns 0 if all updates
# succeed, 1 if any fail.
function update_packages() {
    local -i failed=0

    # Debian/Ubuntu: prefer nala over apt
    if has_command "nala"; then
        logc "- updating {{BOLD}}nala{{RESET}} package index..."
        ${SUDO} nala update || ((failed++))
    elif has_command "apt"; then
        logc "- updating {{BOLD}}apt{{RESET}} package index..."
        ${SUDO} apt update || ((failed++))
    fi

    # macOS: brew doesn't require sudo
    if has_command "brew"; then
        logc "- updating {{BOLD}}brew{{RESET}} package index..."
        brew update || ((failed++))
    fi

    # Alpine
    if has_command "apk"; then
        logc "- updating {{BOLD}}apk{{RESET}} package index..."
        ${SUDO} apk update || ((failed++))
    fi

    # Arch: prefer AUR helpers over plain pacman (they wrap pacman)
    if has_command "yay"; then
        logc "- updating {{BOLD}}yay{{RESET}} package index..."
        yay -Sy || ((failed++))
    elif has_command "paru"; then
        logc "- updating {{BOLD}}paru{{RESET}} package index..."
        paru -Sy || ((failed++))
    elif has_command "pacman"; then
        logc "- updating {{BOLD}}pacman{{RESET}} package index..."
        ${SUDO} pacman -Sy || ((failed++))
    fi

    # Fedora/RHEL: prefer dnf over yum
    if has_command "dnf"; then
        logc "- updating {{BOLD}}dnf{{RESET}} package index..."
        ${SUDO} dnf check-update || {
            # dnf check-update returns 100 if updates available, 0 if none, 1 on error
            local rc=$?
            [[ $rc -eq 1 ]] && ((failed++))
        }
    elif has_command "yum"; then
        logc "- updating {{BOLD}}yum{{RESET}} package index..."
        ${SUDO} yum check-update || {
            local rc=$?
            [[ $rc -eq 1 ]] && ((failed++))
        }
    fi

    # Nix: prefer flakes (nix profile) over traditional channels
    if has_command "nix"; then
        if nix profile list &>/dev/null; then
            # Flakes-based: no channel update needed, inputs are locked in flake.lock
            logc "- {{DIM}}nix (flakes): no index update needed{{RESET}}"
        elif has_command "nix-channel"; then
            logc "- updating {{BOLD}}nix{{RESET}} channels..."
            nix-channel --update || ((failed++))
        fi
    fi

    # Note: npm, gem, and cargo don't have separate "update index" operations
    # They query their registries directly during install/upgrade

    return $((failed > 0 ? 1 : 0))
}

# upgrade_packages
#
# Upgrades all installed packages using all detected package
# managers on the system. Returns 0 if all upgrades succeed,
# 1 if any fail.
function upgrade_packages() {
    local -i failed=0

    # Debian/Ubuntu: prefer nala over apt
    if has_command "nala"; then
        logc "- upgrading packages via {{BOLD}}nala{{RESET}}..."
        ${SUDO} nala upgrade -y || ((failed++))
    elif has_command "apt"; then
        logc "- upgrading packages via {{BOLD}}apt{{RESET}}..."
        ${SUDO} apt upgrade -y || ((failed++))
    fi

    # macOS: brew doesn't require sudo and has no -y flag
    if has_command "brew"; then
        logc "\n- upgrading packages via {{BOLD}}brew{{RESET}}..."
        brew upgrade || ((failed++))
    fi

    # Alpine
    if has_command "apk"; then
        logc "\n- upgrading packages via {{BOLD}}apk{{RESET}}..."
        ${SUDO} apk upgrade || ((failed++))
    fi

    # Arch: prefer AUR helpers over plain pacman (they wrap pacman)
    if has_command "yay"; then
        logc "\n- upgrading packages via {{BOLD}}yay{{RESET}}..."
        yay -Syu --noconfirm || ((failed++))
    elif has_command "paru"; then
        logc "\n- upgrading packages via {{BOLD}}paru{{RESET}}..."
        paru -Syu --noconfirm || ((failed++))
    elif has_command "pacman"; then
        logc "\n- upgrading packages via {{BOLD}}pacman{{RESET}}..."
        ${SUDO} pacman -Syu --noconfirm || ((failed++))
    fi

    # Fedora/RHEL: prefer dnf over yum
    if has_command "dnf"; then
        logc "\n- upgrading packages via {{BOLD}}dnf{{RESET}}..."
        ${SUDO} dnf upgrade -y || ((failed++))
    elif has_command "yum"; then
        logc "\n- upgrading packages via {{BOLD}}yum{{RESET}}..."
        ${SUDO} yum upgrade -y || ((failed++))
    fi

    # Nix: prefer flakes (nix profile) over traditional nix-env
    if has_command "nix"; then
        if nix profile list &>/dev/null; then
            logc "\n- upgrading {{BOLD}}nix profile{{RESET}} packages..."
            # '.*' is a regex matching all installed packages
            nix profile upgrade '.*' || ((failed++))
        elif has_command "nix-env"; then
            logc "\n- upgrading packages via {{BOLD}}nix-env{{RESET}}..."
            nix-env --upgrade || ((failed++))
        fi
    fi

    # npm global packages
    if has_command "npm"; then
        logc "\n- upgrading global {{BOLD}}npm{{RESET}} packages..."
        npm update -g || ((failed++))
    fi

    # pnpm global packages
    if has_command "pnpm"; then
        logc "\n- upgrading global {{BOLD}}pnpm{{RESET}} packages..."
        pnpm update -g || ((failed++))
    fi

    # bun: upgrade bun itself (no built-in "upgrade all globals")
    if has_command "bun"; then
        logc "\n- upgrading {{BOLD}}bun{{RESET}} itself..."
        bun upgrade || ((failed++))
    fi

    # Ruby gems
    if has_command "gem"; then
        logc "\n- upgrading {{BOLD}}gem{{RESET}} packages..."
        gem update || ((failed++))
    fi

    # Cargo: requires cargo-update crate (cargo install cargo-update)
    if has_command "cargo" && has_command "cargo-install-update"; then
        logc "\n- upgrading {{BOLD}}cargo{{RESET}} packages..."
        cargo install-update -a || ((failed++))
    fi

    # uv tools (Python)
    if has_command "uv"; then
        logc "\n- upgrading {{BOLD}}uv{{RESET}} tools..."
        uv tool upgrade --all || ((failed++))
    fi

    # pip: upgrade pip itself and use pip-review if available for all packages
    if has_command "pip"; then
        logc "- upgrading {{BOLD}}pip{{RESET}} itself..."
        pip install --upgrade pip || ((failed++))
        if has_command "pip-review"; then
            logc "- upgrading all {{BOLD}}pip{{RESET}} packages via pip-review..."
            pip-review --auto || ((failed++))
        fi
    fi

    return $((failed > 0 ? 1 : 0))
}


# Only run CLI if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    logc "{{BOLD}}install.sh"
fi
