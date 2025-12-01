# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of shared shell scripts that provide utilities for system configuration, environment setup, and shell enhancements across macOS and Linux (particularly Debian) systems. The scripts are designed to be sourced from `~/.config/sh/`.

## Core Architecture

### Script Dependencies

The scripts follow a hierarchical dependency structure:

- **color.sh**: Base color definitions - no dependencies
- **typeof.sh**: Type checking utilities - no dependencies
- **os.sh**: OS detection - imports color.sh
- **utils.sh**: Core utilities - imports color.sh, os.sh, typeof.sh
- **adaptive.sh**: Main entry point - orchestrates loading of other scripts based on detected environment and is intended to be _sourced_ from a user's `.bashrc`, `.zshrc`, etc.

### Key Modules

- **adaptive.sh**: Main initialization script that sources other modules and sets up completions
- **utils.sh**: Extensive utility functions for file operations, string manipulation, system detection
- **aliases.sh**: Dynamic alias generation based on available commands (kubectl, nvim, lazygit, eza/exa)
- **initialize.sh**: System initialization for Debian systems (package installation, tool setup)
- **proxmox.sh**: Proxmox VE API integration utilities
- **build.sh**: Source compilation scripts (e.g., neovim from source)

## Static Analysis

The repository includes powerful static analysis capabilities via `static.sh`:

```bash
# Analyze functions in a directory/file
./static.sh <path>

# Get JSON output of all functions (used by reports/fns.sh)
bash_functions_summary <path>
```

The static analysis extracts:
- Function names, arguments, descriptions from comment blocks
- File locations and line ranges
- Duplicate function detection

## Common Development Commands

```bash
# Source the adaptive configuration
source ~/.config/sh/adaptive.sh

# View all available utility functions
./reports/fns.sh

# Filter functions by glob pattern
./reports/fns.sh "is_*"        # functions starting with "is_"
./reports/fns.sh "*debug*"     # functions containing "debug"

# Test color utilities
./tests/color.sh

# Initialize a Debian system with standard tools
./initialize.sh
```

## Code Conventions

### Function Patterns

- Functions use lowercase with underscores: `function_name()`
- Local variables declared with `local -r` for readonly or `local` for mutable
- Error handling via `panic()` for fatal errors, `error()` for recoverable ones
- Debug output via `debug "function_name" "message"` pattern
- Return values: 0 for success/true, 1 for failure/false

### Function Documentation

Document functions with comment blocks immediately above the function definition:

```bash
# function_name <arg1> [optional_arg2]
#
# Description of what the function does.
# Can span multiple lines.
function function_name() {
    # implementation
}
```

The static analysis tool extracts:
- First line matching function name becomes the arguments specification
- Remaining lines become the description
- Empty line after first line is automatically stripped

### Variable Conventions

- Script directory references: `SCRIPT_DIR="${HOME}/.config/sh"`
- Color variables from color.sh: `${BOLD}`, `${RESET}`, `${RED}`, etc.
- Use `has_command` to check for command availability before use
- Use utility functions like `is_empty`, `not_empty`, `contains`, `starts_with` for string operations

### Shell Compatibility

- Scripts target bash but include compatibility checks for zsh/fish
- Only use bash syntax for Bash 3.x
- You should not assume the availability of tools outside of bash (e.g., ripgrep, etc.)
  - If you want to use these tools always create a function which abstracts the functionality and make sure that this function has a fallback or at least a graceful error message
- Use `get_shell()` to detect current shell
- Shell-specific operations wrapped in conditionals (`is_bash()`, `is_zsh()`, `is_fish()`)

### Color Utilities

The `utils/color.sh` module provides extensive RGB-based colorization:

- Use `setup_colors` to initialize standard ANSI color variables (`${RED}`, `${BOLD}`, etc.)
- Use `rgb_text "R G B" "text"` for custom RGB foreground colors
- Use `rgb_text "R G B / R2 G2 B2" "text"` for foreground + background
- Use `rgb_text "/ R G B" "text"` for background only
- Use `colorize` to convert `{{TAG}}` markers to color variables (e.g., `{{RED}}`, `{{BOLD}}`)
- Predefined color functions: `orange`, `tangerine`, `slate_blue`, `lime`, `pink`, etc.
- Each has variants: plain, `_backed` (dark text, colored bg), `_highlighted` (colored text + muted bg)
- Background-only functions: `bg_*` (e.g., `bg_light_blue`, `bg_dark_gray`)
- Use `remove_colors` to unset all color variables

### Testing

This repository uses a hybrid testing approach:

**Automated Tests (Vitest)**:
```bash
pnpm test                  # Run all tests
pnpm test:watch            # Run in watch mode
pnpm test:coverage         # Generate coverage report
pnpm test tests/text.test.ts  # Run specific test file
```

**Visual Demos (Bash)**:
```bash
./tests/demos/color-demo.sh    # Interactive color demonstrations
```

**Test Structure**:
- `tests/*.test.ts` - Automated TypeScript tests using Vitest
- `tests/demos/*-demo.sh` - Visual demonstration scripts
- `tests/helpers/` - Test framework and utilities

**Writing Tests (Modern Approach)**:

The repository uses a custom test framework with `sourceScript()` and Vitest custom matchers:

```typescript
import { sourceScript } from './helpers'

// Test a function with parameters
const api = sourceScript('./utils/text.sh')('lc')('HELLO')

// Use custom matchers for readable assertions
expect(api).toBeSuccessful()       // Exit code 0
expect(api).toReturn('hello')      // Exact stdout match
expect(api).toContainInStdOut('ell')  // Stdout contains substring

// Test failure cases
const failApi = sourceScript('./utils.sh')('some_fn')('arg')
expect(failApi).toFail()           // Non-zero exit code
expect(failApi).toFail(42)         // Specific exit code

// Access result properties directly
expect(api.result.stdout).toBe('hello')
expect(api.result.code).toBe(0)
```

**Available Custom Matchers**:
- `.toBeSuccessful()` - Assert exit code 0
- `.toFail(code?)` - Assert non-zero exit code (optional: specific code)
- `.toReturn(expected)` - Assert exact stdout match
- `.toReturnTrimmed(expected)` - Assert trimmed stdout match
- `.toContainInStdOut(substring)` - Assert stdout contains string
- `.toReturnStdErr(expected)` - Assert exact stderr match
- `.toReturnStdErrTrimmed(expected)` - Assert trimmed stderr match
- `.toContainInStdErr(substring)` - Assert stderr contains string

**Limitations**:

The `sourceScript()` framework is designed for calling individual functions with parameters.
It cannot handle:
- Multi-step bash scripts with state setup (e.g., `var="x" && func $var`)
- Bash array initialization and reference passing
- Piping data to stdin
- Environment variable state between calls

For tests requiring these capabilities, use the deprecated helpers:
```typescript
import { bashExitCode, sourcedBash } from './helpers'

const exitCode = bashExitCode('source ./utils.sh && arr=("a" "b") && func arr')
```

See `tests/CUSTOM_MATCHERS.md` and `tests/README.md` for comprehensive testing guides.

**Mocking External Commands**:

For testing functions that call external commands (package managers, system tools), use the mock infrastructure in `tests/helpers/install-mocks.sh`. This allows testing install logic without actually installing anything.

```typescript
import { execSync } from 'child_process'

function runWithMocks(options: {
  availableCommands: string[]    // Commands that appear "installed"
  existingPackages: string[]     // Packages that "exist" (format: "manager:pkg")
  script: string                 // The bash script to run
}): { calls: string[]; exitCode: number } {
  // Source install.sh first, THEN mocks to override functions
  const fullScript = `
source utils/install.sh
source tests/helpers/install-mocks.sh
mock_available_commands ${options.availableCommands.map(c => `"${c}"`).join(' ')}
mock_package_exists ${options.existingPackages.map(p => `"${p}"`).join(' ')}
${options.script}
# ... capture calls and exit code
`
  // Execute and parse results
}

// Example test
it('should prefer brew over port', () => {
  const result = runWithMocks({
    availableCommands: ['brew', 'port'],
    existingPackages: ['brew:jq'],
    script: 'install_on_macos jq'
  })
  expect(result.calls.some(c => c.startsWith('brew:install'))).toBe(true)
})
```

**Mock Infrastructure Features**:
- `mock_available_commands "cmd1" "cmd2"` - Set which commands `has_command` returns true for
- `mock_package_exists "brew:jq" "apt:vim"` - Set which packages "exist" in which managers
- `mock_install_succeeds "brew:jq"` - Control which installs succeed (all succeed by default)
- `reset_mocks` - Clear all mock state
- `MOCK_CALLS` array - Records all mock function calls for verification

**Supported Mocked Commands**:
- Package managers: `brew`, `port`, `fink`, `apt`, `nala`, `dnf`, `yum`, `apk`, `pacman`, `yay`, `paru`
- Language tools: `nix-env`, `cargo`
- Utility overrides: `has_command`, `logc`, `SUDO`

**Important Limitation**: Commands piped to other commands (e.g., `nix-env -qa pkg | grep`) run in subshells and cannot record mock calls. Test install commands (not piped) rather than query commands when verifying behavior.
