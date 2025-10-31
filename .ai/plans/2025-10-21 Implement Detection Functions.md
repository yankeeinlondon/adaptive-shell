# Plan: Implement TODO Functions in utils/detection.sh

**Date**: 2025-10-21
**Goal**: Implement all 9 TODO-marked functions in utils/detection.sh with full test coverage
**Complexity**: Medium-High (circular dependencies, git integration, filesystem checks)

## Problem Analysis

### Functions to Implement

1. **Git Repository Functions** (foundational):
   - `is_git_repo()` - Check if path is in git repo ⚠️ **CIRCULAR DEPENDENCY BUG**
   - `repo_root()` - Get git repo root ⚠️ **CIRCULAR DEPENDENCY BUG**
   - `repo_is_dirty()` - Check for uncommitted changes

2. **Repository Analysis Functions**:
   - `is_monorepo()` - Detect monorepo structure
   - `has_package_json()` - Find package.json
   - `has_typescript_files()` - Find TypeScript files

3. **Project Type Detection Functions**:
   - `looks_like_js_project()` - Detect JavaScript/TypeScript project
   - `looks_like_rust_project()` - Detect Rust project
   - `looks_like_python_project()` - Detect Python project

### Critical Issues Found

**Circular Dependencies:**
```bash
# is_git_repo calls itself! Line 192
function is_git_repo() {
    if is_git_repo "${path}"; then  # ← CALLS ITSELF
        repo_root="$(repo_root "${path}")"
    fi
}

# repo_root calls is_git_repo which calls repo_root! Line 230
function repo_root() {
    if is_git_repo "${path}"; then  # ← CIRCULAR
        repo_root="$(repo_root "${path}")"  # ← CALLS ITSELF
    fi
}
```

**These must be fixed first or all functions will fail.**

### Dependencies Between Functions

```
is_git_repo() ←─┐
                ├─ repo_root() ←─┬─ repo_is_dirty()
                │                 ├─ is_monorepo()
                │                 ├─ has_package_json()
                │                 └─ has_typescript_files()
                │
                └─ looks_like_js_project()
                   looks_like_rust_project()
                   looks_like_python_project()
```

**Implementation Order**:
1. Fix `is_git_repo()` first (no dependencies)
2. Fix `repo_root()` (depends on is_git_repo)
3. Implement functions that depend on repo_root
4. Implement standalone project detection functions

## Phase 0: Setup and Planning

**Objective**: Create test infrastructure and fix circular dependencies

### Tasks:

1. **Create test file** (10 min)
   - Create `tests/WIP/detection.test.ts`
   - Import bash test helpers
   - Set up test structure for all 9 functions

2. **Create test fixtures** (15 min)
   - Create temporary git repos for testing
   - Create sample project structures
   - Set up cleanup in afterEach

3. **Document current bugs** (5 min)
   - Document circular dependency issues
   - Plan refactoring approach
   - Review existing code patterns

**Deliverables**:
- Empty test file with describe blocks
- Test fixture setup code
- Bug documentation

## Phase 1: Fix Circular Dependencies & Implement Core Git Functions

**Objective**: Implement is_git_repo() and repo_root() without circular dependencies

### 1.1: Implement is_git_repo() (TDD)

**Current broken code:**
```bash
function is_git_repo() {
    local -r path="${1}:-${CWD}"
    local repo_root

    if is_git_repo "${path}"; then  # ← BUG: calls itself!
        repo_root="$(repo_root "${path}")"
    else
        repo_root="${path}"
    fi
    # TODO
    return 1
}
```

**Correct implementation approach:**
```bash
function is_git_repo() {
    local -r path="${1:-${PWD}}"

    # Change to the directory and check if we're in a git repo
    if [ -d "${path}" ]; then
        ( cd "${path}" && git rev-parse --git-dir >/dev/null 2>&1 )
        return $?
    else
        return 1
    fi
}
```

**Tests to write first:**
```typescript
describe('is_git_repo()', () => {
  it('should return 0 for current repo', () => {
    const exitCode = bashExitCode('source ./utils.sh && is_git_repo "."')
    expect(exitCode).toBe(0)
  })

  it('should return 1 for /tmp', () => {
    const exitCode = bashExitCode('source ./utils.sh && is_git_repo "/tmp"')
    expect(exitCode).toBe(1)
  })

  it('should return 0 for subdirectory of repo', () => {
    const exitCode = bashExitCode('source ./utils.sh && is_git_repo "./utils"')
    expect(exitCode).toBe(0)
  })

  it('should handle no parameter (use CWD)', () => {
    const exitCode = bashExitCode('source ./utils.sh && is_git_repo')
    expect(exitCode).toBe(0) // Current directory is a git repo
  })
})
```

