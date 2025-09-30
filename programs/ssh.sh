#!/usr/bin/env bash

get_ssh_hosts() {
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
