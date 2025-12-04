#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__FUNCTIONS_SH_LOADED:-}" ]] && declare -f "list_functions" > /dev/null && return
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