**Time estimate**: 30 minutes

### 1.2: Implement repo_root() (TDD)

**Current broken code:**
```bash
function repo_root() {
    local -r path="${1}:-${CWD}"
    local repo_root

    if is_git_repo "${path}"; then
        repo_root="$(repo_root "${path}")"  # ← BUG: calls itself!
    else
        repo_root="${path}"
    fi
    # TODO
    return 1
}
```

**Correct implementation approach:**
```bash
function repo_root() {
    local -r path="${1:-${PWD}}"

    if ! is_git_repo "${path}"; then
        debug "repo_root" "${path} is not a git repo"
        return 1
    fi

    # Get the toplevel directory of the git repo
    if [ -d "${path}" ]; then
        ( cd "${path}" && git rev-parse --show-toplevel )
        return $?
    else
        return 1
    fi
}
```

**Tests to write first:**
```typescript
describe('repo_root()', () => {
  it('should return repo root for current directory', () => {
    const result = sourcedBash('./utils.sh', 'repo_root')
    expect(result).toContain('config/sh')
  })

  it('should return repo root for subdirectory', () => {
    const result = sourcedBash('./utils.sh', 'repo_root "./utils"')
    expect(result).toContain('config/sh')
  })

  it('should return error for non-repo', () => {
    const exitCode = bashExitCode('source ./utils.sh && repo_root "/tmp"')
    expect(exitCode).toBe(1)
  })

  it('should return absolute path', () => {
    const result = sourcedBash('./utils.sh', 'repo_root')
    expect(result).toMatch(/^\//)
  })
})
```

**Time estimate**: 30 minutes

### 1.3: Implement repo_is_dirty() (TDD)

**Implementation approach:**
```bash
function repo_is_dirty() {
    local -r path="${1:-${PWD}}"

    if ! is_git_repo "${path}"; then
        debug "repo_is_dirty" "${path} is not a git repo"
        return 1
    fi

    local -r repo_root="$(repo_root "${path}")"

    # Check if there are any changes (staged, unstaged, or untracked)
    if [ -d "${repo_root}" ]; then
        local -r status=$(cd "${repo_root}" && git status --porcelain 2>/dev/null)
        if [ -n "${status}" ]; then
            debug "repo_is_dirty" "repo has uncommitted changes"
            return 0  # Dirty
        else
            debug "repo_is_dirty" "repo is clean"
            return 1  # Clean
        fi
    fi

    return 1
}
```

**Tests to write first:**
```typescript
describe('repo_is_dirty()', () => {
  it('should return 0 when repo has uncommitted changes', () => {
    // Assuming current repo has changes
    const exitCode = bashExitCode('source ./utils.sh && repo_is_dirty')
    // Will depend on actual repo state
  })

  it('should return 1 for non-repo', () => {
    const exitCode = bashExitCode('source ./utils.sh && repo_is_dirty "/tmp"')
    expect(exitCode).toBe(1)
  })

  it('should work with path parameter', () => {
    const exitCode = bashExitCode('source ./utils.sh && repo_is_dirty "."')
    // Exit code depends on repo state: 0 = dirty, 1 = clean or error
  })
})
```

**Time estimate**: 30 minutes

**Phase 1 Deliverables**:
- ✅ is_git_repo() implemented and tested
- ✅ repo_root() implemented and tested
- ✅ repo_is_dirty() implemented and tested
- ✅ All circular dependencies fixed
- ✅ ~9 tests passing

## Phase 2: Implement Repository Analysis Functions

**Objective**: Implement functions that analyze repository structure

### 2.1: Implement has_package_json() (TDD)

**Implementation approach:**
```bash
function has_package_json() {
    local -r path="${1:-${PWD}}"
    local repo_root_dir

    # Check in the specified path first
    if [ -f "${path}/package.json" ]; then
        debug "has_package_json" "found in ${path}"
        return 0
    fi

    # If in a git repo, check repo root
    if is_git_repo "${path}"; then
        repo_root_dir="$(repo_root "${path}")"
        if [ -f "${repo_root_dir}/package.json" ]; then
            debug "has_package_json" "found in repo root: ${repo_root_dir}"
            return 0
        fi
    fi

    debug "has_package_json" "not found"
    return 1
}
```

