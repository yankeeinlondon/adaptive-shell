#!/usr/bin/env bash

# shellcheck source="./shared.sh"
source "${HOME}/.config/sh/shared.sh"

if file_exists "${HOME}/.env"; then
  source "${HOME}/.env"
fi

alias k='kubectl'
if has_command "nvim"; then
  alias v='nvim'
fi

if has_command "lazygit"; then
alias lg='lazygit'
fi

if has_command "htop"; then
  alias top='htop'
fi

if has_command "python3"; then
alias python='python3'
alias pip='pip3'
fi

if has_command "eza"; then 
alias ls='eza -a --icons=always'
alias ll='eza -lhga --git '
alias ld='eza -lDga --git'
alias lt='eza -lTL 3 --icons=always'
elif has_command "exa"; then
alias ls='exa -a --icons=always'
alias ll='exa -lhga --git '
alias ld='exa -lDga --git'
alias lt='exa -lTL 3 --icons=always'
fi

# FZF 
eval "$(fzf --zsh)"

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --lin-range :500 {}"
export FZF_ALT_C_OPTS="--preview 'eza --tree -color=always {} | head -200'"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in 
  cd)             fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
  export|unset)   fzf --preview "eval 'echo \$' {}" "$@" ;;
  ssh)            fzf --preview 'dig {}' "$@" ;;
  *)              fzf --preview "--preview 'bat -n --color=always --lin-range :500 {}" "$@" ;;
  esac
}

# Wezterm Aliases
function name() {
  local -r name="${1:-pwd}"

  if [[ "${name}" == "pwd" ]]; then
    wezterm cli set-tab-title "$(pwd)"
  else
    wezterm cli set-tab-title "${name}"
  fi
}
function left() {
  local percent="50"
  local name="undefined"

  if is_numeric "$1"; then
    percent="$1"
  fi

  if is_numeric "$2"; then
    percent="$2"
  fi

  if is_string "$1"; then
    name="$1"
  fi
  if is_string "$2"; then
    name="$2"
  fi

  if [[ "${name}" == "undefined" ]]; then 
    wezterm cli split-pane --left --percent "${percent}" 1>/dev/null 2>/dev/null
    log "open tab to ${BOLD}left${RESET} (${DIM}${percent}%${RESET})"
  else
    log "open tab to ${BOLD}left${NO_BOLD} (${percent}%) named ${name}"
    wezterm cli split-pane --left --percent "${percent}" --title "${name}"
  fi
}

function right() {
  local percent="50"
  local name="undefined"

  if is_numeric "$1"; then
    percent="$1"
  fi

  if is_numeric "$2"; then
    percent="$2"
  fi

  if is_string "$1"; then
    name="$1"
  fi
  if is_string "$2"; then
    name="$2"
  fi

  if [[ "${name}" == "undefined" ]]; then 
    wezterm cli split-pane --right --percent "${percent}" 1>/dev/null 2>/dev/null
    log "open tab to ${BOLD}right${RESET} (${DIM}${percent}%${RESET})"
  else
    log "open tab to ${BOLD}right${NO_BOLD} (${percent}%) named ${name}"
    wezterm cli split-pane --right --percent "${percent}" --title "${name}"
  fi
}

function below() {
  local percent="50"
  local name="undefined"

  if is_numeric "$1"; then
    percent="$1"
  fi

  if is_numeric "$2"; then
    percent="$2"
  fi

  if is_string "$1"; then
    name="$1"
  fi
  if is_string "$2"; then
    name="$2"
  fi

  if [[ "${name}" == "undefined" ]]; then 
    wezterm cli split-pane --bottom --percent "${percent}" 1>/dev/null 2>/dev/null
    log "open tab to ${BOLD}bottom${RESET} (${DIM}${percent}%${RESET})"
  else
    log "open tab to ${BOLD}bottom${NO_BOLD} (${percent}%) named ${name}"
    wezterm cli split-pane --bottom --percent "${percent}" --title "${name}"
  fi
}

