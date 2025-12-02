# How to Do Good Sourcing

This guide covers best practices for sourcing shell scripts in this repository, including source guards, color handling, and the distinction between sourced and executed scripts.

## Source Guards

Source guards prevent a script from being sourced multiple times, which can cause:
- Redundant processing
- Variable overwrites
- Function redefinitions
- Unexpected side effects

### Pattern

```bash
#!/usr/bin/env bash

# Source guard - must be BEFORE any other code
[[ -n "${__MYSCRIPT_SH_LOADED:-}" ]] && return
__MYSCRIPT_SH_LOADED=1

# Rest of script...
```

### Key Points

1. **Place at the very top** - The guard must come before path setup or any other initialization
2. **Use unique variable names** - Convention: `__FILENAME_SH_LOADED` (double underscore prefix)
3. **Use `:-}` for safety** - Prevents errors if the variable is unset
4. **Use `return`, not `exit`** - `return` exits the sourced script; `exit` would terminate the calling shell

### Why Guards Return Early

When a script is sourced multiple times (e.g., through different dependency chains), the guard ensures:
- Functions are defined only once
- Initialization code runs only once
- No duplicate side effects

## Sourced vs Executed Scripts

Scripts behave differently when sourced (`source script.sh`) vs executed (`bash script.sh` or `./script.sh`).

### Detection Pattern

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    main_function "$@"
fi
```

### Key Differences

| Aspect | Sourced | Executed |
|--------|---------|----------|
| Environment | Shares caller's environment | New subprocess |
| Variables | Modifies caller's vars | Isolated vars |
| Functions | Available to caller | Lost when script ends |
| `exit` | Exits caller's shell! | Exits subprocess only |
| Source guards | Effective | No effect (fresh process) |

### Subprocess Implications

When running via `bash "${file}"`:
- Source guard variables are **not inherited** (fresh process)
- The script runs from scratch
- Functions defined inside aren't available to caller
- Environment variables must be explicitly exported to be visible

## Color Handling

This repository provides two approaches for colorized output.

### Approach 1: Template Tags with `logc` (Preferred)

Use `{{TAG}}` markers that `logc()` interpolates:

```bash
logc "{{BOLD}}{{BLUE}}Hello{{RESET}} {{DIM}}world{{RESET}}"
```

**Available tags:** `{{BOLD}}`, `{{DIM}}`, `{{ITALIC}}`, `{{RESET}}`, `{{RED}}`, `{{GREEN}}`, `{{BLUE}}`, `{{YELLOW}}`, `{{CYAN}}`, `{{MAGENTA}}`, `{{WHITE}}`, `{{BLACK}}`, `{{BRIGHT_RED}}`, `{{BRIGHT_GREEN}}`, `{{BRIGHT_BLUE}}`, etc.

**Why this is preferred:**
- `logc()` handles setup and cleanup automatically
- No need to call `setup_colors` or `remove_colors`
- Works consistently across sourced and executed contexts
- Colors are only active during the `logc` call

### Approach 2: Direct Variables with `setup_colors`

If you need direct variable access (e.g., for complex string building):

```bash
setup_colors

local msg="${BOLD}${BLUE}Hello${RESET} ${DIM}world${RESET}"
log "$msg"

remove_colors  # Clean up when done
```

**When to use:**
- Building strings outside of `logc` calls
- Performance-critical loops with many color operations
- Integration with external tools expecting escape codes

### The `logc` Lifecycle

Understanding how `logc()` works explains why direct variables fail without `setup_colors`:

```bash
function logc() {
    local colors_missing=$(colors_not_setup)

    if [[ "$colors_missing" == "0" ]]; then
        setup_colors      # Temporarily set color vars
    fi

    content="$(colorize "${*}")"  # Convert {{TAG}} to escape codes
    printf "%b\n" "${content}${reset}"

    if [[ "$colors_missing" == "0" ]]; then
        remove_colors     # Clean up color vars
    fi
}
```

**Important:** If you use `${BLUE}` directly in a string passed to `logc`, the variable is evaluated **before** `logc` runs. Since colors aren't set up yet, `${BLUE}` expands to empty string.

```bash
# WRONG - ${BLUE} evaluated before logc sets up colors
logc "{{BOLD}}${BLUE}Hello{{RESET}}"  # ${BLUE} is empty!

