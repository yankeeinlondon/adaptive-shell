#!/usr/bin/env bash

# First-run host bootstrap.
#
# The first time `adaptive.sh` is sourced on a host it asks, in turn,
# whether to install:
#
#   1. the Starship prompt (and a config showing `user@host`)
#   2. switching a Bash login shell to zsh or upgrading Bash 3
#   3. a set of core CLI utilities
#   4. Rust (via rustup) plus `cargo-binstall`
#   5. a set of AI agent CLIs (only when `curl` is available)
#
# Everything here is written for bash 3.2+ and runs in a bash child
# process -- `adaptive.sh` may be sourced from zsh, but the install logic
# never runs inside it.
#
# Every command that changes the host goes through `_bootstrap_exec` so
# tests can override that one function and record what would have run.

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__BOOTSTRAP_SH_LOADED:-}" ]] && declare -f "adaptive_bootstrap_run" > /dev/null && return
__BOOTSTRAP_SH_LOADED=1

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "${UTILS}" == *"/utils" ]]; then
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
# shellcheck source="./os.sh"
source "${UTILS}/os.sh"
# shellcheck source="./detection.sh"
source "${UTILS}/detection.sh"

# The core utilities offered by the bootstrap, in install order.
BOOTSTRAP_CORE_UTILS=(curl git wget fzf gh eza dust build-tools)

# The AI agent CLIs offered by the bootstrap, in install order.
BOOTSTRAP_AI_AGENTS=(claude codex opencode agy pi)

# Outcome tracking for the end-of-run summary.
BOOTSTRAP_INSTALLED=()
BOOTSTRAP_FAILED=()
# Manual follow-ups the bootstrap could not do itself.
BOOTSTRAP_TODO=()

# Package managers whose index has already been refreshed this run.
__BOOTSTRAP_REFRESHED=" "

# ---------------------------------------------------------------------------
# Host detection
# ---------------------------------------------------------------------------

# is_nixos
#
# Returns true when running on NixOS (not merely a host with Nix installed).
#
# ## Environment Variables
#
# - `ADAPTIVE_OS_RELEASE` -- path to the os-release file to inspect;
#   defaults to /etc/os-release (overridable for tests)
function is_nixos() {
    local -r os_release="${ADAPTIVE_OS_RELEASE:-/etc/os-release}"

    if [ -z "${ADAPTIVE_OS_RELEASE:-}" ] && [ -e /etc/NIXOS ]; then
        return 0
    fi
    if [ -r "${os_release}" ] && grep -qE '^ID="?nixos"?$' "${os_release}"; then
        return 0
    fi
    return 1
}

# host_pkg_manager
#
# Prints the name of the package manager the bootstrap installs with on
# this host: one of brew, port, apt, dnf, yum, pacman, apk, zypper, nix,
# winget, scoop or choco. Prints nothing (and returns 1) when none is
# found.
#
# ## Environment Variables
#
# - `ADAPTIVE_PKG_MANAGER` -- forces a specific manager
function host_pkg_manager() {
    if [ -n "${ADAPTIVE_PKG_MANAGER:-}" ]; then
        echo "${ADAPTIVE_PKG_MANAGER}"
        return 0
    fi

    local candidates=()
    if is_windows; then
        candidates=(winget scoop choco)
    elif is_mac; then
        candidates=(brew port)
    elif is_nixos; then
        candidates=(nix)
    else
        candidates=(apt dnf yum pacman apk zypper nix brew)
    fi

    local mgr probe
    for mgr in "${candidates[@]}"; do
        probe="${mgr}"
        case "${mgr}" in
            apt) probe="apt-get" ;;
            nix) probe="nix-env" ;;
        esac
        if has_command "${probe}"; then
            echo "${mgr}"
            return 0
        fi
    done

    return 1
}

# _bootstrap_exec <cmd> [args...]
#
# Runs a command that changes the host. Tests override this function to
# record calls instead of executing them.
function _bootstrap_exec() {
    "$@"
}

# _bootstrap_privileged <cmd> [args...]
#
# Runs a command as root: directly when already root (or on Windows),
# through `sudo` otherwise.
function _bootstrap_privileged() {
    if is_windows || [ "$(id -u 2> /dev/null || echo 0)" -eq 0 ]; then
        _bootstrap_exec "$@"
    elif has_command "sudo"; then
        _bootstrap_exec sudo "$@"
    else
        logc "- {{RED}}ERROR:{{RESET}} root access is needed for {{BOLD}}$1{{RESET}} but {{BOLD}}sudo{{RESET}} is not installed"
        return 1
    fi
}

# _bootstrap_refresh_path
#
# Prepends the directories the installers used here drop binaries into,
# so a freshly installed tool is found without starting a new shell.
function _bootstrap_refresh_path() {
    local -a dirs=(
        "${HOME}/.local/bin"
        "${HOME}/.cargo/bin"
        "${HOME}/.opencode/bin"
        "${HOME}/.nix-profile/bin"
        "/nix/var/nix/profiles/default/bin"
    )
    if is_mac; then
        dirs+=("/opt/homebrew/bin" "/usr/local/bin")
    fi
    if is_windows && [ -n "${LOCALAPPDATA:-}" ] && has_command "cygpath"; then
        local local_app_data
        local_app_data="$(cygpath -u "${LOCALAPPDATA}")"
        dirs+=(
            "${local_app_data}/Microsoft/WinGet/Links"
            "${local_app_data}/Programs/OpenAI/Codex/bin"
            "${local_app_data}/agy/bin"
            "${HOME}/scoop/shims"
        )
        if [ -n "${APPDATA:-}" ]; then
            dirs+=("$(cygpath -u "${APPDATA}")/npm")
        fi
    fi

    local dir
    for dir in "${dirs[@]}"; do
        if [ -d "${dir}" ]; then
            case ":${PATH}:" in
                *":${dir}:"*) ;;
                *) PATH="${dir}:${PATH}" ;;
            esac
        fi
    done
    export PATH
    hash -r 2> /dev/null || true
}

# ---------------------------------------------------------------------------
# Package specs
# ---------------------------------------------------------------------------

# spec_packages <manager> <spec> [<spec> ...]
#
# Given a list of `manager:package` specs, prints -- one per line, in
# order -- the package names that apply to `manager`.
function spec_packages() {
    local -r mgr="${1:?manager missing in call to spec_packages}"
    shift

    local spec
    for spec in "$@"; do
        if [[ "${spec%%:*}" == "${mgr}" ]]; then
            echo "${spec#*:}"
        fi
    done
}

