#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__FUNCTIONS_SH_LOADED:-}" ]] && return
__FUNCTIONS_SH_LOADED=1

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

source "${UTILS}/logging.sh"

# list_functions
#
# lists all bash functions defined in the ENV that are do not
# start with an underscore character.
list_functions() {
  mapfile -t fns < <(compgen -A function | grep -v '^_')
  printf '%s\n' "${fns[@]}"
}

# remove_functions <starting> <starting> <...>
#
# removes all functions which start with the function names
# provided as parameters.
remove_functions() {
  # Optional: --dry-run just prints what would be removed
  local dry=0
  [[ $1 == --dry-run ]] && dry=1 && shift

  (( $# )) || return 0  # no prefixes => nothing to do

  # Collect function names from list_functions (your existing function)
  local -a names=()
  local n
  while IFS= read -r n; do
    names+=("$n")
  done < <(list_functions)

  # Remove any function whose name starts with one of the prefixes
  local fn p
  for fn in "${names[@]}"; do
    for p in "$@"; do
      [[ $fn == ${p}* ]] || continue
      if (( dry )); then
        printf '%s\n' "$fn"
      else
        unset -f "$fn" 2>/dev/null || unfunction "$fn" 2>/dev/null
      fi
      break
    done
  done
}
