#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
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
# shellcheck source="./utils/color.sh"
source "${UTILS}/color.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "to test colors try running the actual implementation found in utils/color.sh"
fi