# core_util_spec <tool>
#
# Prints the `manager:package` specs for one of the bootstrap's core
# utilities. `cargo:` entries are the fallback once Rust is installed.
function core_util_spec() {
    local -r tool="${1:?tool missing in call to core_util_spec}"
    local -a spec=()

    case "${tool}" in
        curl)
            spec=(brew:curl port:curl apt:curl dnf:curl yum:curl pacman:curl apk:curl zypper:curl nix:curl
                winget:cURL.cURL scoop:curl choco:curl)
            ;;
        git)
            spec=(brew:git port:git apt:git dnf:git yum:git pacman:git apk:git zypper:git nix:git
                winget:Git.Git scoop:git choco:git)
            ;;
        wget)
            spec=(brew:wget port:wget apt:wget dnf:wget2-wget dnf:wget yum:wget pacman:wget apk:wget zypper:wget nix:wget
                winget:JernejSimoncic.Wget scoop:wget choco:wget)
            ;;
        fzf)
            spec=(brew:fzf port:fzf apt:fzf dnf:fzf yum:fzf pacman:fzf apk:fzf zypper:fzf nix:fzf
                winget:junegunn.fzf scoop:fzf choco:fzf)
            ;;
        gh)
            spec=(brew:gh port:gh apt:gh dnf:gh yum:gh pacman:github-cli apk:github-cli zypper:gh nix:gh
                winget:GitHub.cli scoop:gh choco:gh)
            ;;
        eza)
            # `exa` is eza's unmaintained predecessor, still the only
            # option in older Debian/Ubuntu repos.
            spec=(brew:eza port:eza apt:eza apt:exa dnf:eza pacman:eza apk:eza zypper:eza nix:eza
                winget:eza-community.eza scoop:eza choco:eza cargo:eza)
            ;;
        dust)
            spec=(brew:dust port:dust apt:du-dust dnf:du-dust dnf:dust pacman:dust apk:dust zypper:dust nix:dust
                winget:bootandy.dust scoop:dust choco:dust cargo:du-dust)
            ;;
        *)
            return 1
            ;;
    esac

    printf '%s\n' "${spec[@]}"
}

# core_util_label <tool>
#
# Prints a short human-readable description of a core utility.
function core_util_label() {
    case "${1:-}" in
        eza) echo "eza (modern ls)" ;;
        dust) echo "dust (modern du)" ;;
        fzf) echo "fzf (fuzzy finder)" ;;
        gh) echo "gh (GitHub CLI)" ;;
        build-tools) echo "build tools (C/C++ compiler, make)" ;;
        *) echo "${1:-}" ;;
    esac
}

# _mac_clt_installed
#
# Returns true when the Xcode Command Line Tools are installed.
function _mac_clt_installed() {
    xcode-select -p > /dev/null 2>&1
}

# _windows_msvc_installed
#
# Returns true when the MSVC C/C++ build tools are installed.
function _windows_msvc_installed() {
    local program_files vswhere
    program_files="$(printenv 'ProgramFiles(x86)' 2> /dev/null || true)"
    [ -n "${program_files}" ] || return 1
    if has_command "cygpath"; then
        program_files="$(cygpath -u "${program_files}")"
    fi
    vswhere="${program_files}/Microsoft Visual Studio/Installer/vswhere.exe"
    [ -x "${vswhere}" ] || return 1
    [ -n "$("${vswhere}" -latest -products '*' \
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
        -property installationPath 2> /dev/null | tr -d '\r')" ]
}

# build_tools_present
#
# Returns true when a working C toolchain is already installed.
function build_tools_present() {
    if is_mac; then
        _mac_clt_installed
    elif is_windows; then
        _windows_msvc_installed
    else
        has_command "cc" && has_command "make"
    fi
}

# core_util_present <tool>
#
# Returns true when the given core utility is already installed.
function core_util_present() {
    local -r tool="${1:?tool missing in call to core_util_present}"

    case "${tool}" in
        build-tools) build_tools_present ;;
        eza) has_command "eza" || has_command "exa" ;;
        git)
            has_command "git" || return 1
            # On macOS /usr/bin/git is a shim that only works once the
            # Command Line Tools are installed.
            if is_mac && [[ "$(command -v git)" == "/usr/bin/git" ]]; then
                _mac_clt_installed
            fi
            ;;
        *) has_command "${tool}" ;;
    esac
}

# missing_core_utils
#
# Prints, one per line, the core utilities not yet installed.
function missing_core_utils() {
    local tool
    for tool in "${BOOTSTRAP_CORE_UTILS[@]}"; do
        if ! core_util_present "${tool}"; then
            echo "${tool}"
        fi
    done
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------

# pm_refresh <manager>
#
# Refreshes the package index of `manager` at most once per run. Fresh
# containers and cloud images ship with empty apt/apk indexes.
function pm_refresh() {
    local -r mgr="${1:?manager missing in call to pm_refresh}"

    case "${__BOOTSTRAP_REFRESHED}" in
        *" ${mgr} "*) return 0 ;;
    esac
    __BOOTSTRAP_REFRESHED="${__BOOTSTRAP_REFRESHED}${mgr} "

    case "${mgr}" in
        apt)
            if has_command "nala"; then
                _bootstrap_privileged nala update
            else
                _bootstrap_privileged apt-get update
            fi
            ;;
        apk) _bootstrap_privileged apk update ;;
        pacman) _bootstrap_privileged pacman -Sy --noconfirm ;;
        *) return 0 ;;
    esac
}

# _nix_profile_verb
#
# Prints the `nix profile` subcommand that adds a package: `add` on Nix
# 2.30+ (where `install` is a deprecated alias), `install` before that.
function _nix_profile_verb() {
    if nix --extra-experimental-features "nix-command flakes" profile add --help > /dev/null 2>&1; then
        echo "add"
    else
        echo "install"
    fi
}

# nix_install <pkg>
#
# Installs a nixpkgs package into the user's profile, using `nix profile`
# when the profile allows it and falling back to `nix-env`. Unfree
# packages (e.g. claude-code) are allowed.
#
# Note: on NixOS this is an imperative install; add the package to
# `configuration.nix` (or home-manager) to make it permanent.
function nix_install() {
    local -r pkg="${1:?package missing in call to nix_install}"

    if has_command "nix"; then
        if _bootstrap_exec env NIXPKGS_ALLOW_UNFREE=1 nix \
            --extra-experimental-features "nix-command flakes" \
            profile "$(_nix_profile_verb)" --impure "nixpkgs#${pkg}"; then
            return 0
        fi
    fi

    if has_command "nix-env"; then
        local channel
        for channel in nixos nixpkgs; do
            if _bootstrap_exec env NIXPKGS_ALLOW_UNFREE=1 nix-env -iA "${channel}.${pkg}"; then
                return 0
            fi
        done
    fi

    return 1
}

# pm_install <manager> <pkg>
#
# Installs one package with the named package manager, without prompting.
function pm_install() {
    local -r mgr="${1:?manager missing in call to pm_install}"
    local -r pkg="${2:?package missing in call to pm_install}"

    pm_refresh "${mgr}" || true

    case "${mgr}" in
        apt)
            if has_command "nala"; then
                _bootstrap_privileged nala install -y "${pkg}"
            else
                _bootstrap_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkg}"
            fi
            ;;
        dnf) _bootstrap_privileged dnf install -y "${pkg}" ;;
        yum) _bootstrap_privileged yum install -y "${pkg}" ;;
        pacman) _bootstrap_privileged pacman -S --needed --noconfirm "${pkg}" ;;
        apk) _bootstrap_privileged apk add "${pkg}" ;;
        zypper) _bootstrap_privileged zypper --non-interactive install "${pkg}" ;;
        brew) _bootstrap_exec brew install "${pkg}" ;;
        port) _bootstrap_privileged port -N install "${pkg}" ;;
        nix) nix_install "${pkg}" ;;
        winget)
            _bootstrap_exec winget install --exact --id "${pkg}" --silent \
                --accept-source-agreements --accept-package-agreements --disable-interactivity
            ;;
        scoop) _bootstrap_exec scoop install "${pkg}" ;;
        choco) _bootstrap_exec choco install -y "${pkg}" ;;
        *)
            logc "- {{RED}}ERROR:{{RESET}} unknown package manager {{BOLD}}${mgr}{{RESET}}"
            return 1
            ;;
    esac
}

