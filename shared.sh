#!/usr/bin/env bash

# shellcheck source="./color.sh"
source "${HOME}/.config/sh/color.sh";

export ANDROID_HOME="${HOME}/Library/Android/sdk"
export NDK_HOME="${ANDROID_HOME}/nd/$(ls -1 ${ANDROID_HOME}/ndk)"


# log
#
# Logs the parameters passed to STDERR
function log() {
    printf "%b\\n" "${*}" >&2
}

# debug <fn> <msg> <...>
# 
# Logs to STDERR when the DEBUG env variable is set
# and not equal to "false".
function debug() {
    local -r DEBUG=$(lc "${DEBUG:-}")
    if [[ "${DEBUG}" != "false" ]]; then
        if (( $# > 1 )); then
            local fn="$1"

            shift
            local regex=""
            local lower_fn="" 
            lower_fn=$(lc "$fn")
            regex="(.*[^a-z]+|^)$lower_fn($|[^a-z]+.*)"

            if [[ "${DEBUG}" == "true" || "${DEBUG}" =~ $regex ]]; then
                log "       ${GREEN}◦${RESET} ${BOLD}${fn}()${RESET} → ${*}"
            fi
        else
            log "       ${GREEN}DEBUG: ${RESET} → ${*}"
        fi
    fi
}

# error <msg>
#
# sends a formatted error message to STDERR
function error() {
    local -r msg="${1:?no message passed to error()!}"
    local -ri code=$(( "${2:-1}" ))
    local -r fn="${3:-${FUNCNAME[1]}}"

    log "\n  [${RED}x${RESET}] ${BOLD}ERROR ${DIM}${RED}$code${RESET}${BOLD} →${RESET} ${msg}" && return $code
}

# lc() <str>
#
# converts the passed in <str> to lowercase
function lc() {
    local -r str="${1-}"
    echo "${str}" | tr '[:upper:]' '[:lower:]'
}

# is_numeric() <candidate>
#
# returns 0/1 based on whether <candidate> is numeric
function is_numeric() {
    local -r val="$1"
        if ! [[ "$val" =~ ^[0-9]+$ ]]; then
            return 1
        else
            return 0
        fi
}

function is_string() {
  local -r val="$1"
  if [[ -z "$val" ]]; then
    return 1
  else
    if [[ "$val" =~ ^[a-zA-Z]{1}.*$ ]]; then
      return 0
    else
      return 1
    fi
  fi
}

function has_characters() {
    local -r char_str="${1:?has_characters() did not recieve a CHARS string!}"
    local -r content="${2:?content expression not passed to has_characters()}"
    # shellcheck disable=SC2207
    local -ra chars=( $(echo "${char_str}" | grep -o .) )
    local found="false"

    if [[ "$content" == *["$char_str"]* ]]; then
        debug "has_characters" "does have some of these characters: '${char_str}'"
        return 0
    else
        debug "has_characters" "does NOT have any of these characters: '${char_str}'"
        return 1
    fi
}

function is_bound() {
    local -n __test_by_ref=$1 2>/dev/null || { debug "is_bound" "unbounded ref";  return 1; }
    local -r by_val="${1}:-"
    local name="${!__test_by_ref}" 2
    local -r arithmetic='→+-=><%'
    if has_characters "${arithmetic}" "$1"; then
        debug "is_bound" "${name} is NOT bound"
        return 1
    else
        local idx=${!1} 2>/dev/null 
        local a="${__test_by_ref@a}" 

        if [[ -z "${idx}${a}" ]]; then
            debug "is_bound" "${name} is NOT bound: ${idx}, ${a}"
            return 1
        else 
            debug "is_bound" "${name} IS bound: ${idx}, ${a}"
            return 0
        fi
    fi
}


# starts_with <look-for> <content>
function starts_with() {
    local -r look_for="${1:?No look-for string provided to starts_with}"
    local -r content="${2:-}"

    if is_empty "${content}"; then
        debug "starts_with" "starts_with(${look_for}, "") was passed empty content so will always return false"
        return 1;
    fi

    if [[ "${content}" == "${content#"$look_for"}" ]]; then
        debug "starts_with" "false (\"${DIM}${look_for}${RESET}\")"
        return 1; # was not present
    else
        debug "starts_with" "true (\"${DIM}${look_for}${RESET}\")"
        return 0; #: found "look_for"
    fi
}

# os
# 
# Will try to detect the operating system of the host computer
# where options are: darwin, linux, windowsnt, 
function os() {
    local -r os_type=$(lc "${OSTYPE}") || "$(lc "$(uname)")" || "unknown"
    case "$os_type" in
        'linux'*)
           echo "linux"
          ;;
        'freebsd'*)
          echo "freebsd"
          ;;
        'windowsnt'*)
          echo "windows"
          ;;
        'darwin'*) 
          echo "macos"
          ;;
        'sunos'*)
          echo "solaris"
          ;;
        'aix'*) 
          echo "aix"
          ;;
        *) echo "unknown/${os_type}"
    esac
}

function is_os() {
  local -r test="${1:?test value for is_os is missing}"

  if [[ "$(os)" == "${test}" ]]; then 
    return 0;
  else 
    return 1;
  fi
}

