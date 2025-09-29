#!/usr/bin/env bash

function path_for_env() {
    local -na path=()

    if dir_exists "${HOME}/.bun"; then
        # shellcheck disable=SC1091
        [ -s "${HOME}/.bun/_bun" ] && source "${HOME}/.bun/_bun"
        
        path+=("${HOME}/.bin")
    fi

    if dir_exists "${HOME}/.local/bin"; then
        path+=("${HOME}/.local/bin")
    fi


}