# cargo_install <crate>
#
# Installs a crate's binaries, preferring prebuilt ones via
# `cargo-binstall` and falling back to compiling with `cargo install`.
function cargo_install() {
    local -r crate="${1:?crate missing in call to cargo_install}"

    if has_command "cargo-binstall"; then
        _bootstrap_exec cargo binstall --no-confirm "${crate}" && return 0
    fi
    if has_command "cargo"; then
        _bootstrap_exec cargo install --locked "${crate}" && return 0
    fi
    return 1
}

# install_from_spec <label> <spec> [<spec> ...]
#
# Installs a tool from a list of `manager:package` specs: each package
# listed for the host's package manager is tried in order, and `cargo:`
# specs are the fallback when Rust is available.
function install_from_spec() {
    local -r label="${1:?label missing in call to install_from_spec}"
    shift

    local mgr pkg
    mgr="$(host_pkg_manager)" || mgr=""

    if [ -n "${mgr}" ]; then
        while IFS= read -r pkg; do
            [ -n "${pkg}" ] || continue
            logc "- installing {{BOLD}}{{BLUE}}${label}{{RESET}} {{DIM}}(${mgr}: ${pkg}){{RESET}}"
            if pm_install "${mgr}" "${pkg}" < /dev/null; then
                return 0
            fi
        done <<< "$(spec_packages "${mgr}" "$@")"
    fi

    while IFS= read -r pkg; do
        [ -n "${pkg}" ] || continue
        if has_command "cargo"; then
            logc "- installing {{BOLD}}{{BLUE}}${label}{{RESET}} {{DIM}}(cargo: ${pkg}){{RESET}}"
            if cargo_install "${pkg}" < /dev/null; then
                return 0
            fi
        fi
    done <<< "$(spec_packages "cargo" "$@")"

    return 1
}

# install_homebrew
#
# Installs Homebrew on macOS using the official installer.
function install_homebrew() {
    if has_command "brew"; then
        return 0
    fi
    logc "- installing {{BOLD}}{{BLUE}}Homebrew{{RESET}}"
    _run_remote_script "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" bash || return 1
    local prefix
    for prefix in /opt/homebrew /usr/local; do
        if [ -x "${prefix}/bin/brew" ]; then
            eval "$("${prefix}/bin/brew" shellenv)"
            return 0
        fi
    done
    has_command "brew"
}

# install_build_tools_for_host
#
# Installs a C/C++ toolchain and make using the host's conventional
# meta-package: build-essential (Debian/Ubuntu), the development-tools
# group (Fedora/RHEL), base-devel (Arch), build-base (Alpine), the
# devel_basis pattern (openSUSE), the Xcode Command Line Tools (macOS),
# gcc/gnumake (NixOS) or the MSVC Build Tools (Windows).
function install_build_tools_for_host() {
    if build_tools_present; then
        return 0
    fi

    if is_mac; then
        logc "- requesting the {{BOLD}}{{BLUE}}Xcode Command Line Tools{{RESET}}"
        logc "  {{DIM}}a macOS dialog will open; finish it, then open a new shell{{RESET}}"
        _bootstrap_exec xcode-select --install
        return $?
    fi

    if is_windows; then
        logc "- installing the {{BOLD}}{{BLUE}}MSVC Build Tools{{RESET}} {{DIM}}(a large download){{RESET}}"
        _bootstrap_exec winget install --exact --id Microsoft.VisualStudio.2022.BuildTools --silent \
            --accept-source-agreements --accept-package-agreements --disable-interactivity \
            --override "--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
        return $?
    fi

    local mgr
    mgr="$(host_pkg_manager)" || mgr=""
    logc "- installing {{BOLD}}{{BLUE}}build tools{{RESET}} {{DIM}}(${mgr:-unknown}){{RESET}}"

    case "${mgr}" in
        apt) pm_install apt build-essential && pm_install apt pkg-config ;;
        dnf)
            pm_refresh dnf
            # dnf5 (Fedora 41+) spells it `group install development-tools`;
            # dnf4 (RHEL and older Fedora) uses `groupinstall`.
            _bootstrap_privileged dnf group install -y development-tools \
                || _bootstrap_privileged dnf groupinstall -y "Development Tools" \
                || true
            _bootstrap_privileged dnf install -y gcc gcc-c++ make pkgconf-pkg-config
            ;;
        yum)
            _bootstrap_privileged yum groupinstall -y "Development Tools" || true
            _bootstrap_privileged yum install -y gcc gcc-c++ make
            ;;
        pacman) pm_install pacman base-devel ;;
        apk) pm_install apk build-base ;;
        zypper) _bootstrap_privileged zypper --non-interactive install -t pattern devel_basis ;;
        nix) nix_install gcc && nix_install gnumake && nix_install pkg-config ;;
        *)
            logc "- {{RED}}ERROR:{{RESET}} no known way to install build tools on this host"
            return 1
            ;;
    esac
}

# install_core_util <tool>
#
# Installs one of the bootstrap's core utilities.
function install_core_util() {
    local -r tool="${1:?tool missing in call to install_core_util}"

    if core_util_present "${tool}"; then
        return 0
    fi

    if [[ "${tool}" == "build-tools" ]]; then
        install_build_tools_for_host
        return $?
    fi

    # The Command Line Tools provide git on macOS.
    if [[ "${tool}" == "git" ]] && is_mac && [[ "$(command -v git 2> /dev/null)" == "/usr/bin/git" ]]; then
        install_build_tools_for_host
        return $?
    fi

    local -a spec=()
    local line
    while IFS= read -r line; do
        [ -n "${line}" ] && spec+=("${line}")
    done <<< "$(core_util_spec "${tool}")"

    install_from_spec "$(core_util_label "${tool}")" "${spec[@]}" || return 1
    _bootstrap_refresh_path
    core_util_present "${tool}"
}

# install_core_utils [<tool> ...]
#
# Installs the given core utilities (default: every missing one) and
# records the outcome for the summary.
function install_core_utils() {
    local -a tools=("$@")
    if [ "${#tools[@]}" -eq 0 ]; then
        local line
        while IFS= read -r line; do
            [ -n "${line}" ] && tools+=("${line}")
        done <<< "$(missing_core_utils)"
    fi

    if is_mac && ! has_command "brew" && ! has_command "port"; then
        logc "- the core utilities are installed with {{BOLD}}Homebrew{{RESET}}, which is not installed"
        if confirm "Install Homebrew now?"; then
            install_homebrew || BOOTSTRAP_FAILED+=("Homebrew")
        fi
    fi

    local tool
    for tool in "${tools[@]}"; do
        if install_core_util "${tool}"; then
            BOOTSTRAP_INSTALLED+=("$(core_util_label "${tool}")")
        else
            logc "- {{YELLOW}}WARN:{{RESET}} could not install {{BOLD}}$(core_util_label "${tool}"){{RESET}}"
            BOOTSTRAP_FAILED+=("$(core_util_label "${tool}")")
        fi
    done
}

# _bootstrap_clear_failure <label>
#
# Removes `label` from the failures recorded for the summary (used when a
# later step installs it after all).
function _bootstrap_clear_failure() {
    local -r label="${1:?label missing in call to _bootstrap_clear_failure}"
    local -a kept=()
    local item
    for item in ${BOOTSTRAP_FAILED[@]+"${BOOTSTRAP_FAILED[@]}"}; do
        [[ "${item}" == "${label}" ]] || kept+=("${item}")
    done
    BOOTSTRAP_FAILED=(${kept[@]+"${kept[@]}"})
}

