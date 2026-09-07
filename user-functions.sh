#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL}" ] || [[ "${ADAPTIVE_SHELL}" == "" ]]; then
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

# use "dust" over base "du" if available
function du() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/detection.sh"

    if has_command "dust"; then
        dust -X ".git" -X "node_modules" "$@"
        logc ""
        logc "{{DIM}}- excluded {{BLUE}}.git{{RESET}}{{DIM}} and {{BLUE}}node_modules{{RESET}}{{DIM}} directory from results{{RESET}}"
        logc "{{DIM}}- use {{GREEN}}{{BOLD}}dust{{RESET}}{{DIM}} to not exclude{{RESET}}"
    else
        if [ -z "$*" ]; then
            $(which du) "."
        else
            $(which du) "$*"
        fi
    fi
    remove_colors
}

# h <filter>
#
# history convenience utility
function h() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/detection.sh"

    local -r filter_by="${1:-}"
    local numeric_re='^[0-9]+$'

    if [[ ${filter_by} =~ ${numeric_re} ]]; then
        logc "{{BOLD}}History{{RESET}} ({{ITALIC}}last ${filter_by}{{RESET}}):\n"
        if is_zsh; then
            builtin fc -l -- "-${filter_by}"
        elif is_bash; then
            builtin history "${filter_by}"
        else
            history "${filter_by}"
        fi
    elif [[ -z ${filter_by} ]]; then
        logc "{{BOLD}}History{{RESET}} ({{ITALIC}}all{{RESET}}):\n"
        if is_zsh; then
            builtin fc -l 1
        elif is_bash; then
            builtin history
        else
            history
        fi
    else
        logc "{{BOLD}}History{{RESET}} ({{ITALIC}}filtered by '${filter_by}'{{RESET}}):\n"
        local -a history_cmd
        if is_zsh; then
            history_cmd=(builtin fc -l 1)
        elif is_bash; then
            history_cmd=(builtin history)
        else
            history_cmd=(history)
        fi
        if has_command "rg"; then
            "${history_cmd[@]}" | rg -- "${filter_by}"
        else
            "${history_cmd[@]}" | command grep -- "${filter_by}"
        fi
    fi

}

