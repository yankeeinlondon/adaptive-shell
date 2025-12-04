import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { mkdirSync, rmSync, existsSync, writeFileSync } from 'fs'
import { join } from 'path'
import { execSync } from 'child_process'
import { runInShell } from "../helpers"

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
    source "${PROJECT_ROOT}/utils/filesystem.sh"
    source "${PROJECT_ROOT}/utils/lang-rs.sh"
    ${script}
  `, { cwd: testDir })
}

describe("lang-rs", () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-lang-rs-test')

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

  describe('get_cargo_toml()', () => {
    it('should return Cargo.toml content from current directory', () => {
      const cargoDir = join(testDir, 'cargo-cwd')
      mkdirSync(cargoDir, { recursive: true })
      const cargoContent = `[package]
name = "test-crate"
version = "0.1.0"
edition = "2021"`
      writeFileSync(join(cargoDir, 'Cargo.toml'), cargoContent)

      const result = runInTestDir('bash', cargoDir, 'get_cargo_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(cargoContent)
    })

    it('should return Cargo.toml content from repo root when not in cwd', () => {
      const repoDir = join(testDir, 'cargo-repo-root')
      const subDir = join(repoDir, 'crates', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      const cargoContent = `[package]
name = "root-crate"
version = "2.0.0"`
      writeFileSync(join(repoDir, 'Cargo.toml'), cargoContent)
      commitFile(repoDir, 'Cargo.toml', cargoContent, 'init')

      const result = runInTestDir('bash', subDir, 'get_cargo_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(cargoContent)
    })

    it('should return 1 when no Cargo.toml exists', () => {
      const tmpEmptyDir = `/tmp/cargo-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })
      writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'no Cargo.toml here')

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'get_cargo_toml')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })

    it('should prefer cwd Cargo.toml over repo root', () => {
      const repoDir = join(testDir, 'cargo-prefer-cwd')
      const subDir = join(repoDir, 'crates', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)

      const rootCargo = `[package]
name = "root-crate"`
      const subCargo = `[package]
name = "sub-crate"`
      writeFileSync(join(repoDir, 'Cargo.toml'), rootCargo)
      writeFileSync(join(subDir, 'Cargo.toml'), subCargo)
      commitFile(repoDir, 'Cargo.toml', rootCargo, 'init')

      const result = runInTestDir('bash', subDir, 'get_cargo_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(subCargo)
    })

    it('should handle Cargo.toml with special characters', () => {
      const cargoDir = join(testDir, 'cargo-special')
      mkdirSync(cargoDir, { recursive: true })
      const cargoContent = `[package]
name = "test"
description = "A \\"quoted\\" value"`
      writeFileSync(join(cargoDir, 'Cargo.toml'), cargoContent)

      const result = runInTestDir('bash', cargoDir, 'get_cargo_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(cargoContent)
    })
  })

  describe('has_dependency()', () => {
    it('should return 0 when dependency exists in inline format', () => {
      const cargoDir = join(testDir, 'has-dep-inline')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"
tokio = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency "serde"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dependency exists in table format', () => {
      const cargoDir = join(testDir, 'has-dep-table')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
tokio = { version = "1.0", features = ["full"] }`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency "tokio"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency does not exist', () => {
      const cargoDir = join(testDir, 'no-dep')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency "tokio"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when dependencies section does not exist', () => {
      const cargoDir = join(testDir, 'no-deps-section')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"
version = "0.1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency "serde"')
      expect(result.code).toBe(1)
    })

    it('should not find dev-dependency in dependencies', () => {
      const cargoDir = join(testDir, 'dev-not-in-deps')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]

[dev-dependencies]
pretty_assertions = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency "pretty_assertions"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const cargoDir = join(testDir, 'dep-no-arg')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dev_dependency()', () => {
    it('should return 0 when dev-dependency exists in inline format', () => {
      const cargoDir = join(testDir, 'has-dev-dep-inline')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dev-dependencies]
pretty_assertions = "1.0"
criterion = "0.5"`)

      const result = runInTestDir('bash', cargoDir, 'has_dev_dependency "pretty_assertions"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dev-dependency exists in table format', () => {
      const cargoDir = join(testDir, 'has-dev-dep-table')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dev-dependencies]
criterion = { version = "0.5", features = ["html_reports"] }`)

      const result = runInTestDir('bash', cargoDir, 'has_dev_dependency "criterion"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dev-dependency does not exist', () => {
      const cargoDir = join(testDir, 'no-dev-dep')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dev-dependencies]
pretty_assertions = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dev_dependency "criterion"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when dev-dependencies section does not exist', () => {
      const cargoDir = join(testDir, 'no-dev-deps-section')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dev_dependency "pretty_assertions"')
      expect(result.code).toBe(1)
    })

    it('should not find dependency in dev-dependencies', () => {
      const cargoDir = join(testDir, 'dep-not-in-dev')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"

[dev-dependencies]`)

      const result = runInTestDir('bash', cargoDir, 'has_dev_dependency "serde"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const cargoDir = join(testDir, 'dev-dep-no-arg')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)

      const result = runInTestDir('bash', cargoDir, 'has_dev_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_build_dependency()', () => {
    it('should return 0 when build-dependency exists in inline format', () => {
      const cargoDir = join(testDir, 'has-build-dep-inline')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[build-dependencies]
cc = "1.0"
bindgen = "0.65"`)

      const result = runInTestDir('bash', cargoDir, 'has_build_dependency "cc"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when build-dependency exists in table format', () => {
      const cargoDir = join(testDir, 'has-build-dep-table')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[build-dependencies]
bindgen = { version = "0.65", features = ["runtime"] }`)

      const result = runInTestDir('bash', cargoDir, 'has_build_dependency "bindgen"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when build-dependency does not exist', () => {
      const cargoDir = join(testDir, 'no-build-dep')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[build-dependencies]
cc = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_build_dependency "bindgen"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when build-dependencies section does not exist', () => {
      const cargoDir = join(testDir, 'no-build-deps-section')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_build_dependency "cc"')
      expect(result.code).toBe(1)
    })

    it('should not find dependency in build-dependencies', () => {
      const cargoDir = join(testDir, 'dep-not-in-build')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"

[build-dependencies]`)

      const result = runInTestDir('bash', cargoDir, 'has_build_dependency "serde"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const cargoDir = join(testDir, 'build-dep-no-arg')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)

      const result = runInTestDir('bash', cargoDir, 'has_build_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dependency_anywhere()', () => {
    it('should find dependency in [dependencies] section', () => {
      const cargoDir = join(testDir, 'dep-anywhere-deps')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency_anywhere "serde"')
      expect(result.code).toBe(0)
    })

    it('should find dependency in [dev-dependencies] section', () => {
      const cargoDir = join(testDir, 'dep-anywhere-dev')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dev-dependencies]
pretty_assertions = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency_anywhere "pretty_assertions"')
      expect(result.code).toBe(0)
    })

    it('should find dependency in [build-dependencies] section', () => {
      const cargoDir = join(testDir, 'dep-anywhere-build')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[build-dependencies]
cc = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency_anywhere "cc"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency not in any section', () => {
      const cargoDir = join(testDir, 'dep-nowhere')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"

[dev-dependencies]
pretty_assertions = "1.0"

[build-dependencies]
cc = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency_anywhere "tokio"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const cargoDir = join(testDir, 'dep-anywhere-no-arg')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)

      const result = runInTestDir('bash', cargoDir, 'has_dependency_anywhere')
      expect(result.code).not.toBe(0)
    })
  })

  describe('crates_not_installed()', () => {
    describe('basic functionality', () => {
      it('should return crates not in any dependency section', () => {
        const cargoDir = join(testDir, 'crates-not-installed-basic')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"

[dev-dependencies]
pretty_assertions = "1.0"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "tokio" "axum" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['tokio', 'axum', 'clap'])
      })

      it('should return empty when all crates are installed', () => {
        const cargoDir = join(testDir, 'crates-all-installed')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"
tokio = "1.0"

[dev-dependencies]
pretty_assertions = "1.0"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "serde" "tokio" "pretty_assertions"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })

      it('should return all crates when none are installed', () => {
        const cargoDir = join(testDir, 'crates-none-installed')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]

[dev-dependencies]`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "serde" "tokio" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['serde', 'tokio', 'clap'])
      })
    })

    describe('dependency section coverage', () => {
      it('should filter out crates in dependencies', () => {
        const cargoDir = join(testDir, 'crates-in-deps')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"
tokio = "1.0"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "serde" "tokio" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['clap'])
      })

      it('should filter out crates in dev-dependencies', () => {
        const cargoDir = join(testDir, 'crates-in-devdeps')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dev-dependencies]
pretty_assertions = "1.0"
criterion = "0.5"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "pretty_assertions" "criterion" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['clap'])
      })

      it('should filter out crates in build-dependencies', () => {
        const cargoDir = join(testDir, 'crates-in-builddeps')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[build-dependencies]
cc = "1.0"
bindgen = "0.65"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "cc" "bindgen" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['clap'])
      })

      it('should handle crates mixed across all sections', () => {
        const cargoDir = join(testDir, 'crates-mixed-sections')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"

[dev-dependencies]
pretty_assertions = "1.0"

[build-dependencies]
cc = "1.0"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "serde" "pretty_assertions" "cc" "tokio" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['tokio', 'clap'])
      })
    })

    describe('input handling', () => {
      it('should handle single crate argument', () => {
        const cargoDir = join(testDir, 'crates-single-arg')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "tokio"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('tokio')
      })

      it('should handle multiple crate arguments', () => {
        const cargoDir = join(testDir, 'crates-multi-args')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "tokio" "axum" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['tokio', 'axum', 'clap'])
      })

      it('should handle pass-by-reference (array name) and modify in-place', () => {
        const cargoDir = join(testDir, 'crates-by-ref')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"`)

        // Pass-by-reference should modify array in-place, not output to stdout
        const script = `
          declare -a my_crates=("serde" "tokio" "clap")
          crates_not_installed my_crates
          echo "\${my_crates[@]}"
        `
        const result = runInTestDir('bash', cargoDir, script)
        expect(result.code).toBe(0)
        // Array should now only contain not-installed crates
        expect(result.stdout).toBe('tokio clap')
      })

      it('should return empty output for empty input', () => {
        const cargoDir = join(testDir, 'crates-empty-input')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })
    })

    describe('edge cases', () => {
      it('should handle crates with hyphens and underscores', () => {
        const cargoDir = join(testDir, 'crates-naming')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde_json = "1.0"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "serde_json" "tokio-util" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['tokio-util', 'clap'])
      })

      it('should handle no Cargo.toml file', () => {
        const tmpEmptyDir = `/tmp/crates-no-cargo-${Date.now()}`
        mkdirSync(tmpEmptyDir, { recursive: true })
        writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'no Cargo.toml')

        try {
          const result = runInTestDir('bash', tmpEmptyDir, 'crates_not_installed "serde" "tokio"')
          // Should return all crates as not installed (or error)
          if (result.code === 0) {
            const lines = result.stdout.trim().split('\n').filter(l => l)
            expect(lines).toEqual(['serde', 'tokio'])
          } else {
            // Error is also acceptable behavior
            expect(result.code).not.toBe(0)
          }
        } finally {
          rmSync(tmpEmptyDir, { recursive: true, force: true })
        }
      })

      it('should handle Cargo.toml with no dependency sections', () => {
        const cargoDir = join(testDir, 'crates-no-dep-sections')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"
version = "0.1.0"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "serde" "tokio"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['serde', 'tokio'])
      })
    })

    describe('output format', () => {
      it('should preserve input order in output', () => {
        const cargoDir = join(testDir, 'crates-order')
        mkdirSync(cargoDir, { recursive: true })
        writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"

[dependencies]
serde = "1.0"`)

        const result = runInTestDir('bash', cargoDir, 'crates_not_installed "zebra" "apple" "mango" "serde"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['zebra', 'apple', 'mango'])
      })
    })
  })

  describe('get_rs_linter_by_config()', () => {
    it('should detect clippy.toml', () => {
      const cargoDir = join(testDir, 'linter-config-clippy')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)
      writeFileSync(join(cargoDir, 'clippy.toml'), 'msrv = "1.70"')

      const result = runInTestDir('bash', cargoDir, 'get_rs_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('clippy')
    })

    it('should detect .clippy.toml', () => {
      const cargoDir = join(testDir, 'linter-config-dot-clippy')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)
      writeFileSync(join(cargoDir, '.clippy.toml'), 'msrv = "1.70"')

      const result = runInTestDir('bash', cargoDir, 'get_rs_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('clippy')
    })

    it('should detect dylint.toml', () => {
      const cargoDir = join(testDir, 'linter-config-dylint')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)
      writeFileSync(join(cargoDir, 'dylint.toml'), '[workspace]')

      const result = runInTestDir('bash', cargoDir, 'get_rs_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('dylint')
    })

    it('should return 1 when no linter config found', () => {
      const cargoDir = join(testDir, 'linter-config-none')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)

      const result = runInTestDir('bash', cargoDir, 'get_rs_linter_by_config')
      expect(result.code).toBe(1)
    })

    it('should detect from repo root when in subdirectory', () => {
      const repoDir = join(testDir, 'linter-config-repo-root')
      const subDir = join(repoDir, 'crates', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'Cargo.toml'), `[workspace]
members = ["crates/*"]`)
      writeFileSync(join(repoDir, 'clippy.toml'), 'msrv = "1.70"')
      commitFile(repoDir, 'Cargo.toml', '[workspace]', 'init')

      const result = runInTestDir('bash', subDir, 'get_rs_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('clippy')
    })
  })

  describe('get_rs_formatter_by_config()', () => {
    it('should detect rustfmt.toml', () => {
      const cargoDir = join(testDir, 'formatter-config-rustfmt')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)
      writeFileSync(join(cargoDir, 'rustfmt.toml'), 'max_width = 100')

      const result = runInTestDir('bash', cargoDir, 'get_rs_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('rustfmt')
    })

    it('should detect .rustfmt.toml', () => {
      const cargoDir = join(testDir, 'formatter-config-dot-rustfmt')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)
      writeFileSync(join(cargoDir, '.rustfmt.toml'), 'max_width = 100')

      const result = runInTestDir('bash', cargoDir, 'get_rs_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('rustfmt')
    })

    it('should return 1 when no formatter config found', () => {
      const cargoDir = join(testDir, 'formatter-config-none')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"`)

      const result = runInTestDir('bash', cargoDir, 'get_rs_formatter_by_config')
      expect(result.code).toBe(1)
    })

    it('should detect from repo root when in subdirectory', () => {
      const repoDir = join(testDir, 'formatter-config-repo-root')
      const subDir = join(repoDir, 'crates', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'Cargo.toml'), `[workspace]
members = ["crates/*"]`)
      writeFileSync(join(repoDir, 'rustfmt.toml'), 'max_width = 100')
      commitFile(repoDir, 'Cargo.toml', '[workspace]', 'init')

      const result = runInTestDir('bash', subDir, 'get_rs_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('rustfmt')
    })
  })

  describe('is_cargo_workspace()', () => {
    it('should return 0 when [workspace] section exists', () => {
      const cargoDir = join(testDir, 'is-workspace-yes')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[workspace]
members = [
  "crates/*"
]

[workspace.dependencies]
serde = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'is_cargo_workspace')
      expect(result.code).toBe(0)
    })

    it('should return 1 when [workspace] section does not exist', () => {
      const cargoDir = join(testDir, 'is-workspace-no')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), `[package]
name = "test"
version = "0.1.0"

[dependencies]
serde = "1.0"`)

      const result = runInTestDir('bash', cargoDir, 'is_cargo_workspace')
      expect(result.code).toBe(1)
    })

    it('should detect workspace from repo root when in subdirectory', () => {
      const repoDir = join(testDir, 'is-workspace-subdir')
      const subDir = join(repoDir, 'crates', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'Cargo.toml'), `[workspace]
members = ["crates/*"]`)
      writeFileSync(join(subDir, 'Cargo.toml'), `[package]
name = "app"`)
      commitFile(repoDir, 'Cargo.toml', '[workspace]', 'init')

      const result = runInTestDir('bash', subDir, 'is_cargo_workspace')
      expect(result.code).toBe(0)
    })

    it('should handle empty Cargo.toml', () => {
      const cargoDir = join(testDir, 'is-workspace-empty')
      mkdirSync(cargoDir, { recursive: true })
      writeFileSync(join(cargoDir, 'Cargo.toml'), '')

      const result = runInTestDir('bash', cargoDir, 'is_cargo_workspace')
      expect(result.code).toBe(1)
    })
  })
})
