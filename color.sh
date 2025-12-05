#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
    __COLOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "${__COLOR_SCRIPT_DIR}" == *"/utils" ]];then
        # Script is in the utils/ subdirectory
        UTILS="${__COLOR_SCRIPT_DIR}"
        ROOT="${__COLOR_SCRIPT_DIR%"/utils"}"
    else
        # Script is in the project root - set UTILS to the utils/ subdirectory
        ROOT="${__COLOR_SCRIPT_DIR}"
        UTILS="${ROOT}/utils"
    fi
    unset __COLOR_SCRIPT_DIR
else
    ROOT="${ADAPTIVE_SHELL}"
    UTILS="${ROOT}/utils"
fi
# shellcheck source="./utils/color.sh"
source "${UTILS}/color.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "to test colors try running the actual implementation found in utils/color.sh"
fi
