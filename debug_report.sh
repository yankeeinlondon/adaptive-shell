#!/usr/bin/env bash

source ./utils.sh
source ./color.sh
source ./paths.sh

setup_colors
echo "About to call paths_for_env"
paths_output=$(paths_for_env)
echo "paths_output: '$paths_output'"
echo "Length: ${#paths_output}"
if [[ -z "$paths_output" ]]; then
    echo "EMPTY"
else
    echo "NOT EMPTY"
    IFS='|'
    paths=( $paths_output )
    echo "Array size: ${#paths[@]}"
fi