# has_command <cmd>
#
# checks whether a particular program passed in via $1 is installed 
# on the OS or not (at least within the $PATH)
function has_command() {
    local -r cmd="${1:?cmd is missing}"

    if command -v "${cmd}" &> /dev/null; then
        return 0
    else 
        return 1
    fi
}

# file_exists <filepath>
#
# tests whether a given filepath exists in the filesystem
function file_exists() {
    local filepath="${1:?filepath is missing}"

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

function has_file() {
    local -r filepath="${1:?no filepath passsed to filepath()!}"

    if [ -f "${filepath}" ]; then
        return 0;
    else
        return 1;
    fi
}


# validates that the current directory has a package.json file
function has_package_json() {
    local -r filepath="./package.json"

    if [ -f "${filepath}" ]; then
        return 0;
    else
        return 1;
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

# contains <find> <content>
# 
# given the "content" string, all other parameters passed in
# will be looked for in this content.
function contains() {
    local -r find="${1}"
    local -r content="${2}"

    if is_empty "$find"; then
        error "contains("", ${content}) function did not recieve a FIND string! This is an invalid call!" 1
    fi

    if is_empty "$content"; then
        debug "contains" "contains(${find},"") received empty content so always returns false"
        return 1;
    fi

    if [[ "${content}" =~ ${find} ]]; then
        debug "contains" "found: ${find}"
        return 0 # successful match
    fi

    debug "contains" "not found: ${find}"
    return 1
}


# is_empty() <test | ref:test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is empty and 1 when it is NOT.
function is_empty() {
    local -n __ref__=$1 2>/dev/null

    if is_bound __ref__; then
        if is_array __ref__; then
            if [[ ${#__ref__[@]} -eq 0 ]]; then
                debug "is_empty" "found an array with no elements so returning true"
                return 0
            else
                debug "is_empty" "found an array with some elements so returning false"
                return 1
            fi
        elif is_assoc_array __ref__; then
            if [[ ${#!__ref__[@]} -eq 0 ]]; then
                debug "is_empty" "found an associative array with no keys so returning true"
                return 0
            else
                debug "is_empty" "found an associative array with some key/values so returning false"
                return 1
            fi
        else
            local -r try_pass_by_val="$__ref__" 2>/dev/null
            if [ -z "$try_pass_by_val" ] || [[ "$try_pass_by_val" == "" ]]; then
                debug "is_empty" "was empty, returning 0/true"
                return 0
            else
                debug "is_empty" "was NOT empty, returning 1/false"
                return 1
            fi
        fi

    else 
        if [ -z "$1" ] || [[ "$1" == "" ]]; then
            debug "is_empty(${1})" "was empty, returning 0/true"
            return 0
        else
            debug "is_empty(${1}))" "was NOT empty, returning 1/false"
            return 1
        fi
    fi
    
}


# not_empty() <test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is NOT empty and 1 when it is.
function not_empty() {
    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "not_empty" "WAS empty, returning 1/false"
        return 1
    else
        debug "not_empty" "was not empty [${#1} chars], returning 0/true"
        return 0
    fi
}

# get_file() <filepath>
#
# Gets the content from a file at the given <filepath>
function get_file() {
    local -r filepath="${1:?get_file() called but no filepath passed in!}"
    
    if file_exists "${filepath}"; then
        debug "get_file(${filepath})" "getting data"
        local content
        { IFS= read -rd '' content <"${filepath}";}  2>/dev/null
        printf '%s' "${content}"
    else
        debug "get_file(${filepath})" "call to get_file(${filepath}) had invalid filepath"
        return 1
    fi
}


# tests whether a given string exists in the package.json file
# located in the current directory.
function in_package_json() {
    local find="${1:?find string missing in call to in_package_json}"
    local -r pkg="$(get_file "./package.json")"

    if contains "${find}" "${pkg}"; then
        return 0;
    else
        return 1;
    fi
}

function not_in_package_json() {
    local find="${1:?find string missing in call to not_in_package_json}"
    local -r pkg="$(get_file "./package.json")"

    if contains "${find}" "${pkg}"; then
        return 1;
    else
        return 0;
    fi
}

# determine which "npm based" package manager to use
function choose_pkg_manager() {
    if file_exists "./pnpm-lock.yaml"; then
        echo "pnpm"
    elif file_exists "./package-lock.json"; then
        echo "npm"
    elif file_exists "./yarn.lock"; then
        echo "yarn"
    else
        echo "pnpm"
    fi
}

function npm_install_devdep() {
    local pkg="${1:?no package sent to npm_install_devdep}"
    local -r mgr="$(choose_pkg_manager)"

    if in_package_json "\"$pkg\":"; then
        log "- ${BOLD}${pkg}${RESET} already installed"
    else 
        log ""
        if "${mgr}" install -D "${pkg}"; then
            log ""
            log "- installed ${BOLD}${GREEN}${1}${RESET} ${ITALIC}using${RESET} ${mgr}"
        else
            log "- problems installing ${RED}${1}${RESET}"
        fi
    fi

}