# retry_core_utils_with_cargo
#
# Once Rust is available, retries the core utilities that have a crate
# (eza, dust) and are still missing -- e.g. when the distro does not
# package them.
function retry_core_utils_with_cargo() {
    has_command "cargo" || return 0

    local tool crate
    for tool in eza dust; do
        core_util_present "${tool}" && continue
        # shellcheck disable=SC2046 # word-splitting the spec list is intended
        crate="$(spec_packages cargo $(core_util_spec "${tool}") | head -n 1)"
        [ -n "${crate}" ] || continue
        logc "- retrying {{BOLD}}{{BLUE}}$(core_util_label "${tool}"){{RESET}} with cargo"
        if cargo_install "${crate}" < /dev/null && core_util_present "${tool}"; then
            BOOTSTRAP_INSTALLED+=("$(core_util_label "${tool}") (cargo)")
            _bootstrap_clear_failure "$(core_util_label "${tool}")"
        fi
    done
}

# ---------------------------------------------------------------------------
# Remote installers
# ---------------------------------------------------------------------------

# _run_remote_script <url> <interpreter> [args...]
#
# Downloads an installer script to a temp file and runs it with
# `interpreter`. Unlike `curl | sh` a failed download is detected, and the
# installer's stdin stays attached to the terminal.
function _run_remote_script() {
    local -r url="${1:?url missing in call to _run_remote_script}"
    local -r interpreter="${2:?interpreter missing in call to _run_remote_script}"
    shift 2

    if ! has_command "curl"; then
        logc "- {{RED}}ERROR:{{RESET}} {{BOLD}}curl{{RESET}} is needed to download ${url}"
        return 1
    fi

    local tmp rc
    tmp="$(mktemp "${TMPDIR:-/tmp}/adaptive-installer.XXXXXX")" || return 1
    if ! _bootstrap_exec curl --proto '=https' --tlsv1.2 -fsSL -o "${tmp}" "${url}"; then
        logc "- {{RED}}ERROR:{{RESET}} failed to download ${url}"
        rm -f "${tmp}"
        return 1
    fi
    _bootstrap_exec "${interpreter}" "${tmp}" "$@"
    rc=$?
    rm -f "${tmp}"
    return ${rc}
}

# _run_powershell_installer <url>
#
# Runs a PowerShell installer script (`irm <url> | iex`) on Windows.
function _run_powershell_installer() {
    local -r url="${1:?url missing in call to _run_powershell_installer}"
    local ps="powershell.exe"
    has_command "powershell.exe" || ps="powershell"
    # stdin from /dev/null: PowerShell otherwise reads the shell's stdin.
    _bootstrap_exec "${ps}" -NoProfile -ExecutionPolicy Bypass -Command "irm ${url} | iex" < /dev/null
}

# ---------------------------------------------------------------------------
# Rust
# ---------------------------------------------------------------------------

# install_rust_toolchain
#
# Installs Rust via rustup: the official rustup-init on macOS, Linux and
# Windows; rustup from nixpkgs on NixOS (rustup's own downloads are not
# patched for NixOS).
function install_rust_toolchain() {
    if has_command "cargo"; then
        return 0
    fi

    logc "- installing {{BOLD}}{{BLUE}}Rust{{RESET}} {{DIM}}(rustup, stable toolchain){{RESET}}"

    if is_nixos; then
        nix_install rustup || return 1
        _bootstrap_refresh_path
        _bootstrap_exec rustup default stable || return 1
    elif is_windows; then
        local arch="x86_64" tmp
        [[ "${PROCESSOR_ARCHITECTURE:-}" == "ARM64" ]] && arch="aarch64"
        tmp="$(mktemp -d "${TMPDIR:-/tmp}/rustup.XXXXXX")" || return 1
        _bootstrap_exec curl --proto '=https' --tlsv1.2 -fsSL -o "${tmp}/rustup-init.exe" \
            "https://win.rustup.rs/${arch}" || return 1
        chmod +x "${tmp}/rustup-init.exe" 2> /dev/null || true
        _bootstrap_exec "${tmp}/rustup-init.exe" -y || return 1
        rm -rf "${tmp}"
    else
        _run_remote_script "https://sh.rustup.rs" sh -y < /dev/null || return 1
    fi

    _bootstrap_refresh_path
    has_command "cargo"
}

# install_cargo_binstall
#
# Installs `cargo-binstall` with `cargo install`, which compiles it and so
# needs a C toolchain/linker -- installed first when missing (except on
# Windows, where the MSVC Build Tools are a separate, multi-GB choice).
function install_cargo_binstall() {
    if has_command "cargo-binstall"; then
        return 0
    fi
    has_command "cargo" || return 1

    if ! build_tools_present && ! is_windows; then
        logc "- {{DIM}}compiling cargo-binstall needs a C toolchain; installing build tools first{{RESET}}"
        install_build_tools_for_host || return 1
    fi

    logc "- installing {{BOLD}}{{BLUE}}cargo-binstall{{RESET}} {{DIM}}(cargo install --locked cargo-binstall){{RESET}}"
    _bootstrap_exec cargo install --locked cargo-binstall < /dev/null || return 1
    _bootstrap_refresh_path
    has_command "cargo-binstall"
}

# ---------------------------------------------------------------------------
# AI agents
# ---------------------------------------------------------------------------

# ai_agent_label <agent>
#
# Prints the display name of one of the bootstrap's AI agent CLIs.
function ai_agent_label() {
    case "${1:-}" in
        claude) echo "Claude Code" ;;
        codex) echo "Codex CLI" ;;
        opencode) echo "OpenCode" ;;
        agy) echo "Antigravity CLI" ;;
        pi) echo "Pi" ;;
        *) echo "${1:-}" ;;
    esac
}

# missing_ai_agents
#
# Prints, one per line, the AI agent CLIs (by command name) not yet
# installed.
function missing_ai_agents() {
    local agent
    for agent in "${BOOTSTRAP_AI_AGENTS[@]}"; do
        if ! has_command "${agent}"; then
            echo "${agent}"
        fi
    done
}

# ai_agent_nix_package <agent>
#
# Prints the nixpkgs attribute for an agent, or nothing when nixpkgs has
# no package for it.
function ai_agent_nix_package() {
    case "${1:-}" in
        claude) echo "claude-code" ;;
        codex) echo "codex" ;;
        opencode) echo "opencode" ;;
        pi) echo "pi-coding-agent" ;;
        *) return 1 ;;
    esac
}

# _nixos_runs_generic_binaries
#
# Returns true when this NixOS host can run generic (FHS, glibc) Linux
# binaries -- i.e. nix-ld has put a dynamic loader at the standard path.
function _nixos_runs_generic_binaries() {
    [ -e /lib64/ld-linux-x86-64.so.2 ] || [ -e /lib/ld-linux-aarch64.so.1 ]
}

