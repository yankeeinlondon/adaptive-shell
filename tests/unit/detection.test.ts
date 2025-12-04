import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { mkdirSync, rmSync, existsSync, writeFileSync, chmodSync } from 'fs'
import { join } from 'path'
import { execSync } from 'child_process'
import { sourceScript, bashExitCode, runInShell, runInBothShells, isShellAvailable } from "../helpers"

/** Project root for absolute path references */
const PROJECT_ROOT = process.cwd()

/**
 * Helper to initialize a git repo in a directory for testing
 */
function initGitRepo(dir: string): void {
  execSync('git init', { cwd: dir, stdio: 'pipe' })
  execSync('git config user.email "test@test.com"', { cwd: dir, stdio: 'pipe' })
  execSync('git config user.name "Test User"', { cwd: dir, stdio: 'pipe' })
}

/**
 * Helper to create and commit a file in a git repo
 */
function commitFile(dir: string, filename: string, content: string, message: string): void {
  writeFileSync(join(dir, filename), content)
  execSync(`git add "${filename}"`, { cwd: dir, stdio: 'pipe' })
  execSync(`git commit -m "${message}"`, { cwd: dir, stdio: 'pipe' })
}

/**
 * Helper to run shell script in a test directory while sourcing scripts from project root
 */
function runInTestDir(shell: 'bash' | 'zsh', testDir: string, script: string) {
  return runInShell(shell, `
    export ADAPTIVE_SHELL="${PROJECT_ROOT}"
    source "${PROJECT_ROOT}/utils/detection.sh"
    ${script}
  `, { cwd: testDir })
}