# f [options] <expression> [directory]
#
# Interactively search the contents of files -- not their names -- starting at
# <directory> (or the CWD when omitted) and recursing into subdirectories.
# Matches are piped to fzf for fuzzy narrowing, previewed with the matching line
# highlighted, and the selection is opened in ${EDITOR} at that line.
#
# The expression is treated as a regular expression unless -F is passed.
#
#   -F, --fixed         treat <expression> as a literal string
#   -i, --ignore-case   case-insensitive match
#   -a, --all           also search hidden and ignored files (excluding .git/)
#   -h, --help          show usage
#
# Degrades where tools are missing: grep replaces ripgrep, a plain listing
# replaces fzf, and cat replaces bat.
function f() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/detection.sh"

    local fixed=0
    local ignore_case=0
    local search_all=0
    local expression=""
    local search_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -F | --fixed)
            fixed=1
            shift
            ;;
        -i | --ignore-case)
            ignore_case=1
            shift
            ;;
        -a | --all)
            search_all=1
            shift
            ;;
        -h | --help)
            logc "Syntax: {{BOLD}}f{{RESET}} {{DIM}}[options]{{RESET}} {{ITALIC}}<expression>{{RESET}} {{DIM}}[directory]{{RESET}}\n"
            logc "Searches file {{BOLD}}contents{{RESET}} recursively, then opens the match in {{BLUE}}\${EDITOR}{{RESET}}.\n"
            logc "  {{GREEN}}-F, --fixed{{RESET}}        treat the expression as a literal string"
            logc "  {{GREEN}}-i, --ignore-case{{RESET}}  case-insensitive match"
            logc "  {{GREEN}}-a, --all{{RESET}}          include hidden and ignored files"
            logc "  {{GREEN}}-h, --help{{RESET}}         show this help"
            remove_colors
            return 0
            ;;
        --)
            shift
            if [[ -z "${expression}" ]] && [[ $# -gt 0 ]]; then
                expression="$1"
                shift
            fi
            if [[ $# -gt 0 ]]; then search_dir="$1"; fi
            break
            ;;
        -*)
            logc "{{RED}}search:{{RESET}} unknown option '$1'"
            remove_colors
            return 2
            ;;
        *)
            if [[ -z "${expression}" ]]; then expression="$1"; else search_dir="$1"; fi
            shift
            ;;
        esac
    done

    if [[ -z "${expression}" ]]; then
        logc "Syntax: {{BOLD}}search{{RESET}} {{DIM}}[options]{{RESET}} {{ITALIC}}<expression>{{RESET}} {{DIM}}[directory]{{RESET}}"
        logc "{{DIM}}See {{RESET}}{{ITALIC}}search --help{{RESET}}{{DIM}} for options.{{RESET}}"
        remove_colors
        return 1
    fi

    if [[ -z "${search_dir}" ]]; then search_dir="."; fi

    if [[ ! -d "${search_dir}" ]]; then
        logc "{{RED}}search:{{RESET}} '${search_dir}' is not a directory"
        remove_colors
        return 1
    fi

    # ripgrep when available, otherwise a portable grep with comparable defaults
    local -a finder
    if has_command "rg"; then
        finder=(rg --line-number --no-heading --color=always)
        [[ ${fixed} -eq 1 ]] && finder+=(--fixed-strings)
        [[ ${ignore_case} -eq 1 ]] && finder+=(--ignore-case)
        [[ ${search_all} -eq 1 ]] && finder+=(--hidden --no-ignore --glob '!.git/')
    else
        finder=(command grep -rnI --color=always)
        [[ ${fixed} -eq 1 ]] && finder+=(-F)
        [[ ${ignore_case} -eq 1 ]] && finder+=(-i)
        [[ ${search_all} -eq 0 ]] && finder+=(--exclude-dir=.git --exclude-dir=node_modules)
    fi
    finder+=(-e "${expression}" -- "${search_dir}")

    # without fzf there is nothing to narrow with, so just show the matches
    if ! has_command "fzf"; then
        logc "{{DIM}}fzf is not installed; listing matches instead.{{RESET}}"
        remove_colors
        "${finder[@]}"
        return $?
    fi

    # field 1 is the path, field 2 the line number; --ansi makes fzf strip the
    # colour codes before those placeholders are expanded
    local preview_cmd
    if has_command "bat"; then
        preview_cmd="bat --color=always --style=numbers --highlight-line {2} -- {1}"
    else
        preview_cmd="cat -- {1}"
    fi

    remove_colors
    "${finder[@]}" | fzf \
        --ansi \
        --delimiter : \
        --prompt "${expression} > " \
        --preview "${preview_cmd}" \
        --preview-window "right,60%,+{2}/2" \
        --bind "enter:become(${EDITOR:-vim} {1} +{2})"
}

function init() {
    bash "${ROOT}/programs/initialize.sh"
}

function installed() {
    # shellcheck source="./utils/install.sh"
    source "${UTILS}/install.sh"

    show_installed "$@"
}

function vitesse() {
    if [ -z "$1" ]; then
        logc "Syntax: ${BOLD}vitesse${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to install to  ${NO_DIM}\n"
        return
    fi

    if ! has_command "node"; then
        if confirm "The host system does not have NodeJS installed; install now?"; then
            install_node
        else
            logc "We need node -- ((ITALIC}}and {{BOLD}}npx{{RESET}} -- to pull down the vitesse starter template. Exiting."
            return 1
        fi
    fi

    if ! has_command "pnpm"; then
        if confirm "The Vitesse starter template expect {{BOLD}}{{BLUE}}pnpm{{RESET}} to be used as the package manager but this isn't install on this host doesn't have it installed. Install now?"; then
            install_pnpm
        fi
    fi

    npx degit antfu/vitesse "$1" --force
}

function vitesse_ext() {
    if [ -z "$1" ]; then
        logc "Syntax: ${BOLD}vitesse-ext${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to install to  ${NO_DIM}\n"
        return
    fi

    npx degit antfu/vitesse-webext "$1" --force
}

# markdownlint()
#
# adds a `.markdownlint.jsonc` file to the current working directory (or $1 if set)
# if no configuration file was already there.
function markdownlint() {
    local -r dir="${1:-${PWD}}"
    source "${UTILS}/logging.sh"
    source "${UTILS}/color.sh"
    source "${UTILS}/detection.sh"

    if [ ! -f "./.markdownlint.jsonc" ] && [ ! -f "./.markdownlint.json" ]; then
        logc "- creating {{BLUE}}.markdownlint.jsonc{{RESET}} file"
        logc ""
        if is_windows; then
            logc "- not implemented for Windows yet! Consider running in WSL.\n"
            return 1
        else
            cp "${ROOT}/resources/.markdownlint.jsonc" "${dir}" >/dev/null 2>/dev/null || error "problems copying the file!"
        fi
    else
        if [ ! -f "./.markdownlint.jsonc" ]; then
            logc "- lint file {{BLUE}}./markdownlint.json{{RESET}} already exists; skipping ..."
        else
            logc "- lint file {{BLUE}}./markdownlint.jsonc{{RESET}} already exists; skipping ..."
        fi
    fi

}

function gitignore() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/color.sh"

    if [ ! -f "./.gitignore" ]; then
        logc "- creating {{BLUE}}.gitignore{{RESET}} file"
        logc ""
        cat <<'EOF' >"./.gitignore"
# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
**/trace/*.json
# Runtime data
*.pid
*.seed
*.pid.lock
# Directory for instrumented libs generated by jscoverage/JSCover
lib-cov
# Coverage directory used by tools like istanbul
coverage
# nyc test coverage
.nyc_output
# Grunt intermediate storage (http://gruntjs.com/creating-plugins#storing-task-files)
.grunt
# Bower dependency directory (https://bower.io/)
bower_components
# node-waf configuration
.lock-wscript
# Compiled binary addons (https://nodejs.org/api/addons.html)
build/Release
# Dependency directories
node_modules/
jspm_packages/
# Optional npm cache directory
.npm
# Optional eslint cache
.eslintcache
# Optional REPL history
.node_repl_history
# Output of 'npm pack'
*.tgz
# Yarn Integrity file
.yarn-integrity
# dotenv environment variables file
.env
# next.js build output
.next
# OS X temporary files
.DS_Store
# Transpiled Destinations
**/dist/
**/.presite
frontend/.vite-ssg-dist/**
/functions
# for simple TODOs
/todo.md

# Local Netlify folder
.netlify

.tsbuildinfo
trace/*
.trace/*
.ai/logs
.ai/plans/archived
.ai/code-reviews/archived

EOF
    else
        logc "- the {{BLUE}}.gitignore{{RESET}} file already exists, {{ITALIC}}skipping{{RESET}}"
    fi
}

# unset login_message

# net()
#
# Proxies the `network_interfaces()` function through as a
# command for the interactive console.
function net() {
    local -ra params=("$@")
    source "${UTILS}/detection.sh"
    source "${UTILS}/cli.sh"
    source "${UTILS}/network.sh"
    local -r file="${UTILS}/network.sh"

    logc "{{BOLD}}{{YELLOW}}Network Interfaces"
    list_network_interfaces

    logc "\n{{BOLD}}{{YELLOW}}TCP/IP Addresses"
    bash "${file}" "network_interfaces" "${params[@]}"
    logc "\n{{BOLD}}{{YELLOW}}Network Default Routes"
    bash "${file}" "get_routes" "${params[@]}"
    if ! has_cli_switch params "-6"; then
        logc "\n{{DIM}}{{ITALIC}}- use {{BOLD}}{{GREEN}}-6{{RESET}}{{DIM}}{{ITALIC}} to get IPv6 information too"
    fi
}

function track() {
    local -r file="${ROOT}/track.sh"
    local -ra params=("$@")

    bash "${file}" "${params[@]}"
}

if has_command "ffmpeg"; then

    # Convert one-or-more files (or globs) to ProRes 422 .mov for Final Cut Pro.
    # Usage:
    #   to_prores input.mp4
    #   to_prores *.mp4
    #   to_prores "/path/with spaces/*.mp4"
    #   to_prores --hq *.mp4
    #   to_prores --lt *.mp4
    #   to_prores --dry-run *.mp4
    to_prores() {
        local profile=3 # 1=LT, 3=422, 4=422HQ
        local suffix="_prores422"
        local timescale=30000 # 0 disables
        local overwrite=0
        local dry_run=0
        local input_dir=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
            --lt)
                profile=1
                suffix="_proresLT"
                shift
                ;;
            --422)
                profile=3
                suffix="_prores422"
                shift
                ;;
            --hq)
                profile=4
                suffix="_prores422HQ"
                shift
                ;;
            --timescale=*)
                timescale="${1#*=}"
                shift
                ;;
            --no-timescale)
                timescale=0
                shift
                ;;
            --in)
                input_dir="$2"
                shift 2
                ;;
            -y | --overwrite)
                overwrite=1
                shift
                ;;
            -n | --dry-run)
                dry_run=1
                shift
                ;;
            -h | --help)
                cat <<'EOF'
to_prores [options] <file-or-glob>...

Works in both bash and zsh.

Important:
- To use shell globs, do NOT quote them:
    to_prores *.mp4
- If you need quoting, use --in DIR to discover files:
    to_prores --in .   (converts *.mp4 in current dir)

Options:
--lt            ProRes LT
--422           ProRes 422 (default)
--hq            ProRes 422 HQ
--timescale=N   Set video track timescale (default 30000)
--no-timescale  Disable timescale adjustment
--in DIR        Convert all *.mp4 in DIR (portable alternative to quoted globs)
-y, --overwrite Overwrite existing outputs
-n, --dry-run   Print ffmpeg commands without running
-h, --help      Show this help
EOF
                return 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "to_prores: unknown option: $1" >&2
                return 2
                ;;
            *) break ;;
            esac
        done

        command -v ffmpeg >/dev/null 2>&1 || {
            echo "to_prores: ffmpeg not found in PATH" >&2
            return 127
        }

        local -a files=()

        if [[ -n "$input_dir" ]]; then
            [[ -d "$input_dir" ]] || {
                echo "to_prores: --in expects a directory: $input_dir" >&2
                return 2
            }
            # Portable file discovery (no eval; works in bash+zsh)
            while IFS= read -r -d '' f; do
                files+=("$f")
            done < <(find "$input_dir" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' \) -print0)
        else
            [[ $# -ge 1 ]] || {
                echo "to_prores: provide at least one file (or use --in DIR)" >&2
                return 2
            }
            # In both bash and zsh, unquoted globs will already be expanded by the shell.
            # Quoted patterns will arrive literally and (correctly) be treated as literal filenames.
            files=("$@")
        fi

        local f base out ret=0 count=0
        local -a cmd

        for f in "${files[@]}"; do
            [[ -e "$f" ]] || {
                echo "to_prores: skipping (not found): $f" >&2
                ret=1
                continue
            }
            [[ -d "$f" ]] && {
                echo "to_prores: skipping (directory): $f" >&2
                ret=1
                continue
            }

            base="${f%.*}"
            out="${base}${suffix}.mov"

            if [[ -e "$out" && $overwrite -ne 1 ]]; then
                echo "to_prores: output exists (use -y to overwrite): $out" >&2
                ret=1
                continue
            fi

            cmd=(ffmpeg)
            ((overwrite)) && cmd+=(-y)
            cmd+=(
                -err_detect ignore_err
                -fflags +genpts
                -i "$f"
                -map 0:v:0
                -map '0:a?' # quoted => safe in zsh AND bash
                -c:v prores_ks
                -profile:v "$profile"
                -pix_fmt yuv422p10le
                -vendor apl0
                -movflags +faststart
            )
            [[ "$timescale" != "0" ]] && cmd+=(-video_track_timescale "$timescale")
            cmd+=("$out")

            ((count++))
            if ((dry_run)); then
                printf 'DRY RUN [%d]: ' "$count"
                printf '%q ' "${cmd[@]}"
                printf '\n'
            else
                echo "[$count] $f -> $out"
                # Extra safety in zsh: prevent any further glob expansion
                noglob "${cmd[@]}" 2>/dev/null || "${cmd[@]}" || ret=$?
            fi
        done

        return "$ret"
    }

fi

# about()
#
# information about aliases, functions, binary
# paths, etc.
function about() {
    local -r file="${REPORTS}/about.sh"

    bash "${file}" "report_about"
}

function sys() {
    local -r file="${REPORTS}/sys.sh"

    bash "${file}" "report_sys"
}

if has_command "yazi"; then
    function y() {
        export EDITOR="nvim"
        local -r tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd" || exit 1
        fi
        rm -f -- "$tmp"
    }
else
    function y() {
        logc ""
        logc "the ${BOLD}${BLUE}Yazi${RESET} CLI file explorer is not installed"
        logc "> https://yazi-rs.github.io/docs/installation"
        logc ""
    }
fi

function upgrade() {
    # shellcheck source="./utils/interactive.sh"
    source "${UTILS}/interactive.sh"
    # shellcheck source="./utils/install.sh"
    source "${UTILS}/install.sh"

    logc "\n{{BOLD}}{{GREEN}}upgrade{{RESET}} will update all package managers installed on the system. This would include the OS's primary package manager as well package managers like gem,npm, pip, and uv."
    if confirm "Continue?"; then
        update_packages
        upgrade_packages
    else
        logc "\nOk.\n"
    fi
}

if has_function is_pve_host && { is_pve_host || is_pve_container || is_pve_aware; }; then
    function nodes() {
        source "${UTILS}/proxmox-utils.sh"
        source "${UTILS}/proxmox-api.sh"
        logc "$(get_pve_nodes)"
    }
fi

if has_command "uv"; then
    unset -f uv 2>/dev/null || true
else
    function uv() {
        logc "{{BOLD}}{{BLUE}}uv{{RESET}} [{{DIM}}https://docs.astral.sh/uv{{RESET}}] is not currently installed on this system."
        # shellcheck source="./utils/interactive.sh"
        source "${UTILS}/interactive.sh"
        if confirm "Install now?"; then
            # shellcheck source="./utils/install.sh"
            source "${UTILS}/install.sh"
            install_uv && unset -f uv
        fi
    }
fi

if has_command "cargo"; then
    unset -f cargo 2>/dev/null || true
else
    function cargo() {
        logc "{{BOLD}}{{BLUE}}Rust{{RESET}} -- {{ITALIC}}and therefore {{BOLD}}cargo{{RESET}} -- are not installed on this system."
        # shellcheck source="./utils/interactive.sh"
        source "${UTILS}/interactive.sh"
        if confirm "Install now?"; then
            # shellcheck source="./utils/install.sh"
            source "${UTILS}/install.sh"
            install_rust && unset -f cargo
        fi
    }
fi

if has_command "starship"; then
    # A wrapper may still be defined from an earlier source of this file,
    # back when starship was missing. Shell functions shadow executables,
    # so a stale wrapper hides the real binary and lies about it being
    # uninstalled. Clear it.
    unset -f starship 2>/dev/null || true
else

    function starship() {
        source "${UTILS}/logging.sh"
        source "${UTILS}/interactive.sh"
        source "${UTILS}/install.sh"

        logc "The {{BOLD}}{{GREEN}}starship{{RESET}} program for managing your prompt is not\ninstalled on this host.\n"
        if confirm "Install now?"; then
            install_starship && unset -f starship
        fi
    }

fi

if is_bash; then
    # upgrade_to_zsh()
    #
    # Upgrades the user's default shell from bash to zsh.
    # Installs zsh if not available, changes the default shell,
    # and ensures interactive.sh is sourced in the new .zshrc file.
    function upgrade_to_zsh() {
        source "${UTILS}/logging.sh"
        source "${UTILS}/detection.sh"
        source "${UTILS}/interactive.sh"
        source "${UTILS}/filesystem.sh"
        # shellcheck source="./utils/install.sh"
        source "${UTILS}/install.sh"

        logc "\n{{BOLD}}{{BLUE}}Shell Upgrade{{RESET}}: bash → zsh\n"

        # Check if zsh is already installed
        if has_command "zsh"; then
            logc "- {{GREEN}}zsh{{RESET}} is already installed on this system"
        else
            logc "- {{YELLOW}}zsh{{RESET}} is not installed"
            if confirm "Install zsh now?"; then
                if is_mac; then
                    install_on_macos "zsh" || {
                        logc "{{RED}}Failed to install zsh on macOS{{RESET}}"
                        return 1
                    }
                elif is_debian || is_ubuntu || is_mint; then
                    install_on_debian "zsh" || {
                        logc "{{RED}}Failed to install zsh on Debian/Ubuntu{{RESET}}"
                        return 1
                    }
                elif is_fedora; then
                    install_on_fedora "zsh" || {
                        logc "{{RED}}Failed to install zsh on Fedora{{RESET}}"
                        return 1
                    }
                elif is_arch; then
                    install_on_arch "zsh" || {
                        logc "{{RED}}Failed to install zsh on Arch{{RESET}}"
                        return 1
                    }
                elif is_alpine; then
                    install_on_alpine "zsh" || {
                        logc "{{RED}}Failed to install zsh on Alpine{{RESET}}"
                        return 1
                    }
                else
                    logc "{{RED}}Unsupported OS for automatic zsh installation{{RESET}}"
                    logc "Please install zsh manually and run this function again"
                    return 1
                fi
                logc "- {{GREEN}}zsh{{RESET}} installed successfully"
            else
                logc "- Skipping zsh installation"
                return 0
            fi
        fi

        # Verify zsh is available
        if ! has_command "zsh"; then
            logc "\n{{RED}}ERROR{{RESET}}: zsh is still not available"
            return 1
        fi

        # Get the path to zsh
        local zsh_path
        zsh_path="$(command -v zsh)"
        logc "- zsh location: {{BLUE}}${zsh_path}{{RESET}}"

        # Verify zsh is in /etc/shells
        if ! grep -q "${zsh_path}" /etc/shells 2>/dev/null; then
            logc "- {{YELLOW}}Warning{{RESET}}: ${zsh_path} is not in /etc/shells"
            if is_root_user; then
                logc "- Adding ${zsh_path} to /etc/shells"
                echo "${zsh_path}" >>/etc/shells
            else
                logc "- You may need to add ${zsh_path} to /etc/shells manually"
            fi
        fi

        # Change the default shell
        logc "\n- Changing default shell to {{GREEN}}zsh{{RESET}}"
        if is_root_user; then
            chsh -s "${zsh_path}" || {
                logc "{{RED}}Failed to change default shell{{RESET}}"
                return 1
            }
        else
            # Need to prompt for password when not root
            logc "- You may be prompted for your password"
            chsh -s "${zsh_path}" || {
                logc "{{RED}}Failed to change default shell{{RESET}}"
                return 1
            }
        fi
        logc "- Default shell changed to {{GREEN}}zsh{{RESET}}"

        # Set up .zshrc file
        local zshrc="${HOME}/.zshrc"
        local interactive_sh="${UTILS}/interactive.sh"

        if ! file_exists "${interactive_sh}"; then
            logc "\n{{RED}}ERROR{{RESET}}: interactive.sh not found at ${interactive_sh}"
            return 1
        fi

        # Create .zshrc if it doesn't exist
        if ! file_exists "${zshrc}"; then
            logc "- Creating new {{BLUE}}.zshrc{{RESET}} file"
            touch "${zshrc}"
        else
            logc "- {{BLUE}}.zshrc{{RESET}} already exists"
        fi

        # Check if interactive.sh is already sourced in .zshrc
        if grep -q "interactive.sh" "${zshrc}" 2>/dev/null; then
            logc "- {{GREEN}}interactive.sh{{RESET}} is already sourced in {{BLUE}}.zshrc{{RESET}}"
        else
            logc "- Adding {{GREEN}}interactive.sh{{RESET}} to {{BLUE}}.zshrc{{RESET}}"
            echo "" >>"${zshrc}"
            echo "# Source interactive utilities" >>"${zshrc}"
            echo "source \"${interactive_sh}\"" >>"${zshrc}"
        fi

        logc "\n{{BOLD}}{{GREEN}}Upgrade complete!{{RESET}}"
        logc ""
        logc "{{ITALIC}}Next steps:{{RESET}}"
        logc "  1. Log out and log back in for the shell change to take effect"
        logc "  2. Or run: {{BOLD}}zsh{{RESET}} to try it immediately"
        logc ""
    }
    :
fi

if has_command "just"; then

    alias j="just"

fi

if has_command "claudine"; then
    alias c="claudine"
fi

if ! has_command "claude"; then
    function claude() {
        logc "{{BOLD}}{{BLUE}}Claude Code{{RESET}} is not installed on this machine."
        if confirm "Install now?"; then
            if install_claude_code; then
                unset -f claude
                claude
            else
                logc "Ok.\n"
                return 0
            fi
        else
            logc "Ok.\n"
            return 1
        fi
    }

    if ! has_command "cc"; then
        function ccc() {
            logc "⚠️ the {{BOLD}}{{RED}}cc{{RESET}} alias was used but Claude Code is not installed\n"
            claude
        }
    fi

else
    source "${UTILS}/detection.sh" || error "discovery utilities not found!"
    if is_zsh; then
        CLAUDE_CLI="$(whence -p claude)"
    else
        CLAUDE_CLI="$(which claude)"
    fi
    export CLAUDE_CLI

    # Claude is installed so wrap executable with
    # function which clears the screen before entering
    # shellcheck disable=SC2155
    function ccc() {
        source "${UTILS}/logging.sh" || error "logging utilities not found!"
        source "${UTILS}/filesystem.sh" || error "discovery utilities not found!"
        local -r prompt_filepath_md="${PWD}/docs/system-prompt.md"
        local -r prompt_filepath_xml="${PWD}/docs/system-prompt.xml"

        if file_exists "${prompt_filepath_md}"; then
            local prompt="$(get_file "${prompt_filepath_md}")"

            if [[ "$1" == "--version" ]]; then
                "${CLAUDE_CLI}" --version
                return
            fi

            if [[ "$1" == "--help" ]]; then
                "${CLAUDE_CLI}" --help
                return
            fi

            if has_cli_switch "--dangerously-skip-permissions"; then
                (
                    clear && "${CLAUDE_CLI}" "${@}" && clear && logc "\n- {{BLUE}}{{BOLD}}Claude{{RESET}} session -- {{ITALIC}}with system prompt{{RESET}}-- exited."
                ) || error "Problem starting Claude Code (with system prompt)."
            else
                (
                    clear && "${CLAUDE_CLI}" --dangerously-skip-permissions "${@}" && clear && logc "\n- {{BLUE}}{{BOLD}}Claude{{RESET}} session -- {{ITALIC}}with system prompt{{RESET}}-- exited."
                ) || error "Problem starting Claude Code (with system prompt)."
            fi
            logc ""
            logc "{{BOLD}}System Prompt:{{RESET}}"
            if has_command "bat"; then
                bat "${prompt_filepath_md}" --no-pager
            else
                logc "${prompt}"
            fi
            logc ""
        elif file_exists "${prompt_filepath_xml}"; then
            local prompt="$(get_file "${prompt_filepath_xml}")"

            if [[ "$1" == "--version" ]]; then
                "${CLAUDE_CLI}" --version
                return
            fi

            if [[ "$1" == "--help" ]]; then
                "${CLAUDE_CLI}" --help
                return
            fi

            if has_cli_switch "--dangerously-skip-permissions"; then
                (
                    clear && "${CLAUDE_CLI}" "${@}" && clear && logc "\n- {{BLUE}}{{BOLD}}Claude{{RESET}} session -- {{ITALIC}}with XML system prompt{{RESET}}-- exited."
                ) || error "Problem starting Claude Code (with system prompt)."
            else
                (
                    clear && "${CLAUDE_CLI}" --dangerously-skip-permissions "${@}" && clear && logc "\n- {{BLUE}}{{BOLD}}Claude{{RESET}} session -- {{ITALIC}}with XML system prompt{{RESET}}-- exited."
                ) || error "Problem starting Claude Code (with system prompt)."
            fi
            logc ""
            logc "{{BOLD}}System Prompt [{{DIM}}xml{{RESET}}{{BOLD}}]:{{RESET}}"
            if has_command "bat"; then
                bat "${prompt_filepath_xml}" --no-pager
                logc ""
                "${CLAUDE_CLI}" --version
            else
                logc "${prompt}"
                logc ""
                "${CLAUDE_CLI}" --version
            fi
            logc ""
        else
            clear && "${CLAUDE_CLI}" "${@}" && clear && logc "\n- {{BLUE}}{{BOLD}}Claude{{RESET}} session exited ({{ITALIC}}{{DIM}}no system prompt{{RESET}})."
        fi

    }

fi