# _node_at_least <major> <minor>
#
# Returns true when `node` is installed at version >= major.minor.
function _node_at_least() {
    local -r want_major="${1:?}" want_minor="${2:?}"
    has_command "node" || return 1

    local version major minor
    version="$(node --version 2> /dev/null)" || return 1
    version="${version#v}"
    major="${version%%.*}"
    minor="${version#*.}"
    minor="${minor%%.*}"
    [[ "${major}" =~ ^[0-9]+$ && "${minor}" =~ ^[0-9]+$ ]] || return 1

    [ "${major}" -gt "${want_major}" ] \
        || { [ "${major}" -eq "${want_major}" ] && [ "${minor}" -ge "${want_minor}" ]; }
}

# _npm_global_writable
#
# Returns true when `npm install -g` can write without root.
function _npm_global_writable() {
    has_command "npm" || return 1
    local prefix
    prefix="$(npm prefix -g 2> /dev/null)" || return 1
    [ -n "${prefix}" ] && [ -w "${prefix}" ]
}

# install_ai_agent <agent>
#
# Installs one AI agent CLI with its official installer: the
# `curl | sh` script on macOS/Linux, the PowerShell script on Windows.
# NixOS prefers nixpkgs, since the installers download generic Linux
# binaries.
function install_ai_agent() {
    local -r agent="${1:?agent missing in call to install_ai_agent}"

    if has_command "${agent}"; then
        return 0
    fi

    logc "- installing {{BOLD}}{{BLUE}}$(ai_agent_label "${agent}"){{RESET}}"

    if is_nixos; then
        local nix_pkg
        if nix_pkg="$(ai_agent_nix_package "${agent}")" && nix_install "${nix_pkg}"; then
            _bootstrap_refresh_path
            has_command "${agent}" && return 0
        fi
        # The official installers download generic glibc binaries, which
        # NixOS can only run through nix-ld's loader.
        if ! _nixos_runs_generic_binaries; then
            logc "  {{YELLOW}}$(ai_agent_label "${agent}"){{RESET}} is not in nixpkgs, and its installer ships a generic Linux binary"
            logc "  that NixOS cannot run without nix-ld. Add {{BOLD}}programs.nix-ld.enable = true;{{RESET}} to"
            logc "  configuration.nix, run {{BOLD}}nixos-rebuild switch{{RESET}}, then {{BOLD}}{{BLUE}}adaptive_bootstrap{{RESET}}."
            return 1
        fi
        logc "  {{DIM}}not available from nixpkgs; using the official installer (nix-ld is enabled){{RESET}}"
    fi

    local rc=0
    case "${agent}" in
        claude)
            if is_windows; then
                _run_powershell_installer "https://claude.ai/install.ps1" || rc=$?
            else
                _run_remote_script "https://claude.ai/install.sh" bash < /dev/null || rc=$?
            fi
            ;;
        codex)
            if is_windows; then
                _run_powershell_installer "https://chatgpt.com/codex/install.ps1" || rc=$?
            else
                # Non-interactive skips the installer's closing "Start Codex
                # now?" -- an agent launched in the middle of setup.
                (
                    export CODEX_NON_INTERACTIVE=1
                    _run_remote_script "https://chatgpt.com/codex/install.sh" sh < /dev/null
                ) || rc=$?
            fi
            ;;
        opencode)
            if is_windows; then
                if has_command "npm"; then
                    _bootstrap_exec npm install -g opencode-ai || rc=$?
                elif has_command "scoop"; then
                    _bootstrap_exec scoop install opencode || rc=$?
                else
                    pm_install winget SST.opencode || rc=$?
                fi
            else
                _run_remote_script "https://opencode.ai/install" bash < /dev/null || rc=$?
            fi
            ;;
        agy)
            if is_windows; then
                _run_powershell_installer "https://antigravity.google/cli/install.ps1" || rc=$?
            else
                _run_remote_script "https://antigravity.google/cli/install.sh" bash < /dev/null || rc=$?
            fi
            ;;
        pi)
            # Pi's own installer ends by asking "Start pi now? [Y/n]" on the
            # terminal and launching it -- in the middle of shell startup.
            # When a new enough Node is already here, install with npm.
            if _node_at_least 22 19 && _npm_global_writable; then
                _bootstrap_exec npm install -g --ignore-scripts @earendil-works/pi-coding-agent || rc=$?
            elif is_windows; then
                _run_powershell_installer "https://pi.dev/install.ps1" || rc=$?
            else
                logc "  {{DIM}}the Pi installer may offer to start pi when done -- answer {{BOLD}}n{{RESET}}{{DIM}} to continue setup{{RESET}}"
                _run_remote_script "https://pi.dev/install.sh" sh || rc=$?
            fi
            ;;
        *)
            logc "- {{RED}}ERROR:{{RESET}} unknown AI agent {{BOLD}}${agent}{{RESET}}"
            return 1
            ;;
    esac

    [ "${rc}" -eq 0 ] || return "${rc}"
    _bootstrap_refresh_path
    if ! has_command "${agent}"; then
        logc "  {{DIM}}installer finished; {{BOLD}}${agent}{{RESET}}{{DIM}} will be on PATH in a new shell{{RESET}}"
    fi
    return 0
}

# install_ai_agents [<agent> ...]
#
# Installs the given AI agents (default: every missing one) and records
# the outcome for the summary.
function install_ai_agents() {
    local -a agents=("$@")
    if [ "${#agents[@]}" -eq 0 ]; then
        local line
        while IFS= read -r line; do
            [ -n "${line}" ] && agents+=("${line}")
        done <<< "$(missing_ai_agents)"
    fi

    local agent
    for agent in "${agents[@]}"; do
        if install_ai_agent "${agent}"; then
            BOOTSTRAP_INSTALLED+=("$(ai_agent_label "${agent}")")
        else
            logc "- {{YELLOW}}WARN:{{RESET}} could not install {{BOLD}}$(ai_agent_label "${agent}"){{RESET}}"
            BOOTSTRAP_FAILED+=("$(ai_agent_label "${agent}")")
        fi
    done
}

# ---------------------------------------------------------------------------
# Starship
# ---------------------------------------------------------------------------

# starship_config_path
#
# Prints the path Starship reads its config from.
function starship_config_path() {
    if [ -n "${STARSHIP_CONFIG:-}" ]; then
        echo "${STARSHIP_CONFIG}"
    else
        echo "${XDG_CONFIG_HOME:-${HOME}/.config}/starship.toml"
    fi
}

