#!/usr/bin/env bash

function git_identity() {
    local name email key origin

    name="$(git config --get user.name 2>/dev/null || true)"
    email="$(git config --get user.email 2>/dev/null || true)"
    key="$(git config --get user.signingkey 2>/dev/null || true)"
    origin="$(git config --get remote.origin.url 2>/dev/null || true)"

    echo "${name}<${email}>, ${key} -> ${origin}"
}
