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

# shellcheck source="../utils.sh"
source "${ROOT}/utils.sh"

# Wezterm Aliases
function name() {
  local -r name="${1:-$(pwd)}"

  if [[ "${name}" == "$(pwd)" ]]; then
    if file_exists "${PWD}/.name"; then
        local -r dir_name="$(get_file "${PWD}/.name")"
        wezterm cli set-tab-title "${dir_name}"
    elif [[ "${name}" == "${HOME}" ]]; then 
        wezterm cli set-tab-title " 🛖 "
    else
        wezterm cli set-tab-title "${name}"
    fi
  else
    wezterm cli set-tab-title "${name}"
  fi
}

function left() {
    local percent="50"

    if is_numeric "$1"; then
        percent="$1"
        shift
    fi

    local -ra params=("$@")

    debug "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) pane ${WEZTERM_PANE}"
    wezterm cli split-pane --left --percent "${percent}" -- "${params[@]}"
}

function right() {
    local percent="50"

    if is_numeric "$1"; then
        percent="$1"
        shift
    fi

    local -ra params=("$@")

    debug "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) pane ${WEZTERM_PANE}"
    wezterm cli split-pane --right --percent "${percent}" -- "${params[@]}"
}

function below() {
    local percent="50"

    if is_numeric "$1"; then
        percent="$1"
        shift
    fi

    local -ra params=("$@")

    debug "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) pane ${WEZTERM_PANE}"
    wezterm cli split-pane --bottom --percent "${percent}" -- "${params[@]}"
}

function above()  {
    local percent="50"

    if is_numeric "$1"; then
        percent="$1"
        shift
    fi

    local -ra params=("$@")


    debug "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) pane ${WEZTERM_PANE}"
    wezterm cli split-pane --top --percent "${percent}" -- "${params[@]}"
}

