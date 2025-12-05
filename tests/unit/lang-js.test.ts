import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { mkdirSync, rmSync, writeFileSync } from 'fs'
import { join } from 'path'
import { runInShell, GitFixtureManager, GitFixtureDef, COMMON_GIT_PATTERNS } from "../helpers"

/** Project root for absolute path references */
const PROJECT_ROOT = process.cwd()

/** Path to permanent fixtures */
const FIXTURES_DIR = join(PROJECT_ROOT, 'tests', 'fixtures', 'lang-js')

/**
 * Helper to run shell script in a test directory while sourcing scripts from project root
 */
function runInTestDir(shell: 'bash' | 'zsh', testDir: string, script: string) {
  return runInShell(shell, `
    export ADAPTIVE_SHELL="${PROJECT_ROOT}"
    source "${PROJECT_ROOT}/utils/detection.sh"
    source "${PROJECT_ROOT}/utils/filesystem.sh"
    source "${PROJECT_ROOT}/utils/lang-js.sh"
    ${script}
  `, { cwd: testDir })
}

// =============================================================================
// GIT FIXTURES - Only fixtures that require git repos (created dynamically)
// =============================================================================

const GIT_FIXTURES: Record<string, GitFixtureDef> = {
  'pkg-mgr-subdir-test': COMMON_GIT_PATTERNS.pkgMgrSubdir(
    'package.json', '{"name": "monorepo"}',
    'pnpm-lock.yaml', 'lockfileVersion: 6.0',
    'packages/app'
  ),
  'pkg-json-repo-root': COMMON_GIT_PATTERNS.repoRoot(
    'package.json',
    '{"name": "root-pkg", "version": "2.0.0"}',
    'packages/app'
  ),
  'pkg-json-prefer-cwd': COMMON_GIT_PATTERNS.preferCwd(
    'package.json',
    '{"name": "root-pkg"}',
    'packages/app',
    '{"name": "sub-pkg"}'
  )
}

// =============================================================================
// TESTS
// =============================================================================

