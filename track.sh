#!/usr/bin/env bash
set -euo pipefail

# shellcheck source="./color.sh"
source "${HOME}/.config/sh/color.sh"

# A global array to track PIDs for backgrounded commands
pids=()

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
  local prefix="$1"
  shift

  (
    # Run the actual command, piping to sed for prefix
    # Stdin is /dev/null so it doesn't block for input or get suspended
    FORCE_COLOR=1 "$@" < /dev/null 2>&1 | sed "s/^/$prefix /"
  ) &
  
  local pid=$!
  pids+=("$pid")

  echo "Started process \"$*\" with PID $pid" >&2
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
    echo "Terminating processes..."
  
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

trap cleanup SIGINT SIGTERM EXIT