# _toml_section <file> <section>
#
# Prints one `[section]` (header plus body, up to the next header) of a
# TOML file.
function _toml_section() {
    awk -v want="[$2]" '
        /^\[/ { inside = ($0 == want) }
        inside { print }
    ' "$1"
}

# configure_starship_prompt
#
# Makes the Starship prompt show `user@host` -- with `@host` dimmed -- and
# hides the container module's `[Systemd]` entry.
#
# With no config yet, installs `resources/starship.toml`. An existing
# config is never rewritten: only the [username], [hostname] and
# [container] sections it lacks are appended.
function configure_starship_prompt() {
    local -r template="${ROOT}/resources/starship.toml"
    local config
    config="$(starship_config_path)"

    if [ ! -f "${template}" ]; then
        logc "- {{RED}}ERROR:{{RESET}} missing Starship template at ${template}"
        return 1
    fi

    if [ ! -f "${config}" ]; then
        mkdir -p "$(dirname "${config}")" || return 1
        cp "${template}" "${config}" || return 1
        logc "- wrote the Starship config to {{BLUE}}${config}{{RESET}}"
        return 0
    fi

    local section added=""
    for section in username hostname container; do
        if grep -qE "^\[${section}\][[:space:]]*$" "${config}"; then
            continue
        fi
        {
            printf '\n'
            _toml_section "${template}" "${section}"
        } >> "${config}"
        added="${added} [${section}]"
    done

    if [ -n "${added}" ]; then
        logc "- added{{BOLD}}${added}{{RESET}} to the Starship config at {{BLUE}}${config}{{RESET}}"
    else
        logc "- {{DIM}}the Starship config at ${config} already sets [username], [hostname] and [container]; left unchanged{{RESET}}"
    fi
}

# install_starship_for_host
#
# Installs Starship: winget on Windows, nixpkgs on NixOS, otherwise
# `install_starship` from install.sh (brew or the official script).
function install_starship_for_host() {
    if has_command "starship"; then
        return 0
    fi

    if is_windows; then
        pm_install winget Starship.Starship || return 1
    elif is_nixos; then
        logc "- installing {{BOLD}}{{BLUE}}Starship{{RESET}} {{DIM}}(nixpkgs){{RESET}}"
        nix_install starship || return 1
    else
        # The script-based install needs curl. Install it here, where
        # privileges are handled, rather than letting install.sh try.
        if ! is_mac && ! has_command "curl"; then
            install_core_util curl || return 1
        fi
        # install.sh runs package managers through a global `${SUDO}`
        # that utils.sh normally sets.
        if [ -z "${SUDO+set}" ]; then
            if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
        fi
        # shellcheck source="./install.sh"
        source "${UTILS}/install.sh"
        install_starship < /dev/null || return 1
    fi

    _bootstrap_refresh_path
    has_command "starship"
}

# ---------------------------------------------------------------------------
# Shell setup
# ---------------------------------------------------------------------------

# login_shell
#
# Prints the current user's login shell as recorded for the account
# (`dscl` on macOS, the passwd database elsewhere), falling back to
# `$SHELL`. Prints nothing and fails on Windows, which has no login shell
# to change.
function login_shell() {
    local -r user="${USER:-$(id -un 2> /dev/null)}"
    local sh=""

    if is_windows; then
        return 1
    fi

    if is_mac; then
        sh="$(dscl . -read "/Users/${user}" UserShell 2> /dev/null | awk '{print $2}')"
    elif has_command "getent"; then
        sh="$(getent passwd "${user}" 2> /dev/null | cut -d: -f7)"
    elif [ -r /etc/passwd ]; then
        sh="$(awk -F: -v u="${user}" '$1 == u { print $7 }' /etc/passwd)"
    fi
    [ -n "${sh}" ] || sh="${SHELL:-}"

    [ -n "${sh}" ] || return 1
    echo "${sh}"
}

# install_zsh_for_host
#
# Installs zsh with the host's package manager (macOS already ships
# /bin/zsh).
function install_zsh_for_host() {
    if has_command "zsh"; then
        return 0
    fi

    install_from_spec "zsh" brew:zsh port:zsh apt:zsh dnf:zsh yum:zsh pacman:zsh apk:zsh zypper:zsh nix:zsh \
        || return 1
    _bootstrap_refresh_path
    has_command "zsh"
}

# zsh_path
#
# Prints the absolute path of the zsh to use as a login shell: the
# system /bin/zsh on macOS; otherwise a zsh /etc/shells already lists
# (its canonical path -- on Fedora root's PATH finds /usr/sbin/zsh
# through the merged sbin, which is not); otherwise the one on PATH.
function zsh_path() {
    local -r shells_file="${ADAPTIVE_ETC_SHELLS:-/etc/shells}"

    if is_mac && [ -x /bin/zsh ]; then
        echo "/bin/zsh"
        return 0
    fi

    local listed
    if [ -r "${shells_file}" ]; then
        while IFS= read -r listed; do
            case "${listed}" in
                /*/zsh)
                    if [ -x "${listed}" ]; then
                        echo "${listed}"
                        return 0
                    fi
                    ;;
            esac
        done < "${shells_file}"
    fi

    command -v zsh 2> /dev/null
}

# _ensure_in_etc_shells <path>
#
# Adds `path` to /etc/shells when it is missing; `chsh` refuses shells
# that are not listed there.
function _ensure_in_etc_shells() {
    local -r shell_path="${1:?path missing in call to _ensure_in_etc_shells}"
    local -r shells_file="${ADAPTIVE_ETC_SHELLS:-/etc/shells}"

    if [ -r "${shells_file}" ] && grep -qxF "${shell_path}" "${shells_file}"; then
        return 0
    fi
    logc "- adding {{BLUE}}${shell_path}{{RESET}} to ${shells_file}"
    printf '%s\n' "${shell_path}" | _bootstrap_privileged tee -a "${shells_file}" > /dev/null
}

# set_login_shell <path>
#
# Changes the current user's login shell with `chsh`, or `usermod -s`
# where chsh is not installed (e.g. minimal Fedora images).
function set_login_shell() {
    local -r shell_path="${1:?path missing in call to set_login_shell}"
    local -r user="${USER:-$(id -un 2> /dev/null)}"

    if has_command "chsh"; then
        if is_mac || [ "$(id -u)" -eq 0 ] || ! has_command "sudo"; then
            # macOS (and a non-root user without sudo) authenticate with
            # the user's own password.
            _bootstrap_exec chsh -s "${shell_path}" "${user}"
        else
            _bootstrap_privileged chsh -s "${shell_path}" "${user}"
        fi
    elif has_command "usermod"; then
        _bootstrap_privileged usermod -s "${shell_path}" "${user}"
    else
        logc "- {{RED}}ERROR:{{RESET}} neither {{BOLD}}chsh{{RESET}} nor {{BOLD}}usermod{{RESET}} is available to change the login shell"
        return 1
    fi
}

# configure_zsh_for_user
#
# Gives the user a ~/.zshrc (honoring ZDOTDIR) that keeps a shared,
# de-duplicated history and sources adaptive.sh -- which also keeps
# zsh's first-run `zsh-newuser-install` wizard from appearing.
#
# The settings live in a marked block; an existing ~/.zshrc that already
# sources adaptive.sh is left alone.
function configure_zsh_for_user() {
    local -r zshrc="${ZDOTDIR:-${HOME}}/.zshrc"
    local -r begin="# >>> adaptive-shell >>>"
    local adaptive="${ADAPTIVE_SHELL:-${ROOT}}/adaptive.sh"

    if [ -f "${zshrc}" ] && grep -qF "adaptive.sh" "${zshrc}"; then
        logc "- {{DIM}}${zshrc} already sources adaptive.sh; left unchanged{{RESET}}"
        return 0
    fi

    # Write the path relative to $HOME so the file survives a moved home.
    case "${adaptive}" in
        "${HOME}"/*) adaptive="\${HOME}${adaptive#"${HOME}"}" ;;
    esac

    mkdir -p "$(dirname "${zshrc}")" || return 1
    {
        [ -s "${zshrc}" ] && printf '\n'
        printf '%s\n' "${begin}"
        printf '%s\n' '# History: large, shared between sessions, without duplicates.'
        printf '%s\n' 'HISTFILE="${HISTFILE:-${HOME}/.zsh_history}"'
        printf '%s\n' 'HISTSIZE=50000'
        printf '%s\n' 'SAVEHIST=50000'
        printf '%s\n' 'setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE'
        printf '\n'
        printf 'source "%s"\n' "${adaptive}"
        printf '%s\n' "# <<< adaptive-shell <<<"
    } >> "${zshrc}" || return 1

    logc "- configured {{BLUE}}${zshrc}{{RESET}} to load adaptive-shell"
}

# switch_to_zsh
#
# Installs zsh, configures it for the user and makes it their login
# shell. On NixOS the login shell is declared in configuration.nix, so
# that last part becomes a printed follow-up.
function switch_to_zsh() {
    if ! has_command "zsh"; then
        logc "- installing {{BOLD}}{{BLUE}}zsh{{RESET}}"
        if install_zsh_for_host; then
            BOOTSTRAP_INSTALLED+=("zsh")
        else
            BOOTSTRAP_FAILED+=("zsh")
            return 1
        fi
    fi

    configure_zsh_for_user || BOOTSTRAP_FAILED+=("zsh config (.zshrc)")

    if is_nixos; then
        logc "- on NixOS the login shell is declared in {{BOLD}}configuration.nix{{RESET}}; add:"
        logc "    {{BOLD}}programs.zsh.enable = true;{{RESET}}"
        logc "    {{BOLD}}users.users.${USER:-<you>}.shell = pkgs.zsh;{{RESET}}"
        logc "  then run {{BOLD}}sudo nixos-rebuild switch{{RESET}}"
        BOOTSTRAP_TODO+=("set zsh as the login shell in configuration.nix")
        return 0
    fi

    local shell_path
    shell_path="$(zsh_path)"
    if [ -z "${shell_path}" ]; then
        BOOTSTRAP_FAILED+=("login shell -> zsh")
        return 1
    fi

    if _ensure_in_etc_shells "${shell_path}" && set_login_shell "${shell_path}"; then
        BOOTSTRAP_INSTALLED+=("login shell -> zsh")
        logc "- login shell is now {{BOLD}}${shell_path}{{RESET}} {{DIM}}(from your next login; {{BOLD}}exec zsh{{RESET}}{{DIM}} starts it now){{RESET}}"
    else
        logc "- {{YELLOW}}WARN:{{RESET}} could not change the login shell; run {{BOLD}}chsh -s ${shell_path}{{RESET}} yourself"
        BOOTSTRAP_FAILED+=("login shell -> zsh")
        return 1
    fi
}

# bash_major_version <shell>
#
# Prints the major version of a Bash executable without loading startup files.
function bash_major_version() {
    BASH_ENV=/dev/null "${1:?Bash executable missing}" --noprofile --norc -c 'printf "%s\n" "${BASH_VERSINFO[0]}"'
}

# modern_bash_path [login_bash]
#
# Prints the first Bash 4+ executable, even when an older Bash precedes it on PATH.
function modern_bash_path() {
    local shell_path brew_prefix
    while IFS= read -r shell_path; do
        [[ "${shell_path}" == /* ]] && [ -x "${shell_path}" ] || continue
        if [ "$(bash_major_version "${shell_path}")" -ge 4 ] 2> /dev/null; then
            printf '%s\n' "${shell_path}"
            return 0
        fi
    done < <(
        printf '%s\n' "${1:-}"
        type -aP bash
        if is_mac; then
            printf '%s\n' /opt/local/bin/bash
            if has_command brew && brew_prefix="$(brew --prefix bash 2> /dev/null)"; then
                printf '%s/bin/bash\n' "${brew_prefix}"
            fi
        fi
    )
    return 1
}

# bootstrap_step_bash <running_version> <login_shell>
#
# Offers modern Bash when Bash 3 is the running or configured login shell.
function bootstrap_step_bash() {
    local -r running_version="${1:-}" current="${2:-}"
    local login_bash="" login_major="" shell_path question start_command

    if [[ "${current##*/}" == bash ]] && [ -x "${current}" ]; then
        login_bash="${current}"
        login_major="$(bash_major_version "${login_bash}")" || login_major=""
    fi

    if [ -n "${running_version}" ]; then
        logc "- running Bash ${running_version%%(*}"
    else
        logc "- bootstrap is using Bash ${BASH_VERSION%%(*}"
    fi
    if [ -n "${login_major}" ]; then
        logc "- login shell uses Bash major version ${login_major}"
    fi
    if is_windows; then
        logc "- Bash upgrades are managed by Git for Windows"
        return 0
    fi
    if [[ "${running_version}" != 3.* && "${login_major}" != 3 ]]; then
        logc "- Bash upgrade skipped (requires Bash 3 as the running or login shell)"
        return 0
    fi

    shell_path="$(modern_bash_path "${login_bash}")" || shell_path=""
    if [ -z "${shell_path}" ]; then
        question="Bash 3 detected. Install Bash 4 or newer?"
        if [ "${login_major}" = 3 ]; then
            question="Bash 3 detected. Install Bash 4 or newer and use it as your login shell?"
        fi
        if ! confirm "${question}" n; then
            logc "- Bash upgrade declined"
            return 0
        fi

        if is_mac && ! has_command brew && ! has_command port; then
            if ! confirm "Install Homebrew to install Bash?" n; then
                logc "- Bash installation skipped because Homebrew setup was declined"
                return 0
            fi
            if ! install_homebrew; then
                BOOTSTRAP_FAILED+=("Homebrew")
                return 1
            fi
        fi

        if install_from_spec "Bash" brew:bash port:bash apt:bash dnf:bash yum:bash pacman:bash apk:bash zypper:bash nix:bashInteractive; then
            _bootstrap_refresh_path
            shell_path="$(modern_bash_path "${login_bash}")" || shell_path=""
        fi
        if [ -z "${shell_path}" ]; then
            logc "- {{YELLOW}}WARN:{{RESET}} could not find Bash 4 or newer after installation"
            BOOTSTRAP_FAILED+=("Bash")
            return 1
        fi
        BOOTSTRAP_INSTALLED+=("Bash")
    else
        logc "- modern Bash is already installed at ${shell_path}"
        if [ "${login_major}" = 3 ] && ! confirm "Bash 3 detected. Use ${shell_path} as your login shell?" n; then
            logc "- Bash login shell upgrade declined"
            return 0
        fi
    fi

    printf -v start_command 'exec %q -l' "${shell_path}"
    logc "- start modern Bash in this terminal with {{BOLD}}${start_command}{{RESET}}"

    if [ "${login_major}" = 3 ] && [ "${shell_path}" != "${current}" ]; then
        if is_nixos; then
            logc "- set {{BOLD}}users.users.${USER:-<you>}.shell = pkgs.bashInteractive;{{RESET}} in configuration.nix, then run {{BOLD}}sudo nixos-rebuild switch{{RESET}}"
            BOOTSTRAP_TODO+=("set Bash as the login shell in configuration.nix")
        elif _ensure_in_etc_shells "${shell_path}" && set_login_shell "${shell_path}"; then
            logc "- your next login will use {{BOLD}}${shell_path}{{RESET}}"
            BOOTSTRAP_INSTALLED+=("login shell -> Bash")
        else
            logc "- {{YELLOW}}WARN:{{RESET}} could not set ${shell_path} as the login shell"
            BOOTSTRAP_FAILED+=("login shell -> Bash")
            return 1
        fi
    fi
}

# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

# _bootstrap_join <item> [<item> ...]
#
# Prints the items joined with ", " (pure bash; no external tools).
function _bootstrap_join() {
    local joined="" item
    for item in "$@"; do
        joined="${joined:+${joined}, }${item}"
    done
    printf '%s' "${joined}"
}

# _bootstrap_list <item> [<item> ...]
#
# Logs each item as an indented bullet.
function _bootstrap_list() {
    local item
    for item in "$@"; do
        logc "    {{DIM}}•{{RESET}} ${item}"
    done
}

# bootstrap_step_starship
#
# Step 1: offers to install Starship, then configures its prompt.
function bootstrap_step_starship() {
    logc "\n{{BOLD}}1. Prompt{{RESET}}"
    if has_command "starship"; then
        logc "- {{BOLD}}starship{{RESET}} is already installed"
        configure_starship_prompt
        return 0
    fi

    logc "- {{BOLD}}{{GREEN}}starship{{RESET}} -- the prompt this config expects -- is not installed"
    if confirm "Install Starship?"; then
        if install_starship_for_host; then
            BOOTSTRAP_INSTALLED+=("Starship")
            configure_starship_prompt
        else
            BOOTSTRAP_FAILED+=("Starship")
        fi
    fi
}

# bootstrap_step_shell [running_bash_version]
#
# Step 2: offers to switch a Bash login shell to zsh or upgrade Bash 3.
function bootstrap_step_shell() {
    logc "\n{{BOLD}}2. Shell{{RESET}}"

    local current
    if ! current="$(login_shell)"; then
        logc "- {{DIM}}skipped: no login shell to change on this host{{RESET}}"
    else
        logc "- login shell is {{BOLD}}${current##*/}{{RESET}} {{DIM}}(${current}){{RESET}}"
        if [[ "${current##*/}" == bash ]] && confirm "Do you want to switch to zsh?"; then
            logc "- Bash upgrade skipped because you chose zsh"
            switch_to_zsh
            return
        fi
    fi
    bootstrap_step_bash "${1:-}" "${current}"
}

