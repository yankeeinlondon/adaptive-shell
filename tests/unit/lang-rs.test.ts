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

// =============================================================================
// FIXTURE DEFINITIONS - All test directories and their contents
// =============================================================================

interface FileFixture {
  files: Record<string, string>
  subdirs?: string[]
}

interface GitFixture extends FileFixture {
  git: true
  commits?: Array<{ file: string; content: string; message: string }>
}

type Fixture = FileFixture | GitFixture

const FIXTURES: Record<string, Fixture> = {
  // get_cargo_toml() fixtures
  'cargo-cwd': {
    files: {
      'Cargo.toml': `[package]
name = "test-crate"
version = "0.1.0"
edition = "2021"`
    }
  },
  'cargo-repo-root': {
    git: true,
    subdirs: ['crates/app'],
    files: {
      'Cargo.toml': `[package]
name = "root-crate"
version = "2.0.0"`
    },
    commits: [
      { file: 'Cargo.toml', content: `[package]\nname = "root-crate"\nversion = "2.0.0"`, message: 'init' }
    ]
  },
  'cargo-empty': {
    files: {
      'readme.txt': 'no Cargo.toml here'
    }
  },
  'cargo-prefer-cwd': {
    git: true,
    subdirs: ['crates/app'],
    files: {
      'Cargo.toml': `[package]
name = "root-crate"`,
      'crates/app/Cargo.toml': `[package]
name = "sub-crate"`
    },
    commits: [
      { file: 'Cargo.toml', content: '[package]\nname = "root-crate"', message: 'init' }
    ]
  },
  'cargo-special': {
    files: {
      'Cargo.toml': `[package]
name = "test"
description = "A \\"quoted\\" value"`
    }
  },

  // has_dependency() fixtures
  'has-dep-inline': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"
tokio = "1.0"`
    }
  },
  'has-dep-table': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
tokio = { version = "1.0", features = ["full"] }`
    }
  },
  'no-dep': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"`
    }
  },
  'no-deps-section': {
    files: {
      'Cargo.toml': `[package]
name = "test"
version = "0.1.0"`
    }
  },
  'dev-not-in-deps': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]

[dev-dependencies]
pretty_assertions = "1.0"`
    }
  },
  'dep-no-arg': {
    files: {
      'Cargo.toml': `[package]
name = "test"`
    }
  },

  // has_dev_dependency() fixtures
  'has-dev-dep-inline': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dev-dependencies]
pretty_assertions = "1.0"
criterion = "0.5"`
    }
  },
  'has-dev-dep-table': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dev-dependencies]
criterion = { version = "0.5", features = ["html_reports"] }`
    }
  },
  'no-dev-dep': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dev-dependencies]
pretty_assertions = "1.0"`
    }
  },
  'no-dev-deps-section': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"`
    }
  },
  'dep-not-in-dev': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"

[dev-dependencies]`
    }
  },
  'dev-dep-no-arg': {
    files: {
      'Cargo.toml': `[package]
name = "test"`
    }
  },

  // has_build_dependency() fixtures
  'has-build-dep-inline': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[build-dependencies]
cc = "1.0"
bindgen = "0.65"`
    }
  },
  'has-build-dep-table': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[build-dependencies]
bindgen = { version = "0.65", features = ["runtime"] }`
    }
  },
  'no-build-dep': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[build-dependencies]
cc = "1.0"`
    }
  },
  'no-build-deps-section': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"`
    }
  },
  'dep-not-in-build': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"

[build-dependencies]`
    }
  },
  'build-dep-no-arg': {
    files: {
      'Cargo.toml': `[package]
name = "test"`
    }
  },

  // has_dependency_anywhere() fixtures
  'dep-anywhere-deps': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"`
    }
  },
  'dep-anywhere-dev': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dev-dependencies]
pretty_assertions = "1.0"`
    }
  },
  'dep-anywhere-build': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[build-dependencies]
cc = "1.0"`
    }
  },
  'dep-nowhere': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"

[dev-dependencies]
pretty_assertions = "1.0"

[build-dependencies]
cc = "1.0"`
    }
  },
  'dep-anywhere-no-arg': {
    files: {
      'Cargo.toml': `[package]
name = "test"`
    }
  },

  // crates_not_installed() fixtures
  'crates-not-installed-basic': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"

[dev-dependencies]
pretty_assertions = "1.0"`
    }
  },
  'crates-all-installed': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"