**Tests**:
```typescript
describe('has_package_json()', () => {
  it('should find package.json in current directory', () => {
    const exitCode = bashExitCode('source ./utils.sh && has_package_json')
    expect(exitCode).toBe(0) // This repo has package.json
  })

  it('should return 1 when no package.json exists', () => {
    const exitCode = bashExitCode('source ./utils.sh && has_package_json "/tmp"')
    expect(exitCode).toBe(1)
  })

  it('should find package.json in repo root from subdirectory', () => {
    const exitCode = bashExitCode('source ./utils.sh && has_package_json "./utils"')
    expect(exitCode).toBe(0)
  })
})
```

**Time estimate**: 20 minutes

### 2.2: Implement has_typescript_files() (TDD)

**Implementation approach:**
```bash
function has_typescript_files() {
    local -r path="${1:-${PWD}}"
    local repo_root_dir
    local -a search_paths=()

    # Build list of paths to search
    search_paths+=("${path}")

    if is_git_repo "${path}"; then
        repo_root_dir="$(repo_root "${path}")"
        search_paths+=("${repo_root_dir}")

        # Common TypeScript locations
        [ -d "${repo_root_dir}/src" ] && search_paths+=("${repo_root_dir}/src")
        [ -d "${repo_root_dir}/tests" ] && search_paths+=("${repo_root_dir}/tests")
    fi

    # Search for .ts files (excluding node_modules)
    for search_path in "${search_paths[@]}"; do
        if [ -d "${search_path}" ]; then
            # Use find to look for .ts files
            local -r ts_files=$(find "${search_path}" -maxdepth 3 -name "*.ts" -not -path "*/node_modules/*" 2>/dev/null | head -1)
            if [ -n "${ts_files}" ]; then
                debug "has_typescript_files" "found TypeScript files in ${search_path}"
                return 0
            fi
        fi
    done

    debug "has_typescript_files" "no TypeScript files found"
    return 1
}
```

**Tests**:
```typescript
describe('has_typescript_files()', () => {
  it('should find TypeScript files in current directory', () => {
    const exitCode = bashExitCode('source ./utils.sh && has_typescript_files')
    expect(exitCode).toBe(0) // This repo has .ts files
  })

  it('should return 1 when no TypeScript files exist', () => {
    const exitCode = bashExitCode('source ./utils.sh && has_typescript_files "/tmp"')
    expect(exitCode).toBe(1)
  })

  it('should find TypeScript files in src directory', () => {
    const exitCode = bashExitCode('source ./utils.sh && has_typescript_files "."')
    expect(exitCode).toBe(0)
  })
})
```

**Time estimate**: 25 minutes

### 2.3: Implement is_monorepo() (TDD)

**Implementation approach:**
```bash
function is_monorepo() {
    local -r path="${1:-${PWD}}"

    if ! is_git_repo "${path}"; then
        debug "is_monorepo" "${path} is not a git repo"
        return 1
    fi

    local -r repo_root_dir="$(repo_root "${path}")"

    # Check for common monorepo indicators
    local -a monorepo_files=(
        "pnpm-workspace.yaml"
        "lerna.json"
        "nx.json"
        "turbo.json"
        "rush.json"
    )

    for file in "${monorepo_files[@]}"; do
        if [ -f "${repo_root_dir}/${file}" ]; then
            debug "is_monorepo" "found ${file} - is a monorepo"
            return 0
        fi
    done

    # Check for workspaces in package.json
    if [ -f "${repo_root_dir}/package.json" ]; then
        if grep -q "\"workspaces\":" "${repo_root_dir}/package.json" 2>/dev/null; then
            debug "is_monorepo" "found workspaces in package.json - is a monorepo"
            return 0
        fi
    fi

    # Check for multiple package.json files (common pattern)
    local -r pkg_count=$(find "${repo_root_dir}" -maxdepth 3 -name "package.json" 2>/dev/null | wc -l)
    if [ "${pkg_count}" -gt 1 ]; then
        debug "is_monorepo" "found ${pkg_count} package.json files - likely a monorepo"
        return 0
    fi

    debug "is_monorepo" "no monorepo indicators found"
    return 1
}
```

