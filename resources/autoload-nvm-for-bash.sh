#!/usr/bin/env bash

cdnvm() {
  command cd "$@" || return $?
  nvm_path="$(nvm_find_nvmrc)"

  if [[ -n $nvm_path ]]; then
    nvm use
  else
    nvm use default
  fi
}

alias cd='cdnvm'

