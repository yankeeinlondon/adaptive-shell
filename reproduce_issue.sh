#!/usr/bin/env bash

# Mocking parts of user-functions.sh and utils to reproduce the issue
ROOT="$(pwd)"
UTILS="${ROOT}/utils"
export ADAPTIVE_SHELL="${ROOT}"

source "${UTILS}/logging.sh"
source "${UTILS}/filesystem.sh"
source "${UTILS}/detection.sh"

# Create a dummy system-prompt.md
mkdir -p docs
cat <<EOF > docs/system-prompt.md
<system_override_directive>
<identity_adjustment>
You are a Senior Systems Architect specializing in working with AI in the Rust programming language.
</identity_adjustment>
</system_override_directive>
EOF

# Simulate the problematic part of the claude function
function reproduce_claude_bug() {
    local -r prompt_filepath="${PWD}/docs/system-prompt.md"
    
    if file_exists "${prompt_filepath}"; then
        # This is where the bug is suspected: prompt variable gets the CONTENT of the file
        local prompt="$(get_file "${prompt_filepath}")"
        
        # logc called with the content of the file
        logc "\n- {{BLUE}}{{BOLD}}Claude{{RESET}} session -- {{ITALIC}}with system prompt{{RESET}}-- exited."
        logc ""
        logc "{{BOLD}}System Prompt:{{RESET}}"
        
        # Suspected BUG: prompt contains the actual content, not the path
        # cat \$(content) will fail if content is long
        echo "Attempting: cat \"\${prompt}\""
        cat "${prompt}"
    fi
}

reproduce_claude_bug