**Tests**:
```typescript
describe('is_monorepo()', () => {
  it('should return 1 for non-monorepo', () => {
    const exitCode = bashExitCode('source ./utils.sh && is_monorepo')
    expect(exitCode).toBe(1) // This repo is not a monorepo
  })

  it('should return 1 for non-git directory', () => {
    const exitCode = bashExitCode('source ./utils.sh && is_monorepo "/tmp"')
    expect(exitCode).toBe(1)
  })

  it('should detect pnpm-workspace.yaml', () => {
    // Would need test fixture with pnpm-workspace.yaml
    // Test with temporary directory setup
  })
})
```

**Time estimate**: 30 minutes

**Phase 2 Deliverables**:
- ✅ has_package_json() implemented and tested
- ✅ has_typescript_files() implemented and tested
- ✅ is_monorepo() implemented and tested
- ✅ ~9 additional tests passing

## Phase 3: Implement Project Type Detection Functions

**Objective**: Implement project type detection functions

### 3.1: Implement looks_like_js_project() (TDD)

**Implementation approach:**
```bash
function looks_like_js_project() {
    local -r path="${1:-${PWD}}"

    # Strong indicators
    [ -f "${path}/package.json" ] && return 0
    [ -d "${path}/node_modules" ] && return 0

    # Check for JS/TS files
    local -r js_files=$(find "${path}" -maxdepth 2 \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) -not -path "*/node_modules/*" 2>/dev/null | head -1)
    [ -n "${js_files}" ] && return 0

    # Check for common JS config files
    local -a js_config_files=(
        "tsconfig.json"
        "jsconfig.json"
        ".eslintrc.js"
        ".eslintrc.json"
        "webpack.config.js"
        "vite.config.js"
        "vite.config.ts"
    )

    for file in "${js_config_files[@]}"; do
        [ -f "${path}/${file}" ] && return 0
    done

    debug "looks_like_js_project" "no JavaScript project indicators found"
    return 1
}
```

**Tests**:
```typescript
describe('looks_like_js_project()', () => {
  it('should detect JS project from package.json', () => {
    const exitCode = bashExitCode('source ./utils.sh && looks_like_js_project')
    expect(exitCode).toBe(0)
  })

  it('should return 1 for non-JS directory', () => {
    const exitCode = bashExitCode('source ./utils.sh && looks_like_js_project "/tmp"')
    expect(exitCode).toBe(1)
  })

  it('should detect from tsconfig.json', () => {
    const exitCode = bashExitCode('source ./utils.sh && looks_like_js_project "."')
    expect(exitCode).toBe(0)
  })
})
```

**Time estimate**: 20 minutes

### 3.2: Implement looks_like_rust_project() (TDD)

**Implementation approach:**
```bash
function looks_like_rust_project() {
    local -r path="${1:-${PWD}}"

    # Strong indicator - Cargo.toml
    [ -f "${path}/Cargo.toml" ] && return 0

    # Check for Cargo.lock
    [ -f "${path}/Cargo.lock" ] && return 0

    # Check for src/main.rs or src/lib.rs (standard Rust structure)
    [ -f "${path}/src/main.rs" ] && return 0
    [ -f "${path}/src/lib.rs" ] && return 0

    # Check for .rs files
    local -r rs_files=$(find "${path}" -maxdepth 2 -name "*.rs" 2>/dev/null | head -1)
    [ -n "${rs_files}" ] && return 0

    debug "looks_like_rust_project" "no Rust project indicators found"
    return 1
}
```

**Tests**:
```typescript
describe('looks_like_rust_project()', () => {
  it('should return 1 for non-Rust project', () => {
    const exitCode = bashExitCode('source ./utils.sh && looks_like_rust_project')
    expect(exitCode).toBe(1)
  })

  it('should return 1 for empty directory', () => {
    const exitCode = bashExitCode('source ./utils.sh && looks_like_rust_project "/tmp"')
    expect(exitCode).toBe(1)
  })
})
```

**Time estimate**: 15 minutes

### 3.3: Implement looks_like_python_project() (TDD)

