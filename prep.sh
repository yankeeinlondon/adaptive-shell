#!/usr/bin/env bash

# shellcheck source="./shared.sh"
source "${HOME}/.config/sh/shared.sh"

# mdlint()
# 
# provides a more reasonable set of defaults for Markdown Linting
# in a .markdownlint.jsonc file.
function mdlint() {
  # test if file exists
  if [ ! -f "./.markdownlint.json" ]; then
    if [ ! -f "./.markdownlint.jsonc" ]; then
      cat <<'EOF' > "./.markdownlint.jsonc"
// [markdown lint file](https://github.com/DavidAnson/markdownlint)
{
  "MD041": false, // [don't require first line to be H1](https://github.com/DavidAnson/markdownlint/blob/main/doc/md041.md) 
  "MD013": false, // [allow any line length](https://github.com/DavidAnson/markdownlint/blob/main/doc/md013.md)
  "MD012": false, // [allow multiple consecutive blank lines](https://github.com/DavidAnson/markdownlint/blob/main/doc/md012.md)
  "MD009": false, // [allow trailing spaces](https://github.com/DavidAnson/markdownlint/blob/main/doc/md009.md)
}
EOF
      log ""
      log "Added a ${BOLD}.markdownlint.jsonc${RESET} file to the currrent directory"
      log ""
      cat "./.markdownlint.jsonc"
      return
    fi
  fi

  log "- the ${BLUE}.markdownlint.jsonc${RESET} file already exists, ${ITALIC}skipping${RESET}"
}

# has_command <cmd>
#
# checks whether a particular program passed in via $1 is installed 
# on the OS or not (at least within the $PATH)
function has_command() {
    local -r cmd="${1:?cmd is missing}"

    if command -v "${cmd}" &> /dev/null; then
        return 0
    else 
        return 1
    fi
}

# install_just()
#
# installs the Just runner whereever possible
# https://github.com/casey/just
function install_just() {
    if has_command "just"; then
        echo "just runner already installed";
    else
        if has_command "homebrew"; then
            brew install just
        elif has_command "asdf"; then
            asdf plugin add just
            asdf install just
        elif has_command "npm"; then 
            npm install -g rust-just
        elif has_command "apk"; then 
            apk add just
        elif has_command "nix-env"; then
            nix-env -iA nixpkgs.just
        elif has_command "cargo"; then 
            cargo install just 
        elif has_command "conda"; then 
            conda install -c conda-forge just
        elif has_command "snap"; then
            snap install --edge --classic just
        else 
            echo "- unsure how to install the just runner in your environment"
            echo "- checkout https://github.com/casey/just for more info"
        fi
    fi
}


# justfile()
# 
# adds a `.justfile` for the just runner
function justfile() {
  if [ ! -f "./.justfile" ]; then
    cat <<'EOF' > "./.justfile"
set dotenv-load

repo := `pwd`

BOLD := '\033[1m'
RESET := '\033[0m'
YELLOW2 := '\033[38;5;3m'
BLACK := '\033[30m'
RED := '\033[31m'
GREEN := '\033[32m'
YELLOW := '\033[33m'
BLUE := '\033[34m'
MAGENTA := '\033[35m'
CYAN := '\033[36m'
WHITE := '\033[37m'

default:
  @echo
  @echo TITLE 
  @just --list
  @echo 

# do something cool
something:
  @echo "no really ... do something cool!"
EOF

    echo ""
    echo "Added a ${BOLD}${BLUE}justfile${RESET} to the currrent directory"
    echo ""
  else 
    echo "- there is already a .justfile here!"
    echo ""
  fi
}

# setEnv()
# 
# sets the Python environment into the `.envrc` file so that the `direnv`
# program will auto-activate it when entering the directory
function setEnv() {
  if ! has_command "conda"; then
    log "${RED}${BOLD}Error:${RESET} conda is not installed."
    return 1
  fi

  if ! has_command "direnv"; then
    log "${RED}${BOLD}Error:${RESET} direnv is not installed. Please install direnv to use this script."
    return 1
  fi

  # List available conda environments
  log "Available conda environments:"
  conda info --envs
  log ""

  # Get user's choice
  printf "Please enter the name of the environment to activate: "
  read -r selected_env

  echo "source $(which activate) ${selected_env}" > .envrc
  direnv allow .

  log "Environment '${GREEN}${BOLD}${selected_env}${RESET}' will now always be used in this directory."
  log ""
  log "- update the .envrc file to change the preferred environment if you wish to change"
  log "- you can also run ${BLUE}${BOLD}conda info --envs${RESET} at any point to validate the preferred env."
  log ""
}

