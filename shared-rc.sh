#!/usr/bin/env bash

# ENV Variables

# add path for the krew pkg manager for kubernetes/kubectl
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
# provide a good set of default paths to search for the directory in
export CDPATH=".:..:${HOME}/coding/personal:${HOME}/coding/langler:${HOME}/coding/particle:${HOME}/coding/lifegadget:${HOME}/coding/inocan/open-source:${HOME}/coding/langler:./packages:${HOME}/"

# Handy Aliases
# alias du="dust -X .git -X node_modules && echo \"\nUse 'dust' to not exclude node_modules and git\"" 2>&1
alias k='kubectl'
alias kn='kubens'
alias kc="kubectx"
alias v='nvim'
alias lg='lazygit'
alias top='htop'
alias python='python3'
alias pip='pip3'
alias ls='exa'
alias ll='exa -lga --git'
alias ld='exa -lDga --git'
alias l='exa -a'


function name() {
  local -r name="${1:-pwd}"

  if [[ "${name}" == "pwd" ]]; then
    wezterm cli set-tab-title "$(pwd)"
  else
    wezterm cli set-tab-title "${name}"
  fi
}

function left() {
  wezterm cli split-pane --left --percent 50
}

function right() {
  wezterm cli split-pane --right --percent 50
}

function below() {
  wezterm cli split-pane --bottom --percent 50
}

function above()  {
  wezterm cli split-pane --top --percent 50
}

# has_command <cmd>
function has_command() {
    local -r cmd="${1:?cmd is missing}"

    if command -v "${cmd}" &> /dev/null; then
        return 0
    else 
        return 1
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


export RED='\033[38;5;1m'
export YELLOW2='\033[38;5;3m'
export BLACK='\033[30m'
export RED='\033[31m'
export GREEN='\033[32m'
export YELLOW='\033[33m'
export BLUE='\033[34m'
export MAGENTA='\033[35m'
export CYAN='\033[36m'
export WHITE='\033[37m'

export BRIGHT_BLACK='\033[90m'
export BRIGHT_RED='\033[91m'
export BRIGHT_GREEN='\033[92m'
export BRIGHT_YELLOW='\033[93m'
export BRIGHT_BLUE='\033[94m'
export BRIGHT_MAGENTA='\033[95m'
export BRIGHT_CYAN='\033[96m'
export BRIGHT_WHITE='\033[97m'


export RESET='\033[0m'
export BOLD='\033[1m'
export NO_BOLD='\033[21m'
export DIM='\033[2m'
export NO_DIM='\033[22m'
export ITALIC='\033[3m'
export NO_ITALIC='\033[23m'
export STRIKE='\033[9m'
export NO_STRIKE='\033[29m'
export REVERSE='\033[7m'
export NO_REVERSE='\033[27m'

export BG_BLACK='\033[40m'
export BG_RED='\033[41m'
export BG_GREEN='\033[42m'
export BG_YELLOW='\033[43m'
export BG_BLUE='\033[44m'
export BG_MAGENTA='\033[45m'
export BG_CYAN='\033[46m'
export BG_WHITE='\033[47m'

export BG_BRIGHT_BLACK='\033[100m'
export BG_BRIGHT_RED='\033[101m'
export BG_BRIGHT_GREEN='\033[102m'
export BG_BRIGHT_YELLOW='\033[103m'
export BG_BRIGHT_BLUE='\033[104m'
export BG_BRIGHT_MAGENTA='\033[105m'
export BG_BRIGHT_CYAN='\033[106m'
export BG_BRIGHT_WHITE='\033[107m'

# moves executing into a kubernetes container
function into () {
  if [[ -z "$1" ]]; then
      echo "Syntax: into \$1 \$2, ... where:" 1>&2
      echo "  \$1 - is the name of the POD you're wanting to shell into" 1>&2
      echo "  \$2 - is the shell you want to use; will use 'bash' by default" 1>&2
      return 1
  else
      SHELL="${2-bash}"
      printf '%s' "Going into POD ${1} using the $SHELL command:\n  kubectl exec -it ${1} ${SHELL}" 1>&2
      kubectl exec -it "${1}" -- "$SHELL"
      echo "Back into parent shell" 1>&2
      return 0
  fi
}

# checks for given text in either stdin or a filename
function has () {
  LOOK_FOR=${1}
  if [[ -z "$1" ]]; then
    printf '%s' "Syntax: use \${1} \${2}, where ...\n"
    echo "  1 - is the text you are looking for"
    echo "  2 - is the file you're looking in; if left out it will read from stdin instead\n"
    return
  fi
  CONTENT=""
  while read -r line 
  do
    CONTENT="${CONTENT}$line"
  done < "${2:-/dev/stdin}"

  if [[ "$CONTENT" == *"${LOOK_FOR}"* ]]; then
    echo "true"
    return 0
  else
    echo "false"
    return 1
  fi
}

function listening() {
		lsof -i:"$1";
}
function killListener() {
	kill -9 "$(lsof -i:"$1" -t)"
}

# history convenience utility
function h () {
	re='^[0-9]+$'
	if [[  $1 =~ $re ]]; then
		echo "History (last $1):"
	 	history "$1"
	 elif [[ -z "$1" ]]; then
		echo "History (all):"
	 	history
	 else
	 	echo "History (filtered by '$1')"
	 	history | grep -v grep | grep "$1"
	fi
}

# find running processes
function running() {
	SERVICE=$1

	ps -aef | grep -v grep | grep "$1"
	if [ "$?" -ne "0" ]; then
		echo "no processes matching the grep pattern '$SERVICE' are running"
	fi
}


# find files
function f() {
	argn=${#}
	first=$1

	if [ "$argn" -eq "1" ]; then
		find . -name "$*"
	else
		shift
		find "$first" -name "$*"
	fi
}

function log() {
    printf "%b\\n" "${*}" >&2
}

function vitesse() {
  if [ -z "$1" ]; then
    echo "Syntax: ${BOLD}vitesse${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to install to  ${NO_DIM}\n"
    return
  fi

  npx degit antfu/vitesse "$1" --force
}

function vitesse-ext() {
  if [ -z "$1" ]; then
    echo "Syntax: ${BOLD}vitesse-ext${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to install to  ${NO_DIM}\n"
    return
  fi

  npx degit antfu/vitesse-webext "$1" --force
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
      echo ""
      echo "Added a ${BOLD}.markdownlint.jsonc${NO_BOLD} to the currrent directory"
      echo ""
      cat "./.markdownlint.jsonc"
      return
    fi
  fi

  echo ""
  echo "you already have an existing markdown lint file so no action necessary"
  echo ""
}

# disk_left [dir]
function ddu() {
  local dir;

  if [[ "$1" =~ /.*--help/ ]]; then
    echo "Syntax: ${BOLD}storage_left${NO_BOLD} ${ITALIC}\${1}${NO_ITALIC}, ${DIM}where ${NO_DIM}${ITALIC}\${1}${NO_ITALIC} ${DIM}indicates the directory to start evaluating in (using current directory if not specified)  ${NO_DIM}\n"
    return
  fi
  if [ -z "$1" ]; then
    dir="$PWD"
  else
    dir="$1"
  fi
  log "Disk usage by subdirectory; starting in ${BLUE}${dir}${RESET}"
  log ""

  if has_command "dust"; then 
    dust -D "${dir}/*"
  else 
    /usr/bin/du -cksh "${dir}/*"
  fi
}