tokio = "1.0"

[dev-dependencies]
pretty_assertions = "1.0"`
    }
  },
  'crates-none-installed': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]

[dev-dependencies]`
    }
  },
  'crates-in-deps': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"
tokio = "1.0"`
    }
  },
  'crates-in-devdeps': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dev-dependencies]
pretty_assertions = "1.0"
criterion = "0.5"`
    }
  },
  'crates-in-builddeps': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[build-dependencies]
cc = "1.0"
bindgen = "0.65"`
    }
  },
  'crates-mixed-sections': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"

[dev-dependencies]
pretty_assertions = "1.0"

[build-dependencies]
cc = "1.0"`
    }
  },
  'crates-single-arg': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]`
    }
  },
  'crates-multi-args': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]`
    }
  },
  'crates-by-ref': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"`
    }
  },
  'crates-empty-input': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]`
    }
  },
  'crates-naming': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde_json = "1.0"`
    }
  },
  'crates-no-cargo': {
    files: {
      'readme.txt': 'no Cargo.toml'
    }
  },
  'crates-no-dep-sections': {
    files: {
      'Cargo.toml': `[package]
name = "test"
version = "0.1.0"`
    }
  },
  'crates-order': {
    files: {
      'Cargo.toml': `[package]
name = "test"

[dependencies]
serde = "1.0"`
    }
  },

  // get_rs_linter_by_config() fixtures
  'linter-config-clippy': {
    files: {
      'Cargo.toml': `[package]
name = "test"`,
      'clippy.toml': 'msrv = "1.70"'
    }
  },
  'linter-config-dot-clippy': {
    files: {
      'Cargo.toml': `[package]
name = "test"`,
      '.clippy.toml': 'msrv = "1.70"'
    }
  },
  'linter-config-dylint': {
    files: {
      'Cargo.toml': `[package]
name = "test"`,
      'dylint.toml': '[workspace]'
    }
  },
  'linter-config-none': {
    files: {
      'Cargo.toml': `[package]
name = "test"`
    }
  },
  'linter-config-repo-root': {
    git: true,
    subdirs: ['crates/app'],
    files: {
      'Cargo.toml': `[workspace]
members = ["crates/*"]`,
      'clippy.toml': 'msrv = "1.70"'
    },
    commits: [
      { file: 'Cargo.toml', content: '[workspace]', message: 'init' }
    ]
  },

  // get_rs_formatter_by_config() fixtures
  'formatter-config-rustfmt': {
    files: {
      'Cargo.toml': `[package]
name = "test"`,
      'rustfmt.toml': 'max_width = 100'
    }
  },
  'formatter-config-dot-rustfmt': {
    files: {
      'Cargo.toml': `[package]
name = "test"`,
      '.rustfmt.toml': 'max_width = 100'
    }
  },
  'formatter-config-none': {
    files: {
      'Cargo.toml': `[package]
name = "test"`
    }
  },
  'formatter-config-repo-root': {
    git: true,
    subdirs: ['crates/app'],
    files: {
      'Cargo.toml': `[workspace]
members = ["crates/*"]`,
      'rustfmt.toml': 'max_width = 100'
    },
    commits: [
      { file: 'Cargo.toml', content: '[workspace]', message: 'init' }
    ]
  },

  // is_cargo_workspace() fixtures
  'is-workspace-yes': {
    files: {
      'Cargo.toml': `[workspace]
members = [
  "crates/*"
]

[workspace.dependencies]
serde = "1.0"`
    }
  },
  'is-workspace-no': {
    files: {
      'Cargo.toml': `[package]
name = "test"
version = "0.1.0"

[dependencies]
serde = "1.0"`
    }
  },
  'is-workspace-subdir': {
    git: true,
    subdirs: ['crates/app'],
    files: {
      'Cargo.toml': `[workspace]
members = ["crates/*"]`,
      'crates/app/Cargo.toml': `[package]
name = "app"`
    },
    commits: [
      { file: 'Cargo.toml', content: '[workspace]', message: 'init' }
    ]
  },
  'is-workspace-empty': {
    files: {
      'Cargo.toml': ''
    }
  }
}

// =============================================================================
// TESTS
// =============================================================================