# CORRECT - Use tag format
logc "{{BOLD}}{{BLUE}}Hello{{RESET}}"
```

## Script Organization Patterns

### Pattern 1: Report Scripts (e.g., `reports/sys.sh`)

Scripts that generate output when executed directly:

```bash
#!/usr/bin/env bash

# Source guard
[[ -n "${__SYS_SH_LOADED:-}" ]] && return
__SYS_SH_LOADED=1

# Path setup
if [ -z "${ADAPTIVE_SHELL}" ]; then
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${UTILS%"/reports"}"
else
    ROOT="${ADAPTIVE_SHELL}"
    UTILS="${ROOT}/utils"
fi

# Define functions
function report_sys() {
    source "${UTILS}/color.sh"
    source "${UTILS}/logging.sh"
    # ... implementation using logc with {{TAG}} format
}

# Execute when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    report_sys
fi
```

### Pattern 2: Utility Libraries (e.g., `utils/text.sh`)

Scripts providing functions to other scripts:

```bash
#!/usr/bin/env bash

# Source guard
[[ -n "${__TEXT_SH_LOADED:-}" ]] && return
__TEXT_SH_LOADED=1

# Path setup (minimal - just set ROOT/UTILS)
# ...

# Define utility functions
function trim() {
    # ...
}

function contains() {
    # ...
}

# No execution block - library only
```

### Pattern 3: User-Facing Functions (e.g., `user-functions.sh`)

Functions that spawn subprocesses:

```bash
# Run report in subprocess (isolated environment)
function sys() {
    local -r file="${REPORTS}/sys.sh"
    bash "${file}" "report_sys"
}

# This works because:
# 1. Fresh bash process - no source guards set
# 2. Script sources its dependencies fresh
# 3. Colors handled via {{TAG}} format in logc
```

## Common Pitfalls

### 1. Using `exit` in Sourced Scripts

```bash
# WRONG - will exit caller's shell!
if [[ -z "$required_var" ]]; then
    exit 1
fi

# CORRECT - return from sourced script
if [[ -z "$required_var" ]]; then
    return 1
fi
```

### 2. Mixing Color Approaches

```bash
# WRONG - ${GREEN} evaluated before setup
logc "Status: ${GREEN}OK{{RESET}}"

# CORRECT - consistent tag format
logc "Status: {{GREEN}}OK{{RESET}}"
```

### 3. Forgetting Source Guard Placement

```bash
# WRONG - initialization runs before guard
source "${UTILS}/color.sh"

[[ -n "${__MYSCRIPT_SH_LOADED:-}" ]] && return
__MYSCRIPT_SH_LOADED=1

# CORRECT - guard first
[[ -n "${__MYSCRIPT_SH_LOADED:-}" ]] && return
__MYSCRIPT_SH_LOADED=1

source "${UTILS}/color.sh"
```

### 4. Assuming Inherited Variables in Subprocesses

```bash
# In parent shell
export MY_VAR="value"
bash child.sh  # MY_VAR is available (exported)

MY_OTHER_VAR="value"
bash child.sh  # MY_OTHER_VAR is NOT available (not exported)

# Source guards are shell variables, not exported
# So they reset in subprocesses
```

## Summary

1. **Always use source guards** at the top of scripts that may be sourced multiple times
2. **Use `{{TAG}}` format** with `logc` for colors - it's self-contained and reliable
3. **Understand the execution context** - sourced vs executed makes a big difference
4. **Use `return` not `exit`** in scripts that may be sourced
5. **Place guards before any initialization** to prevent partial re-execution