# bootstrap_step_core_utils
#
# Step 3: offers to install the missing core utilities.
function bootstrap_step_core_utils() {
    logc "\n{{BOLD}}3. Core utilities{{RESET}}"

    local -a missing=()
    local line
    while IFS= read -r line; do
        [ -n "${line}" ] && missing+=("$(core_util_label "${line}")")
    done <<< "$(missing_core_utils)"

    if [ "${#missing[@]}" -eq 0 ]; then
        logc "- all core utilities are already installed"
        return 0
    fi

    logc "- not yet installed:"
    _bootstrap_list "${missing[@]}"
    if confirm "Install them?"; then
        install_core_utils
    fi
}

# bootstrap_step_rust
#
# Step 4: offers to install Rust and cargo-binstall.
function bootstrap_step_rust() {
    logc "\n{{BOLD}}4. Rust{{RESET}}"

    if has_command "cargo" && has_command "cargo-binstall"; then
        logc "- {{BOLD}}Rust{{RESET}} and {{BOLD}}cargo-binstall{{RESET}} are already installed"
        retry_core_utils_with_cargo
        return 0
    fi

    local question="Install Rust (rustup) and cargo-binstall?"
    if has_command "cargo"; then
        logc "- {{BOLD}}Rust{{RESET}} is installed but {{BOLD}}cargo-binstall{{RESET}} is not"
        question="Install cargo-binstall?"
    fi

    confirm "${question}" || return 0

    if ! has_command "cargo"; then
        if install_rust_toolchain; then
            BOOTSTRAP_INSTALLED+=("Rust")
        else
            BOOTSTRAP_FAILED+=("Rust")
            return 1
        fi
    fi

    if install_cargo_binstall; then
        BOOTSTRAP_INSTALLED+=("cargo-binstall")
    else
        BOOTSTRAP_FAILED+=("cargo-binstall")
    fi

    retry_core_utils_with_cargo
}

# bootstrap_step_ai_agents
#
# Step 5: offers to install the missing AI agent CLIs. Skipped when
# `curl` is not installed.
function bootstrap_step_ai_agents() {
    logc "\n{{BOLD}}5. AI agents{{RESET}}"

    if ! has_command "curl"; then
        logc "- {{DIM}}skipped: the agent installers need {{BOLD}}curl{{RESET}}{{DIM}}, which is not installed{{RESET}}"
        return 0
    fi

    local -a missing=()
    local line
    while IFS= read -r line; do
        [ -n "${line}" ] && missing+=("$(ai_agent_label "${line}") {{DIM}}(${line}){{RESET}}")
    done <<< "$(missing_ai_agents)"

    if [ "${#missing[@]}" -eq 0 ]; then
        logc "- all AI agent CLIs are already installed"
        return 0
    fi

    logc "- not yet installed:"
    _bootstrap_list "${missing[@]}"
    if confirm "Install the AI agent CLIs?"; then
        install_ai_agents
    fi
}

# adaptive_bootstrap_run [running_bash_version]
#
# Runs the interactive first-run setup for Starship, the login shell, core
# utilities, Rust and AI agents. Returns non-zero when a requested step fails.
function adaptive_bootstrap_run() {
    local where
    where="$(os)"
    if is_windows; then
        where="windows"
    elif is_linux; then
        where="${where} → $(distro)"
    fi

    logc ""
    logc "{{BOLD}}Host setup{{RESET}} for {{BOLD}}{{BLUE}}$(uname -n 2> /dev/null || hostname){{RESET}} {{DIM}}(${where}; package manager: $(host_pkg_manager || echo none)){{RESET}}"

    _bootstrap_refresh_path

    bootstrap_step_starship
    bootstrap_step_shell "${1-${BASH_VERSION}}"
    bootstrap_step_core_utils
    bootstrap_step_rust
    bootstrap_step_ai_agents

    if [ "${#BOOTSTRAP_INSTALLED[@]}" -gt 0 ] || [ "${#BOOTSTRAP_FAILED[@]}" -gt 0 ] || [ "${#BOOTSTRAP_TODO[@]}" -gt 0 ]; then
        logc ""
    fi
    if [ "${#BOOTSTRAP_INSTALLED[@]}" -gt 0 ]; then
        logc "{{GREEN}}Installed:{{RESET}} $(_bootstrap_join "${BOOTSTRAP_INSTALLED[@]}")"
    fi
    if [ "${#BOOTSTRAP_FAILED[@]}" -gt 0 ]; then
        logc "{{RED}}Failed:{{RESET}} $(_bootstrap_join "${BOOTSTRAP_FAILED[@]}")"
    fi
    if [ "${#BOOTSTRAP_TODO[@]}" -gt 0 ]; then
        logc "{{YELLOW}}To do:{{RESET}} $(_bootstrap_join "${BOOTSTRAP_TODO[@]}")"
    fi
    [ "${#BOOTSTRAP_FAILED[@]}" -eq 0 ]
}

# CLI invocation handler - allows running script directly with a function name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd="${1:-}"
    shift 2> /dev/null || true

    if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
        script_name="$(basename "${BASH_SOURCE[0]}")"
        echo "Usage: $script_name <function> [args...]"
        echo ""
        echo "Available functions:"
        declare -F | awk '{print $3}' | grep -v '^_' | sort | sed 's/^/  /'
        exit 0
    fi

    if declare -f "$cmd" > /dev/null 2>&1; then
        "$cmd" "$@"
    else
        echo "Error: Unknown function '$cmd'" >&2
        echo "Run '$(basename "${BASH_SOURCE[0]}") --help' for available functions" >&2
        exit 1
    fi
fi
