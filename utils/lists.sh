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

source "${UTILS}/logging.sh"

filter_list() {
  # Usage: filter_list PREFIX1 [PREFIX2 ...] <<< "$input"
  local prefixes=("$@")
  local item matched=0
  local out=()

  while IFS= read -r item; do
    matched=0
    for p in "${prefixes[@]}"; do
      if [[ $item == ${p}* ]]; then
        matched=1
        break
      fi
    done
    (( matched )) && out+=("$item")
  done

  printf '%s\n' "${out[@]}"
}


# filter_out ARR_NAME PREFIX1 [PREFIX2 ...]
filter_out() {
  local -n _arr="$1"; shift
  local it p match
  for it in "${_arr[@]}"; do
    match=0
    for p in "$@"; do
      [[ $it == ${p}* ]] && match=1 && break
    done
    (( ! match )) && printf '%s\n' "$it"
  done
}