describe("lang-js", { concurrent: true }, () => {
  // Git fixture manager
  const gitManager = new GitFixtureManager('lang-js-git')

  // Paths to all fixtures (permanent + git)
  const dirs: Record<string, string> = {}

  beforeAll(() => {
    // Set up paths to permanent fixtures
    const permanentFixtures = [
      'pnpm-project', 'pnpm-workspace-project', 'npm-project', 'yarn-project',
      'bun-project', 'deno-project', 'js-no-lock', 'non-js-project', 'mixed-locks',
      'no-lockfile', 'pkg-json-cwd', 'pkg-json-empty', 'pkg-json-special',
      'has-dev-dep', 'no-dev-dep', 'no-dev-deps-section', 'dep-wrong-section', 'dev-dep-no-arg',
      'has-dep', 'no-dep', 'no-deps-section', 'dev-not-in-deps', 'dep-no-arg',
      'has-peer-dep', 'no-peer-dep', 'no-peer-deps-section', 'dep-not-in-peer', 'peer-dep-no-arg',
      'linter-dep-eslint', 'linter-dep-biomejs', 'linter-dep-biome-unscoped',
      'linter-dep-oxlint', 'linter-dep-tsslint', 'linter-dep-none', 'linter-dep-priority',
      'pkgs-not-installed-basic', 'pkgs-all-installed', 'pkgs-none-installed',
      'pkgs-in-deps', 'pkgs-in-devdeps', 'pkgs-in-peerdeps', 'pkgs-mixed-sections',
      'pkgs-single-arg', 'pkgs-multi-args', 'pkgs-by-ref', 'pkgs-empty-input',
      'pkgs-scoped', 'pkgs-no-dep-sections', 'pkgs-order'
    ]

    for (const name of permanentFixtures) {
      dirs[name] = join(FIXTURES_DIR, name)
    }

    // Create git fixtures using the manager
    const gitDirs = gitManager.setup(GIT_FIXTURES)
    Object.assign(dirs, gitDirs)
  })

  afterAll(() => {
    gitManager.teardown()
  })

  describe('js_package_manager()', () => {
    it('should return "pnpm" when pnpm-lock.yaml exists', () => {
      const result = runInTestDir('bash', dirs['pnpm-project'], 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pnpm')
    })

    it('should return "pnpm" when pnpm-workspace.yaml exists', () => {
      const result = runInTestDir('bash', dirs['pnpm-workspace-project'], 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pnpm')
    })

    it('should return "npm" when package-lock.json exists', () => {
      const result = runInTestDir('bash', dirs['npm-project'], 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('npm')
    })

    it('should return "yarn" when yarn.lock exists', () => {
      const result = runInTestDir('bash', dirs['yarn-project'], 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('yarn')
    })

    it('should return "bun" when bun.lockb exists', () => {
      const result = runInTestDir('bash', dirs['bun-project'], 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('bun')
    })

    it('should return "deno" when deno.lock exists', () => {
      const result = runInTestDir('bash', dirs['deno-project'], 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('deno')
    })

    it('should return success with empty output when package.json exists but no lock file', () => {
      const result = runInTestDir('bash', dirs['js-no-lock'], 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('')
    })

    it('should return 1 when not a JS project', () => {
      // Use a temp directory outside the repo to avoid inheriting repo's pnpm-lock.yaml
      const tmpDir = `/tmp/pkg-mgr-nojs-${Date.now()}`
      mkdirSync(tmpDir, { recursive: true })
      writeFileSync(join(tmpDir, 'readme.txt'), 'not a js project')
      try {
        const result = runInTestDir('bash', tmpDir, 'js_package_manager')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpDir, { recursive: true, force: true })
      }
    })

    it('should detect package manager from repo root when in subdirectory', () => {
      const subDir = join(dirs['pkg-mgr-subdir-test'], 'packages', 'app')
      const result = runInTestDir('bash', subDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pnpm')
    })

    it('should prioritize pnpm over npm when both lock files exist', () => {
      const result = runInTestDir('bash', dirs['mixed-locks'], 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pnpm')
    })
  })

  describe('get_package_json()', () => {
    it('should return package.json content from current directory', () => {
      const result = runInTestDir('bash', dirs['pkg-json-cwd'], 'get_package_json')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('"name"')
      expect(result.stdout).toContain('test-pkg')
    })

    it('should return package.json content from repo root when not in cwd', () => {
      const subDir = join(dirs['pkg-json-repo-root'], 'packages', 'app')
      const result = runInTestDir('bash', subDir, 'get_package_json')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('root-pkg')
    })

    it('should return 1 when no package.json exists', () => {
      // Use a temp directory outside the repo to avoid inheriting repo's package.json
      const tmpDir = `/tmp/pkg-json-empty-${Date.now()}`
      mkdirSync(tmpDir, { recursive: true })
      writeFileSync(join(tmpDir, 'readme.txt'), 'no package.json here')
      try {
        const result = runInTestDir('bash', tmpDir, 'get_package_json')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpDir, { recursive: true, force: true })
      }
    })

    it('should prefer cwd package.json over repo root', () => {
      const subDir = join(dirs['pkg-json-prefer-cwd'], 'packages', 'app')
      const result = runInTestDir('bash', subDir, 'get_package_json')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('sub-pkg')
    })

    it('should handle package.json with special characters', () => {
      const result = runInTestDir('bash', dirs['pkg-json-special'], 'get_package_json')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('quoted')
    })
  })

  describe('has_dev_dependency()', () => {
    it('should return 0 when devDependency exists', () => {
      const result = runInTestDir('bash', dirs['has-dev-dep'], 'has_dev_dependency "vitest"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when devDependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-dev-dep'], 'has_dev_dependency "jest"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when devDependencies section does not exist', () => {
      const result = runInTestDir('bash', dirs['no-dev-deps-section'], 'has_dev_dependency "vitest"')
      expect(result.code).toBe(1)
    })

    it('should not find dependency in wrong section', () => {
      const result = runInTestDir('bash', dirs['dep-wrong-section'], 'has_dev_dependency "lodash"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['dev-dep-no-arg'], 'has_dev_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dependency()', () => {
    it('should return 0 when dependency exists', () => {
      const result = runInTestDir('bash', dirs['has-dep'], 'has_dependency "lodash"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-dep'], 'has_dependency "express"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when dependencies section does not exist', () => {
      const result = runInTestDir('bash', dirs['no-deps-section'], 'has_dependency "lodash"')
      expect(result.code).toBe(1)
    })

    it('should not find devDependency in dependencies', () => {
      const result = runInTestDir('bash', dirs['dev-not-in-deps'], 'has_dependency "vitest"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['dep-no-arg'], 'has_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_peer_dependency()', () => {
    it('should return 0 when peerDependency exists', () => {
      const result = runInTestDir('bash', dirs['has-peer-dep'], 'has_peer_dependency "react"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when peerDependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-peer-dep'], 'has_peer_dependency "vue"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when peerDependencies section does not exist', () => {
      const result = runInTestDir('bash', dirs['no-peer-deps-section'], 'has_peer_dependency "react"')
      expect(result.code).toBe(1)
    })

    it('should not find dependency in peerDependencies', () => {
      const result = runInTestDir('bash', dirs['dep-not-in-peer'], 'has_peer_dependency "lodash"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['peer-dep-no-arg'], 'has_peer_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('get_js_linter_by_dep()', () => {
    it('should detect eslint in devDependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-eslint'], 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect @biomejs/biome in devDependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-biomejs'], 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('biome')
    })

    it('should detect biome (unscoped) in devDependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-biome-unscoped'], 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('biome')
    })

    it('should detect oxlint in devDependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-oxlint'], 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })

    it('should detect tsslint in devDependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-tsslint'], 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('tsslint')
    })

    it('should return 1 when no linter is found', () => {
      const result = runInTestDir('bash', dirs['linter-dep-none'], 'get_js_linter_by_dep')
      expect(result.code).toBe(1)
    })

    it('should prioritize oxlint over other linters', () => {
      const result = runInTestDir('bash', dirs['linter-dep-priority'], 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })
  })

  describe('packages_not_installed()', () => {
    describe('basic functionality', () => {
      it('should return packages not in any dependency section', () => {
        const result = runInTestDir('bash', dirs['pkgs-not-installed-basic'], 'packages_not_installed "express" "react" "vue"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['express', 'react', 'vue'])
      })

      it('should return empty when all packages are installed', () => {
        const result = runInTestDir('bash', dirs['pkgs-all-installed'], 'packages_not_installed "lodash" "express" "vitest"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })

      it('should return all packages when none are installed', () => {
        const result = runInTestDir('bash', dirs['pkgs-none-installed'], 'packages_not_installed "lodash" "express" "vitest"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['lodash', 'express', 'vitest'])
      })
    })

    describe('dependency section coverage', () => {
      it('should filter out packages in dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-deps'], 'packages_not_installed "lodash" "express" "react"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['react'])
      })

      it('should filter out packages in devDependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-devdeps'], 'packages_not_installed "vitest" "typescript" "eslint"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['eslint'])
      })

      it('should filter out packages in peerDependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-peerdeps'], 'packages_not_installed "react" "react-dom" "vue"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['vue'])
      })

      it('should handle packages mixed across all sections', () => {
        const result = runInTestDir('bash', dirs['pkgs-mixed-sections'], 'packages_not_installed "lodash" "vitest" "react" "express" "vue"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['express', 'vue'])
      })
    })

    describe('input handling', () => {
      it('should handle single package argument', () => {
        const result = runInTestDir('bash', dirs['pkgs-single-arg'], 'packages_not_installed "express"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('express')
      })

      it('should handle multiple package arguments', () => {
        const result = runInTestDir('bash', dirs['pkgs-multi-args'], 'packages_not_installed "express" "react" "vue"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['express', 'react', 'vue'])
      })

      it('should handle pass-by-reference (array name) and modify in-place', () => {
        const script = `
          declare -a my_packages=("lodash" "express" "react")
          packages_not_installed my_packages
          echo "\${my_packages[@]}"
        `
        const result = runInTestDir('bash', dirs['pkgs-by-ref'], script)
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('express react')
      })

      it('should return empty output for empty input', () => {
        const result = runInTestDir('bash', dirs['pkgs-empty-input'], 'packages_not_installed')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })
    })

    describe('edge cases', () => {
      it('should handle scoped packages', () => {
        const result = runInTestDir('bash', dirs['pkgs-scoped'], 'packages_not_installed "@biomejs/biome" "@typescript-eslint/parser" "react"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['@typescript-eslint/parser', 'react'])
      })

      it('should handle package.json with no dependency sections', () => {
        const result = runInTestDir('bash', dirs['pkgs-no-dep-sections'], 'packages_not_installed "lodash" "express"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['lodash', 'express'])
      })
    })

    describe('output format', () => {
      it('should preserve input order in output', () => {
        const result = runInTestDir('bash', dirs['pkgs-order'], 'packages_not_installed "zebra" "apple" "mango" "zlib"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['zebra', 'apple', 'mango'])
      })
    })
  })
})