describe("lang-rs", { concurrent: true }, () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-lang-rs-test')

  // Pre-computed fixture paths for easy access in tests
  const dirs: Record<string, string> = {}

  beforeAll(() => {
    // Clean up from previous runs and create test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
    mkdirSync(testDir, { recursive: true })

    // Create all fixtures
    for (const [name, fixture] of Object.entries(FIXTURES)) {
      const fixtureDir = join(testDir, name)
      dirs[name] = fixtureDir

      // Create subdirectories first if specified
      if (fixture.subdirs) {
        for (const subdir of fixture.subdirs) {
          mkdirSync(join(fixtureDir, subdir), { recursive: true })
        }
      } else {
        mkdirSync(fixtureDir, { recursive: true })
      }

      // Initialize git repo if needed (before writing files that need to be committed)
      const isGitFixture = 'git' in fixture && fixture.git
      if (isGitFixture) {
        initGitRepo(fixtureDir)
      }

      // Write all files
      for (const [filename, content] of Object.entries(fixture.files)) {
        const filePath = join(fixtureDir, filename)
        const fileDir = join(filePath, '..')
        if (!existsSync(fileDir)) {
          mkdirSync(fileDir, { recursive: true })
        }
        writeFileSync(filePath, content)
      }

      // Create commits if specified
      if (isGitFixture && (fixture as GitFixture).commits) {
        for (const commit of (fixture as GitFixture).commits!) {
          execSync(`git add "${commit.file}"`, { cwd: fixtureDir, stdio: 'pipe' })
          execSync(`git commit --no-gpg-sign -m "${commit.message}"`, { cwd: fixtureDir, stdio: 'pipe' })
        }
      }
    }
  })

  afterAll(() => {
    // Clean up test directory once at the end
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
  })

  describe('get_cargo_toml()', () => {
    it('should return Cargo.toml content from current directory', () => {
      const result = runInTestDir('bash', dirs['cargo-cwd'], 'get_cargo_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('name = "test-crate"')
    })

    it('should return Cargo.toml content from repo root when not in cwd', () => {
      const subDir = join(dirs['cargo-repo-root'], 'crates', 'app')
      const result = runInTestDir('bash', subDir, 'get_cargo_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('name = "root-crate"')
    })

    it('should return 1 when no Cargo.toml exists', () => {
      const result = runInTestDir('bash', dirs['cargo-empty'], 'get_cargo_toml')
      expect(result.code).toBe(1)
    })

    it('should prefer cwd Cargo.toml over repo root', () => {
      const subDir = join(dirs['cargo-prefer-cwd'], 'crates', 'app')
      const result = runInTestDir('bash', subDir, 'get_cargo_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('name = "sub-crate"')
    })

    it('should handle Cargo.toml with special characters', () => {
      const result = runInTestDir('bash', dirs['cargo-special'], 'get_cargo_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('description')
    })
  })

  describe('has_dependency()', () => {
    it('should return 0 when dependency exists in inline format', () => {
      const result = runInTestDir('bash', dirs['has-dep-inline'], 'has_dependency "serde"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dependency exists in table format', () => {
      const result = runInTestDir('bash', dirs['has-dep-table'], 'has_dependency "tokio"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-dep'], 'has_dependency "tokio"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when dependencies section does not exist', () => {
      const result = runInTestDir('bash', dirs['no-deps-section'], 'has_dependency "serde"')
      expect(result.code).toBe(1)
    })

    it('should not find dev-dependency in dependencies', () => {
      const result = runInTestDir('bash', dirs['dev-not-in-deps'], 'has_dependency "pretty_assertions"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['dep-no-arg'], 'has_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dev_dependency()', () => {
    it('should return 0 when dev-dependency exists in inline format', () => {
      const result = runInTestDir('bash', dirs['has-dev-dep-inline'], 'has_dev_dependency "pretty_assertions"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dev-dependency exists in table format', () => {
      const result = runInTestDir('bash', dirs['has-dev-dep-table'], 'has_dev_dependency "criterion"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dev-dependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-dev-dep'], 'has_dev_dependency "criterion"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when dev-dependencies section does not exist', () => {
      const result = runInTestDir('bash', dirs['no-dev-deps-section'], 'has_dev_dependency "pretty_assertions"')
      expect(result.code).toBe(1)
    })

    it('should not find dependency in dev-dependencies', () => {
      const result = runInTestDir('bash', dirs['dep-not-in-dev'], 'has_dev_dependency "serde"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['dev-dep-no-arg'], 'has_dev_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_build_dependency()', () => {
    it('should return 0 when build-dependency exists in inline format', () => {
      const result = runInTestDir('bash', dirs['has-build-dep-inline'], 'has_build_dependency "cc"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when build-dependency exists in table format', () => {
      const result = runInTestDir('bash', dirs['has-build-dep-table'], 'has_build_dependency "bindgen"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when build-dependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-build-dep'], 'has_build_dependency "bindgen"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when build-dependencies section does not exist', () => {
      const result = runInTestDir('bash', dirs['no-build-deps-section'], 'has_build_dependency "cc"')
      expect(result.code).toBe(1)
    })

    it('should not find dependency in build-dependencies', () => {
      const result = runInTestDir('bash', dirs['dep-not-in-build'], 'has_build_dependency "serde"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['build-dep-no-arg'], 'has_build_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dependency_anywhere()', () => {
    it('should find dependency in [dependencies] section', () => {
      const result = runInTestDir('bash', dirs['dep-anywhere-deps'], 'has_dependency_anywhere "serde"')
      expect(result.code).toBe(0)
    })

    it('should find dependency in [dev-dependencies] section', () => {
      const result = runInTestDir('bash', dirs['dep-anywhere-dev'], 'has_dependency_anywhere "pretty_assertions"')
      expect(result.code).toBe(0)
    })

    it('should find dependency in [build-dependencies] section', () => {
      const result = runInTestDir('bash', dirs['dep-anywhere-build'], 'has_dependency_anywhere "cc"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency not in any section', () => {
      const result = runInTestDir('bash', dirs['dep-nowhere'], 'has_dependency_anywhere "tokio"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['dep-anywhere-no-arg'], 'has_dependency_anywhere')
      expect(result.code).not.toBe(0)
    })
  })

  describe('crates_not_installed()', () => {
    describe('basic functionality', () => {
      it('should return crates not in any dependency section', () => {
        const result = runInTestDir('bash', dirs['crates-not-installed-basic'], 'crates_not_installed "tokio" "axum" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['tokio', 'axum', 'clap'])
      })

      it('should return empty when all crates are installed', () => {
        const result = runInTestDir('bash', dirs['crates-all-installed'], 'crates_not_installed "serde" "tokio" "pretty_assertions"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })

      it('should return all crates when none are installed', () => {
        const result = runInTestDir('bash', dirs['crates-none-installed'], 'crates_not_installed "serde" "tokio" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['serde', 'tokio', 'clap'])
      })
    })

    describe('dependency section coverage', () => {
      it('should filter out crates in dependencies', () => {
        const result = runInTestDir('bash', dirs['crates-in-deps'], 'crates_not_installed "serde" "tokio" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['clap'])
      })

      it('should filter out crates in dev-dependencies', () => {
        const result = runInTestDir('bash', dirs['crates-in-devdeps'], 'crates_not_installed "pretty_assertions" "criterion" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['clap'])
      })

      it('should filter out crates in build-dependencies', () => {
        const result = runInTestDir('bash', dirs['crates-in-builddeps'], 'crates_not_installed "cc" "bindgen" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['clap'])
      })

      it('should handle crates mixed across all sections', () => {
        const result = runInTestDir('bash', dirs['crates-mixed-sections'], 'crates_not_installed "serde" "pretty_assertions" "cc" "tokio" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['tokio', 'clap'])
      })
    })

    describe('input handling', () => {
      it('should handle single crate argument', () => {
        const result = runInTestDir('bash', dirs['crates-single-arg'], 'crates_not_installed "tokio"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('tokio')
      })

      it('should handle multiple crate arguments', () => {
        const result = runInTestDir('bash', dirs['crates-multi-args'], 'crates_not_installed "tokio" "axum" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['tokio', 'axum', 'clap'])
      })

      it('should handle pass-by-reference (array name) and modify in-place', () => {
        // Pass-by-reference should modify array in-place, not output to stdout
        const script = `
          declare -a my_crates=("serde" "tokio" "clap")
          crates_not_installed my_crates
          echo "\${my_crates[@]}"
        `
        const result = runInTestDir('bash', dirs['crates-by-ref'], script)
        expect(result.code).toBe(0)
        // Array should now only contain not-installed crates
        expect(result.stdout).toBe('tokio clap')
      })

      it('should return empty output for empty input', () => {
        const result = runInTestDir('bash', dirs['crates-empty-input'], 'crates_not_installed')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })
    })

    describe('edge cases', () => {
      it('should handle crates with hyphens and underscores', () => {
        const result = runInTestDir('bash', dirs['crates-naming'], 'crates_not_installed "serde_json" "tokio-util" "clap"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['tokio-util', 'clap'])
      })

      it('should handle no Cargo.toml file', () => {
        const result = runInTestDir('bash', dirs['crates-no-cargo'], 'crates_not_installed "serde" "tokio"')
        // Should return all crates as not installed (or error)
        if (result.code === 0) {
          const lines = result.stdout.trim().split('\n').filter(l => l)
          expect(lines).toEqual(['serde', 'tokio'])
        } else {
          // Error is also acceptable behavior
          expect(result.code).not.toBe(0)
        }
      })

      it('should handle Cargo.toml with no dependency sections', () => {
        const result = runInTestDir('bash', dirs['crates-no-dep-sections'], 'crates_not_installed "serde" "tokio"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['serde', 'tokio'])
      })
    })

    describe('output format', () => {
      it('should preserve input order in output', () => {
        const result = runInTestDir('bash', dirs['crates-order'], 'crates_not_installed "zebra" "apple" "mango" "serde"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['zebra', 'apple', 'mango'])
      })
    })
  })

  describe('get_rs_linter_by_config()', () => {
    it('should detect clippy.toml', () => {
      const result = runInTestDir('bash', dirs['linter-config-clippy'], 'get_rs_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('clippy')
    })

    it('should detect .clippy.toml', () => {
      const result = runInTestDir('bash', dirs['linter-config-dot-clippy'], 'get_rs_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('clippy')
    })

    it('should detect dylint.toml', () => {
      const result = runInTestDir('bash', dirs['linter-config-dylint'], 'get_rs_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('dylint')
    })

    it('should return 1 when no linter config found', () => {
      const result = runInTestDir('bash', dirs['linter-config-none'], 'get_rs_linter_by_config')
      expect(result.code).toBe(1)
    })

    it('should detect from repo root when in subdirectory', () => {
      const subDir = join(dirs['linter-config-repo-root'], 'crates', 'app')
      const result = runInTestDir('bash', subDir, 'get_rs_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('clippy')
    })
  })

  describe('get_rs_formatter_by_config()', () => {
    it('should detect rustfmt.toml', () => {
      const result = runInTestDir('bash', dirs['formatter-config-rustfmt'], 'get_rs_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('rustfmt')
    })

    it('should detect .rustfmt.toml', () => {
      const result = runInTestDir('bash', dirs['formatter-config-dot-rustfmt'], 'get_rs_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('rustfmt')
    })

    it('should return 1 when no formatter config found', () => {
      const result = runInTestDir('bash', dirs['formatter-config-none'], 'get_rs_formatter_by_config')
      expect(result.code).toBe(1)
    })

    it('should detect from repo root when in subdirectory', () => {
      const subDir = join(dirs['formatter-config-repo-root'], 'crates', 'app')
      const result = runInTestDir('bash', subDir, 'get_rs_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('rustfmt')
    })
  })

  describe('is_cargo_workspace()', () => {
    it('should return 0 when [workspace] section exists', () => {
      const result = runInTestDir('bash', dirs['is-workspace-yes'], 'is_cargo_workspace')
      expect(result.code).toBe(0)
    })

    it('should return 1 when [workspace] section does not exist', () => {
      const result = runInTestDir('bash', dirs['is-workspace-no'], 'is_cargo_workspace')
      expect(result.code).toBe(1)
    })

    it('should detect workspace from repo root when in subdirectory', () => {
      const subDir = join(dirs['is-workspace-subdir'], 'crates', 'app')
      const result = runInTestDir('bash', subDir, 'is_cargo_workspace')
      expect(result.code).toBe(0)
    })

    it('should handle empty Cargo.toml', () => {
      const result = runInTestDir('bash', dirs['is-workspace-empty'], 'is_cargo_workspace')
      expect(result.code).toBe(1)
    })
  })
})
