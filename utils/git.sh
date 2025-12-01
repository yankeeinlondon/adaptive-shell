#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__GIT_SH_LOADED:-}" ]] && return
__GIT_SH_LOADED=1

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

# shellcheck source="./logging.sh"
source "${UTILS}/logging.sh"

function has_uncommitted_changes() {
    if ! git diff --quiet || ! git diff --cached --quiet; then
        debug "has_uncommitted_changes" "Repo is dirty (uncommitted changes present)"
        return 0
    else
        debug "has_uncommitted_changes" "Repo is clean (no uncommitted changes)"
        return 1
    fi
}

function has_unpushed_commits() {
    git fetch -q >/dev/null 2>/dev/null
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]; then
        debug "has_unpushed_commits" "Repo is dirty (local commits not pushed)"
        return 0
    else
        debug "has_unpushed_commits" "Repo is clean (no un-pushed commits)"
        return 1
    fi
}


function git_identity() {
    local name email key origin

    # shellcheck source="../utils/text.sh"
    source "${UTILS}/text.sh"
    # shellcheck source="../utils/link.sh"
    source "${UTILS}/link.sh"

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