describe('detection utilities', () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-detection-test')

  beforeAll(() => {
    // Clean up from previous runs and create test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
    mkdirSync(testDir, { recursive: true })
  })

  afterAll(() => {
    // Clean up test directory once at the end
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
  })

  describe('get_shell()', () => {
    it('should return a shell name', () => {
      const api = sourceScript('./utils/detection.sh')('get_shell')()
      expect(api.result.stdout).toBeTruthy()
      expect(api.result.stdout.length).toBeGreaterThan(0)
    })

    it('should return bash when running in bash', () => {
      const api = sourceScript('./utils/detection.sh')('get_shell')()
      // Since we're executing via bash, it should detect bash
      expect(['bash', 'sh']).toContain(api.result.stdout)
    })

    it('should not return a path, only the shell name', () => {
      const api = sourceScript('./utils/detection.sh')('get_shell')()
      expect(api.result.stdout).not.toContain('/')
    })
  })

  describe('is_bash()', () => {
    it('should return 0 when running in bash', () => {
      // Our tests run in bash via sourceScript helper
      const api = sourceScript('./utils/detection.sh')('is_bash')()
      expect(api).toBeSuccessful()
    })
  })

  describe('is_zsh()', () => {
    it('should return 1 when not running in zsh', () => {
      // Our tests run in bash, not zsh
      const api = sourceScript('./utils/detection.sh')('is_zsh')()
      expect(api).toFail()
    })
  })

  describe('is_fish()', () => {
    it('should return 1 when not running in fish', () => {
      // Our tests run in bash, not fish
      const api = sourceScript('./utils/detection.sh')('is_fish')()
      expect(api).toFail()
    })
  })

  describe('is_nushell()', () => {
    it('should return 1 when not running in nushell', () => {
      const api = sourceScript('./utils/detection.sh')('is_nushell')()
      expect(api).toFail()
    })
  })

  describe('is_xonsh()', () => {
    it('should return 1 when not running in xonsh', () => {
      const api = sourceScript('./utils/detection.sh')('is_xonsh')()
      expect(api).toFail()
    })
  })

  describe('is_docker()', () => {
    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/detection.sh')('is_docker')()
      // Should return either 0 (is docker) or 1 (not docker), not an error
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_lxc()', () => {
    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/detection.sh')('is_lxc')()
      // Should return either 0 (is lxc) or 1 (not lxc), not an error
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_vm()', () => {
    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/detection.sh')('is_vm')()
      // Should return either 0 (is vm) or 1 (not vm), not an error
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_pve_host()', () => {
    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/detection.sh')('is_pve_host')()
      // Should return either 0 (has pveversion) or 1 (does not have pveversion)
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('bash_version()', () => {
    it('should return a version string', () => {
      const api = sourceScript('./utils/detection.sh')('bash_version')()
      expect(api.result.stdout).toBeTruthy()
      expect(api.result.stdout.length).toBeGreaterThan(0)
    })

    it('should return a version that starts with a number', () => {
      const api = sourceScript('./utils/detection.sh')('bash_version')()
      expect(api.result.stdout).toMatch(/^\d/)
    })

    it('should contain version number parts', () => {
      const api = sourceScript('./utils/detection.sh')('bash_version')()
      // Version should be like "5.1.16" or "3.2.57"
      expect(api.result.stdout).toMatch(/\d+\.\d+/)
    })
  })

  describe('using_bash_3()', () => {
    it('should return 0 or 1 based on bash version', () => {
      const api = sourceScript('./utils/detection.sh')('using_bash_3')()
      // Should return either 0 (is bash 3) or 1 (not bash 3)
      expect([0, 1]).toContain(api.result.code)
    })

    it('should be consistent with bash_version()', () => {
      const versionApi = sourceScript('./utils/detection.sh')('bash_version')()
      const usingBash3Api = sourceScript('./utils/detection.sh')('using_bash_3')()

      if (versionApi.result.stdout.startsWith('3')) {
        expect(usingBash3Api).toBeSuccessful()
      } else {
        expect(usingBash3Api).toFail()
      }
    })
  })

  describe('has_command()', () => {
    it('should return 0 for common commands that exist', () => {
      const api = sourceScript('./utils/detection.sh')('has_command')('ls')
      expect(api).toBeSuccessful()
    })

    it('should return 0 for bash command', () => {
      const api = sourceScript('./utils/detection.sh')('has_command')('bash')
      expect(api).toBeSuccessful()
    })

    it('should return 1 for commands that do not exist', () => {
      const api = sourceScript('./utils/detection.sh')('has_command')('nonexistent-command-12345')
      expect(api).toFail()
    })

    it('should error when no command provided', () => {
      const api = sourceScript('./utils/detection.sh')('has_command')()
      expect(api).toFail()
    })

    it('should handle commands with special characters', () => {
      // Test with a command that definitely doesn't exist
      const api = sourceScript('./utils/detection.sh')('has_command')('fake@command')
      expect(api).toFail()
    })

    it('should return 0 for shell builtins like cd', () => {
      const api = sourceScript('./utils/detection.sh')('has_command')('cd')
      expect(api).toBeSuccessful()
    })

    it('should return 0 for shell builtins like echo', () => {
      const api = sourceScript('./utils/detection.sh')('has_command')('echo')
      expect(api).toBeSuccessful()
    })

    it('should return FALSE for shell functions (wrapper function pattern)', () => {
      // This is the key test: has_command should NOT find shell functions
      // This enables the wrapper function pattern where we define a function
      // to prompt for installation, but has_command still returns false
      const exitCode = bashExitCode(`
        source ./utils/detection.sh
        function fake_cargo() { echo "wrapper"; }
        has_command fake_cargo
      `)
      expect(exitCode).toBe(1) // Should NOT find the function
    })

    it('should still find real commands even when wrapper function exists', () => {
      // Even if a function with the same name exists, it should find the real binary
      const exitCode = bashExitCode(`
        source ./utils/detection.sh
        function ls() { echo "wrapper"; }
        has_command ls
      `)
      expect(exitCode).toBe(0) // Should find the real ls binary
    })
  })

  describe('has_function()', () => {
    it('should return 0 for defined shell functions', () => {
      const exitCode = bashExitCode(`
        source ./utils/detection.sh
        function my_test_fn() { echo "test"; }
        has_function my_test_fn
      `)
      expect(exitCode).toBe(0)
    })

    it('should return 1 for commands that are executables, not functions', () => {
      const api = sourceScript('./utils/detection.sh')('has_function')('ls')
      expect(api).toFail()
    })

    it('should return 1 for shell builtins', () => {
      const api = sourceScript('./utils/detection.sh')('has_function')('cd')
      expect(api).toFail()
    })

    it('should return 1 for non-existent functions', () => {
      const api = sourceScript('./utils/detection.sh')('has_function')('nonexistent_fn_12345')
      expect(api).toFail()
    })

    it('should error when no function name provided', () => {
      const api = sourceScript('./utils/detection.sh')('has_function')()
      expect(api).toFail()
    })

    it('should detect functions defined by sourced scripts', () => {
      // has_command itself is a function defined in detection.sh
      const exitCode = bashExitCode(`
        source ./utils/detection.sh
        has_function has_command
      `)
      expect(exitCode).toBe(0)
    })
  })

  describe('has_command() - cross-shell compatibility', () => {
    const zshAvailable = isShellAvailable('zsh')

    it('should find executables in both bash and zsh', () => {
      const { bash, zsh } = runInBothShells(`
        source ./utils/detection.sh
        has_command ls
      `)
      expect(bash.code).toBe(0)
      if (zshAvailable) {
        expect(zsh.code).toBe(0)
      }
    })

    it('should find builtins (cd) in both bash and zsh', () => {
      const { bash, zsh } = runInBothShells(`
        source ./utils/detection.sh
        has_command cd
      `)
      expect(bash.code).toBe(0)
      if (zshAvailable) {
        expect(zsh.code).toBe(0)
      }
    })

    it('should NOT find shell functions in both bash and zsh', () => {
      const { bash, zsh } = runInBothShells(`
        source ./utils/detection.sh
        function fake_cmd() { echo "wrapper"; }
        has_command fake_cmd
      `)
      expect(bash.code).toBe(1) // Should NOT find the function
      if (zshAvailable) {
        expect(zsh.code).toBe(1) // Should also NOT find the function in zsh
      }
    })

    it('should find real command even when shadowed by function in both shells', () => {
      const { bash, zsh } = runInBothShells(`
        source ./utils/detection.sh
        function ls() { echo "shadowed"; }
        has_command ls
      `)
      expect(bash.code).toBe(0) // Should still find real ls
      if (zshAvailable) {
        expect(zsh.code).toBe(0) // Should also find real ls in zsh
      }
    })

    it('should return false for non-existent commands in both shells', () => {
      const { bash, zsh } = runInBothShells(`
        source ./utils/detection.sh
        has_command nonexistent_cmd_xyz_123
      `)
      expect(bash.code).toBe(1)
      if (zshAvailable) {
        expect(zsh.code).toBe(1)
      }
    })

    // This test specifically checks the uv scenario
    it('should find uv when PATH includes ~/.local/bin (zsh specific)', function() {
      if (!zshAvailable) {
        return
      }

      // Test with PATH that includes ~/.local/bin
      const result = runInShell('zsh', `
        export PATH="$HOME/.local/bin:$PATH"
        source ./utils/detection.sh
        has_command uv && echo "FOUND" || echo "NOT_FOUND"
      `)

      // If uv is installed in ~/.local/bin, this should find it
      if (existsSync(join(process.env.HOME || '', '.local/bin/uv'))) {
        expect(result.code).toBe(0)
        expect(result.stdout).toContain('FOUND')
      }
    })

    // Simulate full adaptive.sh initialization to catch ordering issues
    it('should NOT create wrapper when uv IS installed (full init simulation)', function() {
      if (!zshAvailable) {
        return
      }

      // Only run if uv is actually installed
      if (!existsSync(join(process.env.HOME || '', '.local/bin/uv'))) {
        return
      }

      const result = runInShell('zsh', `
        # Ensure PATH includes ~/.local/bin BEFORE sourcing
        export PATH="$HOME/.local/bin:$PATH"

        # Source the full adaptive.sh
        source ./adaptive.sh 2>/dev/null

        # Check if uv is a function (bad) or command (good)
        if [[ "$(whence -w uv 2>/dev/null)" == *": function" ]]; then
          echo "FAIL: uv is a wrapper function"
          exit 1
        else
          echo "PASS: uv is a real command"
          exit 0
        fi
      `)

      expect(result.code).toBe(0)
      expect(result.stdout).toContain('PASS')
    })

    // Test what happens when PATH does NOT include ~/.local/bin initially
    it('should create wrapper when PATH excludes ~/.local/bin (expected behavior)', function() {
      if (!zshAvailable) {
        return
      }

      const result = runInShell('zsh', `
        # Start with minimal PATH that excludes ~/.local/bin
        export PATH="/usr/bin:/bin"

        # Source only detection.sh and user-functions.sh
        source ./utils/detection.sh
        source ./user-functions.sh 2>/dev/null

        # Check if uv wrapper was created
        if [[ "$(whence -w uv 2>/dev/null)" == *": function" ]]; then
          echo "EXPECTED: uv wrapper function created (PATH missing ~/.local/bin)"
          exit 0
        else
          echo "UNEXPECTED: uv is not a function"
          exit 1
        fi
      `)

      // When PATH doesn't include the binary location, wrapper SHOULD be created
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('EXPECTED')
    })

    // Regression test: zsh 'path' is tied to 'PATH' - using 'local path' empties PATH!
    it('should not empty PATH when append_to_path runs (zsh path/PATH regression)', function() {
      if (!zshAvailable) {
        return
      }

      const result = runInShell('zsh', `
        export PATH="/usr/bin:/bin:/test/initial"

        cd /Users/ken/config/sh
        source ./utils/logging.sh
        source ./utils.sh
        source ./reports/paths.sh

        # PATH before
        local before="$PATH"

        # Call append_to_path
        append_to_path

        # PATH should still contain the original paths
        if [[ "$PATH" == *"/test/initial"* ]]; then
          echo "PASS: PATH preserved after append_to_path"
          exit 0
        else
          echo "FAIL: PATH was corrupted (zsh path/PATH tie bug)"
          echo "Before: $before"
          echo "After: $PATH"
          exit 1
        fi
      `)

      expect(result.code).toBe(0)
      expect(result.stdout).toContain('PASS')
    })
  })

  describe('has_function() - cross-shell compatibility', () => {
    const zshAvailable = isShellAvailable('zsh')

    it('should find shell functions in both bash and zsh', () => {
      const { bash, zsh } = runInBothShells(`
        source ./utils/detection.sh
        function my_test_fn() { echo "test"; }
        has_function my_test_fn
      `)
      expect(bash.code).toBe(0)
      if (zshAvailable) {
        expect(zsh.code).toBe(0)
      }
    })

    it('should NOT find executables in both bash and zsh', () => {
      const { bash, zsh } = runInBothShells(`
        source ./utils/detection.sh
        has_function ls
      `)
      expect(bash.code).toBe(1)
      if (zshAvailable) {
        expect(zsh.code).toBe(1)
      }
    })

    it('should NOT find builtins in both bash and zsh', () => {
      const { bash, zsh } = runInBothShells(`
        source ./utils/detection.sh
        has_function cd
      `)
      expect(bash.code).toBe(1)
      if (zshAvailable) {
        expect(zsh.code).toBe(1)
      }
    })
  })

  describe('is_keyword()', () => {
    it('should return 0 for bash keywords', () => {
      const api = sourceScript('./utils/detection.sh')('is_keyword')('if')
      expect(api).toBeSuccessful()
    })

    it('should return 0 for function keyword', () => {
      const api = sourceScript('./utils/detection.sh')('is_keyword')('function')
      expect(api).toBeSuccessful()
    })

    it('should return 1 for non-keywords', () => {
      const api = sourceScript('./utils/detection.sh')('is_keyword')('notakeyword')
      expect(api).toFail()
    })

    it('should error when no parameter provided', () => {
      const api = sourceScript('./utils/detection.sh')('is_keyword')()
      expect(api).toFail()
    })
  })

  describe('in_package_json()', () => {
    it('should return 0 when string exists in package.json', () => {
      const projectDir = join(testDir, 'pkg-json-search')
      mkdirSync(projectDir, { recursive: true })
      writeFileSync(join(projectDir, 'package.json'), JSON.stringify({
        name: 'test-project',
        dependencies: { 'some-dep': '^1.0.0' }
      }))

      const result = runInTestDir('bash', projectDir, `in_package_json 'some-dep'`)
      expect(result.code).toBe(0)
    })

    it('should return 1 when string does not exist in package.json', () => {
      const projectDir = join(testDir, 'pkg-json-no-match')
      mkdirSync(projectDir, { recursive: true })
      writeFileSync(join(projectDir, 'package.json'), JSON.stringify({
        name: 'test-project',
        dependencies: { 'some-dep': '^1.0.0' }
      }))

      const result = runInTestDir('bash', projectDir, `in_package_json 'nonexistent-string-12345'`)
      expect(result.code).toBe(1)
    })

    it('should error when no string provided', () => {
      const projectDir = join(testDir, 'pkg-json-no-arg')
      mkdirSync(projectDir, { recursive: true })
      writeFileSync(join(projectDir, 'package.json'), '{"name": "test"}')

      const result = runInTestDir('bash', projectDir, `in_package_json`)
      expect(result.code).not.toBe(0)
    })

    it('should return 1 when no package.json exists', () => {
      const emptyDir = join(testDir, 'no-pkg-json')
      mkdirSync(emptyDir, { recursive: true })

      const result = runInTestDir('bash', emptyDir, `in_package_json 'anything'`)
      expect(result.code).not.toBe(0)
    })
  })

  describe('is_git_repo()', () => {
    // Use /tmp for non-git tests to ensure we're outside any git repo
    const tmpNonGitDir = `/tmp/detection-test-${Date.now()}`
    // Lazy init: create git repo once, reuse for multiple tests
    let cachedGitDir: string | null = null
    let cachedGitSubdir: string | null = null

    function getOrCreateGitRepo() {
      if (!cachedGitDir) {
        cachedGitDir = join(testDir, 'cached-git-repo')
        const subDir = join(cachedGitDir, 'src', 'components')
        mkdirSync(subDir, { recursive: true })
        initGitRepo(cachedGitDir)
        cachedGitSubdir = subDir
      }
      return { gitDir: cachedGitDir, subDir: cachedGitSubdir! }
    }

    afterEach(() => {
      if (existsSync(tmpNonGitDir)) {
        rmSync(tmpNonGitDir, { recursive: true, force: true })
      }
    })

    it('should return 0 for initialized git directory', () => {
      const { gitDir } = getOrCreateGitRepo()
      const api = sourceScript('./utils/detection.sh')('is_git_repo')(gitDir)
      expect(api).toBeSuccessful()
    })

    it('should return 0 for subdirectory of git repo', () => {
      const { subDir } = getOrCreateGitRepo()
      const api = sourceScript('./utils/detection.sh')('is_git_repo')(subDir)
      expect(api).toBeSuccessful()
    })

    it('should return 1 for non-git directory', () => {
      // Use /tmp to ensure we're outside any git repo
      mkdirSync(tmpNonGitDir, { recursive: true })

      const api = sourceScript('./utils/detection.sh')('is_git_repo')(tmpNonGitDir)
      expect(api).toFail()
    })

    it('should handle non-existent paths gracefully', () => {
      const api = sourceScript('./utils/detection.sh')('is_git_repo')('/nonexistent/path/12345')
      expect(api).toFail()
    })
  })

  describe('repo_root()', () => {
    // Use /tmp for non-git tests to ensure we're outside any git repo
    const tmpNonGitDir = `/tmp/repo-root-test-${Date.now()}`
    let cachedRepoRoot: string | null = null
    let cachedRepoSubdir: string | null = null

    function getOrCreateRepoRoot() {
      if (!cachedRepoRoot) {
        cachedRepoRoot = join(testDir, 'cached-repo-root')
        cachedRepoSubdir = join(cachedRepoRoot, 'src', 'utils')
        mkdirSync(cachedRepoSubdir, { recursive: true })
        initGitRepo(cachedRepoRoot)
      }
      return { gitDir: cachedRepoRoot, subDir: cachedRepoSubdir! }
    }

    afterEach(() => {
      if (existsSync(tmpNonGitDir)) {
        rmSync(tmpNonGitDir, { recursive: true, force: true })
      }
    })

    it('should output the repo root path for git directory', () => {
      const { gitDir } = getOrCreateRepoRoot()
      const api = sourceScript('./utils/detection.sh')('repo_root')(gitDir)
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toBe(gitDir)
    })

    it('should output the repo root when called from subdirectory', () => {
      const { gitDir, subDir } = getOrCreateRepoRoot()
      const api = sourceScript('./utils/detection.sh')('repo_root')(subDir)
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toBe(gitDir)
    })

    it('should output an absolute path', () => {
      const { gitDir } = getOrCreateRepoRoot()
      const api = sourceScript('./utils/detection.sh')('repo_root')(gitDir)
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toBeTruthy()
      expect(api.result.stdout).toContain('/')
    })

    it('should return error for non-git directory', () => {
      // Use /tmp to ensure we're outside any git repo
      mkdirSync(tmpNonGitDir, { recursive: true })

      const api = sourceScript('./utils/detection.sh')('repo_root')(tmpNonGitDir)
      expect(api).toFail()
    })

    it('should handle non-existent paths gracefully', () => {
      const api = sourceScript('./utils/detection.sh')('repo_root')('/nonexistent/path/12345')
      expect(api).toFail()
    })
  })

  describe('repo_is_dirty()', () => {
    const gitTestDir = join(testDir, 'git-dirty-test')

    beforeEach(() => {
      // Clean up from previous test in this describe block
      if (existsSync(gitTestDir)) {
        rmSync(gitTestDir, { recursive: true, force: true })
      }
      mkdirSync(gitTestDir, { recursive: true })
      initGitRepo(gitTestDir)
    })

    it('should return 0 (dirty) when repo has uncommitted changes', () => {
      // Create initial commit, then modify the file
      commitFile(gitTestDir, 'file.txt', 'initial content', 'initial commit')
      writeFileSync(join(gitTestDir, 'file.txt'), 'modified content')

      const api = sourceScript('./utils/detection.sh')('repo_is_dirty')(gitTestDir)
      expect(api).toBeSuccessful()
    })

    it('should return 1 (clean) when repo has no uncommitted changes', () => {
      // Create a commit and leave the repo clean
      commitFile(gitTestDir, 'file.txt', 'content', 'initial commit')

      const api = sourceScript('./utils/detection.sh')('repo_is_dirty')(gitTestDir)
      expect(api).toFail()
    })

    it('should return 0 (dirty) for staged but uncommitted changes', () => {
      commitFile(gitTestDir, 'file.txt', 'initial', 'initial commit')
      writeFileSync(join(gitTestDir, 'new-file.txt'), 'new content')
      execSync('git add new-file.txt', { cwd: gitTestDir, stdio: 'pipe' })

      const api = sourceScript('./utils/detection.sh')('repo_is_dirty')(gitTestDir)
      expect(api).toBeSuccessful()
    })

    it('should return 0 (dirty) for untracked files', () => {
      commitFile(gitTestDir, 'file.txt', 'initial', 'initial commit')
      writeFileSync(join(gitTestDir, 'untracked.txt'), 'untracked content')

      const api = sourceScript('./utils/detection.sh')('repo_is_dirty')(gitTestDir)
      expect(api).toBeSuccessful()
    })

    it('should work when called from subdirectory', () => {
      commitFile(gitTestDir, 'file.txt', 'initial', 'initial commit')
      const subDir = join(gitTestDir, 'subdir')
      mkdirSync(subDir, { recursive: true })
      writeFileSync(join(gitTestDir, 'modified.txt'), 'dirty')

      const api = sourceScript('./utils/detection.sh')('repo_is_dirty')(subDir)
      expect(api).toBeSuccessful()
    })

    it('should return error for non-git directory', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpNonGitDir = `/tmp/dirty-test-nongit-${Date.now()}`
      mkdirSync(tmpNonGitDir, { recursive: true })

      try {
        const api = sourceScript('./utils/detection.sh')('repo_is_dirty')(tmpNonGitDir)
        expect(api).toFail()
      } finally {
        rmSync(tmpNonGitDir, { recursive: true, force: true })
      }
    })

    it('should handle non-existent paths gracefully', () => {
      const api = sourceScript('./utils/detection.sh')('repo_is_dirty')('/nonexistent/path/12345')
      expect(api).toFail()
    })
  })

  describe('is_monorepo()', () => {
    let cachedPnpmMono: string | null = null
    let cachedLernaMono: string | null = null
    let cachedNpmWorkspace: string | null = null
    let cachedRegularRepo: string | null = null

    it('should return 0 when pnpm-workspace.yaml exists', () => {
      if (!cachedPnpmMono) {
        cachedPnpmMono = join(testDir, 'cached-pnpm-mono')
        const subDir = join(cachedPnpmMono, 'packages', 'pkg-a')
        mkdirSync(subDir, { recursive: true })
        initGitRepo(cachedPnpmMono)
        writeFileSync(join(cachedPnpmMono, 'pnpm-workspace.yaml'), 'packages:\n  - "packages/*"')
      }
      const api = sourceScript('./utils/detection.sh')('is_monorepo')(cachedPnpmMono)
      expect(api).toBeSuccessful()
    })

    it('should return 0 when lerna.json exists', () => {
      if (!cachedLernaMono) {
        cachedLernaMono = join(testDir, 'cached-lerna-mono')
        mkdirSync(cachedLernaMono, { recursive: true })
        initGitRepo(cachedLernaMono)
        writeFileSync(join(cachedLernaMono, 'lerna.json'), '{"version": "1.0.0"}')
      }
      const api = sourceScript('./utils/detection.sh')('is_monorepo')(cachedLernaMono)
      expect(api).toBeSuccessful()
    })

    it('should return 0 when package.json has workspaces field', () => {
      if (!cachedNpmWorkspace) {
        cachedNpmWorkspace = join(testDir, 'cached-npm-workspace')
        mkdirSync(cachedNpmWorkspace, { recursive: true })
        initGitRepo(cachedNpmWorkspace)
        writeFileSync(join(cachedNpmWorkspace, 'package.json'), '{"name": "test", "workspaces": ["packages/*"]}')
      }
      const api = sourceScript('./utils/detection.sh')('is_monorepo')(cachedNpmWorkspace)
      expect(api).toBeSuccessful()
    })

    it('should work from subdirectory of monorepo', () => {
      if (!cachedPnpmMono) {
        cachedPnpmMono = join(testDir, 'cached-pnpm-mono')
        const subDir = join(cachedPnpmMono, 'packages', 'pkg-a')
        mkdirSync(subDir, { recursive: true })
        initGitRepo(cachedPnpmMono)
        writeFileSync(join(cachedPnpmMono, 'pnpm-workspace.yaml'), 'packages:\n  - "packages/*"')
      }
      const subDir = join(cachedPnpmMono, 'packages', 'pkg-a')
      const api = sourceScript('./utils/detection.sh')('is_monorepo')(subDir)
      expect(api).toBeSuccessful()
    })

    it('should return 1 for regular repo without workspace config', () => {
      if (!cachedRegularRepo) {
        cachedRegularRepo = join(testDir, 'cached-regular-repo')
        mkdirSync(cachedRegularRepo, { recursive: true })
        initGitRepo(cachedRegularRepo)
        writeFileSync(join(cachedRegularRepo, 'package.json'), '{"name": "test"}')
      }
      const api = sourceScript('./utils/detection.sh')('is_monorepo')(cachedRegularRepo)
      expect(api).toFail()
    })

    it('should return 1 for non-git directory without workspace config', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpPlainDir = `/tmp/monorepo-plain-${Date.now()}`
      mkdirSync(tmpPlainDir, { recursive: true })

      try {
        const api = sourceScript('./utils/detection.sh')('is_monorepo')(tmpPlainDir)
        expect(api).toFail()
      } finally {
        rmSync(tmpPlainDir, { recursive: true, force: true })
      }
    })
  })

  describe('has_package_json()', () => {
    let cachedJsProject: string | null = null
    let cachedJsSubdir: string | null = null

    it('should return 0 when package.json exists in directory', () => {
      if (!cachedJsProject) {
        cachedJsProject = join(testDir, 'cached-js-project')
        cachedJsSubdir = join(cachedJsProject, 'src', 'components')
        mkdirSync(cachedJsSubdir, { recursive: true })
        initGitRepo(cachedJsProject)
        writeFileSync(join(cachedJsProject, 'package.json'), '{"name": "test"}')
      }
      const api = sourceScript('./utils/detection.sh')('has_package_json')(cachedJsProject)
      expect(api).toBeSuccessful()
    })

    it('should return 0 from subdirectory when repo root has package.json', () => {
      if (!cachedJsProject) {
        cachedJsProject = join(testDir, 'cached-js-project')
        cachedJsSubdir = join(cachedJsProject, 'src', 'components')
        mkdirSync(cachedJsSubdir, { recursive: true })
        initGitRepo(cachedJsProject)
        writeFileSync(join(cachedJsProject, 'package.json'), '{"name": "test"}')
      }
      const api = sourceScript('./utils/detection.sh')('has_package_json')(cachedJsSubdir!)
      expect(api).toBeSuccessful()
    })

    it('should return 1 when no package.json exists', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpEmptyDir = `/tmp/pkgjson-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })

      try {
        const api = sourceScript('./utils/detection.sh')('has_package_json')(tmpEmptyDir)
        expect(api).toFail()
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })

    it('should return 1 for non-git directory without package.json', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpPlainDir = `/tmp/pkgjson-plain-${Date.now()}`
      mkdirSync(tmpPlainDir, { recursive: true })

      try {
        const api = sourceScript('./utils/detection.sh')('has_package_json')(tmpPlainDir)
        expect(api).toFail()
      } finally {
        rmSync(tmpPlainDir, { recursive: true, force: true })
      }
    })

    it('should handle non-existent paths gracefully', () => {
      const api = sourceScript('./utils/detection.sh')('has_package_json')('/nonexistent/path/12345')
      expect(api).toFail()
    })
  })

  describe('has_typescript_files()', () => {
    it('should return 0 when .ts files exist in directory', () => {
      const tsDir = join(testDir, 'ts-project')
      mkdirSync(tsDir, { recursive: true })
      writeFileSync(join(tsDir, 'index.ts'), 'const x: number = 1;')

      const api = sourceScript('./utils/detection.sh')('has_typescript_files')(tsDir)
      expect(api).toBeSuccessful()
    })

    it('should return 0 when .tsx files exist in directory', () => {
      const tsxDir = join(testDir, 'tsx-project')
      mkdirSync(tsxDir, { recursive: true })
      writeFileSync(join(tsxDir, 'App.tsx'), 'export const App = () => <div />')

      const api = sourceScript('./utils/detection.sh')('has_typescript_files')(tsxDir)
      expect(api).toBeSuccessful()
    })

    it('should return 0 when .ts files exist in src/ subdirectory', () => {
      const projectDir = join(testDir, 'ts-src-project')
      const srcDir = join(projectDir, 'src')
      mkdirSync(srcDir, { recursive: true })
      initGitRepo(projectDir)
      writeFileSync(join(srcDir, 'main.ts'), 'console.log("hello")')

      const api = sourceScript('./utils/detection.sh')('has_typescript_files')(projectDir)
      expect(api).toBeSuccessful()
    })

    it('should return 1 for directories without .ts files', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpNoTsDir = `/tmp/ts-nots-${Date.now()}`
      mkdirSync(tmpNoTsDir, { recursive: true })
      writeFileSync(join(tmpNoTsDir, 'index.js'), 'const x = 1;')

      try {
        const api = sourceScript('./utils/detection.sh')('has_typescript_files')(tmpNoTsDir)
        expect(api).toFail()
      } finally {
        rmSync(tmpNoTsDir, { recursive: true, force: true })
      }
    })

    it('should return 1 for empty directory', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpEmptyDir = `/tmp/ts-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })

      try {
        const api = sourceScript('./utils/detection.sh')('has_typescript_files')(tmpEmptyDir)
        expect(api).toFail()
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })

    it('should handle non-existent paths gracefully', () => {
      const api = sourceScript('./utils/detection.sh')('has_typescript_files')('/nonexistent/path/12345')
      expect(api).toFail()
    })
  })

  describe('looks_like_js_project()', () => {
    it('should return 0 when package.json exists in CWD', () => {
      const jsDir = join(testDir, 'js-cwd-test')
      mkdirSync(jsDir, { recursive: true })
      writeFileSync(join(jsDir, 'package.json'), '{"name": "test"}')

      const result = runInTestDir('bash', jsDir, 'looks_like_js_project')
      expect(result.code).toBe(0)
    })

    it('should return 0 when .js files exist in CWD', () => {
      const jsDir = join(testDir, 'js-files-test')
      mkdirSync(jsDir, { recursive: true })
      writeFileSync(join(jsDir, 'index.js'), 'console.log("hello")')

      const result = runInTestDir('bash', jsDir, 'looks_like_js_project')
      expect(result.code).toBe(0)
    })

    it('should return 0 when .ts files exist in CWD', () => {
      const tsDir = join(testDir, 'ts-files-test')
      mkdirSync(tsDir, { recursive: true })
      writeFileSync(join(tsDir, 'index.ts'), 'const x: number = 1')

      const result = runInTestDir('bash', tsDir, 'looks_like_js_project')
      expect(result.code).toBe(0)
    })

    it('should return 1 when no JS/TS indicators exist', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpEmptyDir = `/tmp/js-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })
      writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'just a text file')

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'looks_like_js_project')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })
  })

  describe('looks_like_rust_project()', () => {
    it('should return 0 when Cargo.toml exists in CWD', () => {
      const rustDir = join(testDir, 'rust-project')
      mkdirSync(rustDir, { recursive: true })
      writeFileSync(join(rustDir, 'Cargo.toml'), '[package]\nname = "test"')

      const result = runInTestDir('bash', rustDir, 'looks_like_rust_project')
      expect(result.code).toBe(0)
    })

    it('should return 0 when .rs files exist in CWD', () => {
      const rustDir = join(testDir, 'rust-files-test')
      mkdirSync(rustDir, { recursive: true })
      writeFileSync(join(rustDir, 'main.rs'), 'fn main() {}')

      const result = runInTestDir('bash', rustDir, 'looks_like_rust_project')
      expect(result.code).toBe(0)
    })

    it('should return 1 when no Rust indicators exist', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpEmptyDir = `/tmp/rust-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })
      writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'just a text file')

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'looks_like_rust_project')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })

    it('should not produce errors (exit code 0 or 1 only)', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpEmptyDir = `/tmp/rust-errorcheck-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'looks_like_rust_project')
        expect([0, 1]).toContain(result.code)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })
  })

  describe('looks_like_python_project()', () => {
    // Note: looks_like_python_project() checks repo root if in a git repo,
    // so we need to use /tmp to test detection of Python projects properly
    it('should return 0 when pyproject.toml exists', () => {
      const tmpPyDir = `/tmp/python-pyproject-${Date.now()}`
      mkdirSync(tmpPyDir, { recursive: true })
      writeFileSync(join(tmpPyDir, 'pyproject.toml'), '[project]\nname = "test"')

      try {
        const result = runInTestDir('bash', tmpPyDir, 'looks_like_python_project')
        expect(result.code).toBe(0)
      } finally {
        rmSync(tmpPyDir, { recursive: true, force: true })
      }
    })

    it('should return 0 when requirements.txt exists', () => {
      const tmpPyDir = `/tmp/python-requirements-${Date.now()}`
      mkdirSync(tmpPyDir, { recursive: true })
      writeFileSync(join(tmpPyDir, 'requirements.txt'), 'requests==2.28.0')

      try {
        const result = runInTestDir('bash', tmpPyDir, 'looks_like_python_project')
        expect(result.code).toBe(0)
      } finally {
        rmSync(tmpPyDir, { recursive: true, force: true })
      }
    })

    it('should return 0 when .py files exist', () => {
      const tmpPyDir = `/tmp/python-files-${Date.now()}`
      mkdirSync(tmpPyDir, { recursive: true })
      writeFileSync(join(tmpPyDir, 'main.py'), 'print("hello")')

      try {
        const result = runInTestDir('bash', tmpPyDir, 'looks_like_python_project')
        expect(result.code).toBe(0)
      } finally {
        rmSync(tmpPyDir, { recursive: true, force: true })
      }
    })

    it('should return 1 when no Python indicators exist', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpEmptyDir = `/tmp/python-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })
      writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'just a text file')

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'looks_like_python_project')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })

    it('should not produce errors (exit code 0 or 1 only)', () => {
      // Use /tmp to ensure we're outside any git repo
      const tmpEmptyDir = `/tmp/python-errorcheck-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'looks_like_python_project')
        expect([0, 1]).toContain(result.code)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })
  })
})
