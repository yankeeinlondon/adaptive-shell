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

# shellcheck source="../utils/text.sh"
source "${UTILS}/text.sh"
# shellcheck source="../utils/link.sh"
source "${UTILS}/link.sh"


function git_identity() {
    local name email key origin

    name="$(git config --get user.name 2>/dev/null || true)"
    email="$(git config --get user.email 2>/dev/null || true)"
    key="$(git config --get user.signingkey 2>/dev/null || true)"
    origin="$(git config --get remote.origin.url 2>/dev/null || true)"

    if is_empty_string "${origin}"; then
        origin=""
    else
        origin=" -> $(link_repo "${origin}")"
    fi


    echo "${name}<$(link_email "${email}")>, ${key}${origin}"
}
