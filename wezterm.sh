
# Wezterm Aliases
function name() {
  local -r name="${1:-pwd}"

  if [[ "${name}" == "pwd" ]]; then
    wezterm cli set-tab-title "$(pwd)"
  else
    wezterm cli set-tab-title "${name}"
  fi
}

function left() {
  local percent="50"
  local name="undefined"

  if is_numeric "$1"; then
    percent="$1"
  fi

  if is_numeric "$2"; then
    percent="$2"
  fi

  if is_string "$1"; then
    name="$1"
  fi
  if is_string "$2"; then
    name="$2"
  fi

  if [[ "${name}" == "undefined" ]]; then 
    wezterm cli split-pane --left --percent "${percent}" 1>/dev/null 2>/dev/null
    log "open tab to ${BOLD}left${RESET} (${DIM}${percent}%${RESET})"
  else
    log "open tab to ${BOLD}left${NO_BOLD} (${percent}%) named ${name}"
    wezterm cli split-pane --left --percent "${percent}" --title "${name}"
  fi
}

function right() {
  local percent="50"
  local name="undefined"

  if is_numeric "$1"; then
    percent="$1"
  fi

  if is_numeric "$2"; then
    percent="$2"
  fi

  if is_string "$1"; then
    name="$1"
  fi
  if is_string "$2"; then
    name="$2"
  fi

  if [[ "${name}" == "undefined" ]]; then 
    wezterm cli split-pane --right --percent "${percent}" 1>/dev/null 2>/dev/null
    log "open tab to ${BOLD}right${RESET} (${DIM}${percent}%${RESET})"
  else
    log "open tab to ${BOLD}right${NO_BOLD} (${percent}%) named ${name}"
    wezterm cli split-pane --right --percent "${percent}" --title "${name}"
  fi
}

function below() {
  local percent="50"
  local name="undefined"

  if is_numeric "$1"; then
    percent="$1"
  fi

  if is_numeric "$2"; then
    percent="$2"
  fi

  if is_string "$1"; then
    name="$1"
  fi
  if is_string "$2"; then
    name="$2"
  fi

  if [[ "${name}" == "undefined" ]]; then 
    wezterm cli split-pane --bottom --percent "${percent}" 1>/dev/null 2>/dev/null
    log "open tab to ${BOLD}bottom${RESET} (${DIM}${percent}%${RESET})"
  else
    log "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) named ${name}"
    wezterm cli split-pane --bottom --percent "${percent}" --title "${name}"
  fi
}

function above()  {
  local percent="50"
  local name="undefined"

  if is_numeric "$1"; then
    percent="$1"
  fi

  if is_numeric "$2"; then
    percent="$2"
  fi

  if is_string "$1"; then
    name="$1"
  fi
  if is_string "$2"; then
    name="$2"
  fi

  if [[ "${name}" == "undefined" ]]; then 
    wezterm cli split-pane --top --percent "${percent}" 1>/dev/null 2>/dev/null
    log "open tab to ${BOLD}above${RESET} (${DIM}${percent}%${RESET})"
  else
    log "open tab to ${BOLD}above${NO_BOLD} (${percent}%) named ${name}"
    wezterm cli split-pane --top --percent "${percent}" --title "${name}"
  fi
}