**Implementation approach:**
```bash
function looks_like_python_project() {
    local -r path="${1:-${PWD}}"

    # Strong indicators - Python project files
    local -a python_files=(
        "setup.py"
        "pyproject.toml"
        "requirements.txt"
        "Pipfile"
        "poetry.lock"
        "setup.cfg"
    )

    for file in "${python_files[@]}"; do
        [ -f "${path}/${file}" ] && return 0
    done

    # Check for __init__.py or .py files
    [ -f "${path}/__init__.py" ] && return 0

    local -r py_files=$(find "${path}" -maxdepth 2 -name "*.py" 2>/dev/null | head -1)
    [ -n "${py_files}" ] && return 0

    debug "looks_like_python_project" "no Python project indicators found"
    return 1
}
```

**Tests**:
```typescript
describe('looks_like_python_project()', () => {
  it('should return 1 for non-Python project', () => {
    const exitCode = bashExitCode('source ./utils.sh && looks_like_python_project')
    expect(exitCode).toBe(1)
  })

  it('should return 1 for empty directory', () => {
    const exitCode = bashExitCode('source ./utils.sh && looks_like_python_project "/tmp"')
    expect(exitCode).toBe(1)
  })
})
```

**Time estimate**: 15 minutes

**Phase 3 Deliverables**:
- ✅ looks_like_js_project() implemented and tested
- ✅ looks_like_rust_project() implemented and tested
- ✅ looks_like_python_project() implemented and tested
- ✅ ~9 additional tests passing

## Phase 4: Integration Testing & Documentation

**Objective**: Ensure all functions work together and document usage

### Tasks:

1. **Create integration tests** (30 min)
   - Test functions working together
   - Test edge cases
   - Test error handling
   - Example: `is_git_repo && repo_root && has_package_json`

2. **Test with real-world scenarios** (20 min)
   - Test on actual projects
   - Test on this repo
   - Test on /tmp (non-repo)
   - Document behavior

3. **Update documentation** (20 min)
   - Update function docstrings
   - Add usage examples
   - Document gotchas
   - Update CLAUDE.md if needed

4. **Move tests to production** (10 min)
   - Move from WIP to tests/
   - Run full test suite
   - Verify all 148+ tests passing

**Deliverables**:
- ✅ Integration tests
- ✅ Documentation updated
- ✅ All tests passing (~27 new tests)
- ✅ Detection functions production-ready

## Success Criteria

- ✅ All 9 TODO functions implemented
- ✅ All circular dependencies fixed
- ✅ ~27 new tests created and passing
- ✅ 100% test pass rate maintained
- ✅ Functions work with real git repos
- ✅ Proper error handling for edge cases
- ✅ Documentation complete

## Timeline

- Phase 0: ~30 minutes (setup)
- Phase 1: ~90 minutes (core git functions)
- Phase 2: ~75 minutes (repository analysis)
- Phase 3: ~50 minutes (project detection)
- Phase 4: ~80 minutes (integration & docs)

**Total Estimated Time**: ~5.5 hours

## Technical Considerations

### Git Command Patterns

```bash
# Check if directory is in a git repo
git rev-parse --git-dir >/dev/null 2>&1

# Get repo root
git rev-parse --show-toplevel

# Check if repo is dirty
git status --porcelain

# Get current branch
git branch --show-current
```

### File Detection Patterns

```bash
# Find files with depth limit
find "${path}" -maxdepth 2 -name "*.ts"

# Exclude directories
find "${path}" -name "*.js" -not -path "*/node_modules/*"

# Check if file exists
[ -f "${path}/file.txt" ]

# Check if directory exists
[ -d "${path}/dir" ]
```

### Error Handling

```bash
# Always check if path is valid
[ -d "${path}" ] || return 1

# Use subshells for directory changes
( cd "${path}" && git status )

# Suppress errors when appropriate
git status 2>/dev/null

# Use debug for visibility
debug "function_name" "message"
```

## Risk Mitigation

**Risk**: Breaking existing code that depends on these functions
**Mitigation**: Functions currently just return 1, so any code using them already handles failure

**Risk**: Git commands failing in CI/CD
**Mitigation**: Always check if path is git repo first, handle errors gracefully

**Risk**: Performance issues with find commands
**Mitigation**: Use maxdepth limits, use head -1 to stop after first match

**Risk**: Tests depending on git state
**Mitigation**: Create isolated test fixtures, document test assumptions

## Notes

- All functions should default to ${PWD} if no path provided
- Use debug() for helpful output
- Return 0 for success/true, 1 for failure/false
- Handle missing directories gracefully
- Test with both relative and absolute paths
- Consider subshell usage to avoid changing CWD
