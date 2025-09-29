#!/usr/bin/env bash

source ./utils.sh
source ./paths.sh

paths=()

if dir_exists "$HOME/bin"; then
    result=$(has_path "$HOME/bin")
    echo "has_path result: '$result'"
    paths+=("User Binaries" "$result" "$HOME/bin")
fi

IFS='|'
echo "${paths[*]}"