# sets up TS related things when prep()
# detects the environment is a JS/TS environment
function ts_prep() {
    mdlint
    gitignore
    if [ -f "./eslint.config.ts" ]; then
      log "- the ${BLUE}eslint.config.ts${RESET} file already exists, ${ITALIC}skipping${RESET}"
    else
      cat "${HOME}/.config/sh/resources/eslint.config.ts" > eslint.config.ts
      log "- added ${BLUE}eslint.config.ts${RESET} to repo"
    fi

    if file_exists ".shellcheckrc"; then
      log "- the ${BLUE}.shellcheckrc${RESET} file already exists, ${ITALIC}skipping${RESET}"
    else
      echo "external-sources=true" > .shellcheckrc
      log "- added a ${BLUE}.shellcheckrc${RESET} file"
    fi

    if file_exists "./tsconfig.json"; then
      log "- the ${BLUE}tsconfig.json${RESET} file already exists, ${ITALIC}skipping${RESET}"
    else
      cat "${HOME}/.config/sh/resources/tsconfig.json" > tsconfig.json
      log "- added ${BLUE}tsconfig.json${RESET} to repo"
    fi

    if file_exists "./vitest.config.ts"; then
      log "- the ${BLUE}vitest.config.ts${RESET} file already exists, ${ITALIC}skipping${RESET}"
    else
      cat "${HOME}/.config/sh/resources/vitest.config.ts" > vitest.config.ts
      log "- added ${BLUE}vitest.config.ts${RESET} to repo"
    fi

    if ! dir_exists "./src"; then
        mkdir "src"
    fi
    if ! dir_exists "./tests"; then
        mkdir "tests"
    fi


    log ""

    npm_install_devdep "bumpp"
    npm_install_devdep "eslint"
    npm_install_devdep "eslint-plugin-format"
    npm_install_devdep "@antfu/eslint-config"
    npm_install_devdep "typescript"
    npm_install_devdep "@types/node@22"
    npm_install_devdep "npm-run-all"
    npm_install_devdep "@type-challenges/utils"
    npm_install_devdep "jiti"
    npm_install_devdep "vitest"
    npm_install_devdep "husky"

    if not_in_package_json 'eslint --flag unstable_ts_config'; then
      log ""
      log "- consider adding a script target ${GREEN}lint${RESET} as: ${DIM}eslint --flag unstable_ts_config src tests${RESET}"
    fi

    log ""

    if [ -d "./.github/workflows" ]; then
      log "- ${BOLD}Github Actions${RESET} exists, ${ITALIC}skipping${RESET}"
    else 
      mkdir -p "./.github/workflows"
      cat "${HOME}/.config/sh/resources/github.main.yaml" > ./.github/workflows/main.yaml
      cat "${HOME}/.config/sh/resources/github.other.yaml" > ./.github/workflows/other.yaml
      log "- created ${BOLD}Github Actions${RESET} in ${BLUE}.github/workflows${RESET}"
    fi

    if [ -f "./.husky/pre-push" ]; then
      log "- ${BOLD}Husky${RESET} ${GREEN}${DIM}pre-push${RESET} event exists, ${ITALIC}skipping${RESET}"
    else
      if [ -d "./.husky" ]; then
        echo "" 1>/dev/null
      else
        mkdir "./.husky"
      fi
      cat "${HOME}/.config/sh/resources/pre-push" > "./.husky/pre-push"
      log "- created ${GREEN}pre-push${RESET} event in Husky directory"
    fi

    log ""

}

function rust_prep() {
    echo ""
}

function py_prep() {
    echo ""
}



# preps a directory with common files where they don't exist
function prep() {
  if has_package_json; then
    ts_prep
  elif has_file "requirements.txt"; then
    echo ""
  else
    log "- no ${BLUE}package.json${RESET} found, ${ITALIC}skipping prep activities${RESET}"
  fi
}
