#!/usr/bin/env bash
set -euo pipefail

RESET=$'\033[0m'
BOLD=$'\033[1m'

# A global array to track PIDs for backgrounded commands
pids=()

YELLOW=$'\033[33m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
BRIGHT_BLACK=$'\033[90m'
BRIGHT_WHITE=$'\033[97m'

BG_BLUE=$'\033[44m'
BG_GREEN=$'\033[42m'
BG_YELLOW=$'\033[43m'
BG_BRIGHT_BLACK=$'\033[100m'
BG_MAGENTA=$'\033[45m'
BG_BRIGHT_MAGENTA=$'\033[105m'
BG_BRIGHT_RED=$'\033[101m'
BG_BRIGHT_BLUE=$'\033[104m'

COLOR_IDX=0

COLOR_OPTIONS=(
    "${BG_GREEN}${BOLD}${BRIGHT_BLACK}"
    "${BG_BLUE}${BOLD}${BRIGHT_BLACK}"
    "${BG_MAGENTA}${BOLD}${BRIGHT_BLACK}"
)

function get_color() {
    local color="${COLOR_OPTIONS[${COLOR_IDX}]}"
    (( COLOR_IDX+=1 ))
    if [[ COLOR_IDX -gt ${#COLOR_OPTIONS[@]} ]]; then
        COLOR_IDX="0"
    fi

    echo "${color}"
}



##############################################################################
# Function: track
# 
# Usage:  track "<PREFIX>" <command> [args...]
# 
# - Launches the given command as a background job
# - Redirects stdin from /dev/null so it won’t hang or get SIGTTIN
# - Pipes output to `sed` to prepend a prefix for each line
# - Captures the PID in the global 'pids' array
##############################################################################
track() {
    local -r name="${1:?No prefix sent to track() function!}"
    local -r command="${2:?No command sent to track() function!}"
    local -r color="${3:?No color sent to track() function!}"
    local -r prefix="${color}${name}${RESET}"

    # Start the command in the background and capture its PID
    (
        FORCE_COLOR=1 bash -c "${command}" < /dev/null 2>&1 | sed "s/^/$prefix /"
    ) &
    local pid=$!

    # Check if the process started successfully
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "${BG_BRIGHT_RED}${BRIGHT_WHITE}Error ${RESET} - failed to start service \"${command}\"!" >&2
        return 1
    fi

    # Track the process and print a success message
    pids+=("$pid")
    echo "${BG_BRIGHT_BLACK}${BRIGHT_WHITE}Service ${RESET} - started service \"${command}\" with PID ${YELLOW}$pid${RESET}" >&2
}

##############################################################################
# Function: waitFor
# 
# - Waits for all tracked PIDs to finish
##############################################################################
waitFor() {
  wait "${pids[@]}"
}

##############################################################################
# Function: cleanup
# 
# - Triggered on SIGINT (Ctrl+C), SIGTERM, or script exit
# - First sends SIGINT to each process (graceful shutdown)
# - Then after a brief pause, SIGKILL any process that’s still running
# - Finally waits for them to terminate
##############################################################################
cleanup() {
  echo ""
  echo "Shutting down all processes..."
  
  # Graceful kill
  for pid in "${pids[@]}"; do
    kill -INT "$pid" 2>/dev/null || true
  done
  
  sleep 1
  
  # Force kill if still alive
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      echo "Force-killing PID $pid"
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  
  # Wait on them to exit fully
  wait
  echo "All background processes have been shut down."
}

start() {
    local -ra params=( "$@" )
    local -r count="${#params[@]}"

    if (( count == 0 )); then
        echo "- invalid parameters passed to ${BOLD}Track${RESET} service!"
        echo "- ${ITALIC}no parameters${RESET} were received!"
        echo ""
        echo "  syntax: ${DIM}track [name1] [command1] [name2] [command2] ..."
        echo ""
        return 1
    fi

    if (( count % 2 != 0 )); then
        echo "- invalid parameters passed to ${BOLD}Track${RESET} service!"
        echo "- the number of parameters must be even"
        echo ""
        echo "  syntax: ${DIM}track [name1] [command1] [name2] [command2] ..."
        echo ""
        return 1
    fi

    # Iterate over the name-command pairs and track each process
    for (( i = 0; i < count; i+=2 )); do
        local name="${params[i]}"
        local command="${params[i+1]}"
        local color
        color="$(get_color)"

        track "$name" "$command" "$color"
    done
}

trap cleanup SIGINT SIGTERM EXIT

start "$@"

waitFor
