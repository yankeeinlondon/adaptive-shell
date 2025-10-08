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
