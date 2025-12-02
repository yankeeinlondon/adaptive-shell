#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__SSH_SH_LOADED:-}" ]] && return
__SSH_SH_LOADED=1

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


# get_ssh_hosts()
#
# Get's all defined hosts in the `.ssh/config` file.
function get_ssh_hosts() {
  local ssh_config="${HOME}/.ssh/config"
  local hosts=()

  # Check if file exists and is readable
  if [[ -f "$ssh_config" && -r "$ssh_config" ]]; then
    # Extract host names, ignoring lines like "HostName"
    while IFS= read -r host; do
      hosts+=("$host")
    done < <(grep -E '^[[:space:]]*Host[[:space:]]+' "$ssh_config" \
              | grep -vE 'Host(Name|KeyAlgorithms|basedAuthentication)' \
              | sed -E 's/^[[:space:]]*Host[[:space:]]+//')
  fi

  # Print array in a way usable by caller
  printf '%s\n' "${hosts[@]}"
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