function above()  {
  local percent="50"
  local name="undefined"

  if is_numeric "$1"; then
    percent="$1"
  fi

  if is_numeric "$2"; then
    percent="$2"
  fi

  if is_string "$1"; then
    name="$1"
  fi
  if is_string "$2"; then
    name="$2"
  fi

  if [[ "${name}" == "undefined" ]]; then 
    wezterm cli split-pane --top --percent "${percent}" 1>/dev/null 2>/dev/null
    log "open tab to ${BOLD}above${RESET} (${DIM}${percent}%${RESET})"
  else
    log "open tab to ${BOLD}above${NO_BOLD} (${percent}%) named ${name}"
    wezterm cli split-pane --top --percent "${percent}" --title "${name}"
  fi
}

# use "dust" over base "du" if available
function du() {
  if has_command "dust"; then
    $(dust -X .git -X node_modules "$*") && echo "\nExcluded .git and node_modules directory from results" && echo "use 'dust' to not exclude"
  else
    /usr/bin/du "$*"
  fi
}


function nixy() {
  if is_os "macos"; then 
    "${HOME}/.config/nixy/nixy" "${@}"
  else
    log "The ${ITALIC}${BOLD}nixy${RESET} command is primarily for macOS (${DIM}found $(os)${RESET})"
    log ""
    log "Some common commands in NixOS however are:"
    log " - uno"
    log " - dos"
    log " - tres"
    log ""
  fi
}

function vitesse() {
  if [ -z "$1" ]; then
    log "Syntax: ${BOLD}vitesse${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to install to  ${NO_DIM}\n"
    return
  fi

  npx degit antfu/vitesse "$1" --force
}

# preps a repo with common files where they don't exist
function prep() {
  if has_package_json; then
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
    
    log ""

    npm_install_devdep "bumpp"
    npm_install_devdep "eslint"
    npm_install_devdep "eslint-plugin-format"
    npm_install_devdep "@antfu/eslint-config"
    npm_install_devdep "typescript"
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
  else
    log "- no ${BLUE}package.json${RESET} found, ${ITALIC}skipping prep activities${RESET}"
  fi
}

function vitesse-ext() {
  if [ -z "$1" ]; then
    log "Syntax: ${BOLD}vitesse-ext${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to install to  ${NO_DIM}\n"
    return
  fi

  npx degit antfu/vitesse-webext "$1" --force
}

function gitignore() {
  if [ ! -f "./.gitignore" ]; then
    log "- creating ${BLUE}.gitignore${RESET} file"
    log ""
    cat <<'EOF' > "./.gitignore"
# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
**/trace/*.json
# Runtime data
*.pid
*.seed
*.pid.lock
# Directory for instrumented libs generated by jscoverage/JSCover
lib-cov
# Coverage directory used by tools like istanbul
coverage
# nyc test coverage
.nyc_output
# Grunt intermediate storage (http://gruntjs.com/creating-plugins#storing-task-files)
.grunt
# Bower dependency directory (https://bower.io/)
bower_components
# node-waf configuration
.lock-wscript
# Compiled binary addons (https://nodejs.org/api/addons.html)
build/Release
# Dependency directories
node_modules/
jspm_packages/
# Optional npm cache directory
.npm
# Optional eslint cache
.eslintcache
# Optional REPL history
.node_repl_history
# Output of 'npm pack'
*.tgz
# Yarn Integrity file
.yarn-integrity
# dotenv environment variables file
.env
# next.js build output
.next
# OS X temporary files
.DS_Store
# Transpiled Destinations
**/dist/
**/.presite
frontend/.vite-ssg-dist/**
/functions
# for simple TODOs
/todo.md

# Local Netlify folder
.netlify

.tsbuildinfo
trace/*
.trace/*
EOF
  else
    log "- the ${BLUE}.gitignore${RESET} file already exists, ${ITALIC}skipping${RESET}"
  fi
}

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
