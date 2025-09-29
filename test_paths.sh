#!/usr/bin/env bash

paths=()

if [[ -d "$HOME/bin" ]]; then
    paths+=("User Binaries" "true" "$HOME/bin")
fi

paths+=("Test" "true" "testing")

IFS='|'
echo "${paths[*]}"
