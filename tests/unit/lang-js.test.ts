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
    source "${PROJECT_ROOT}/utils/lang-js.sh"
    ${script}
  `, { cwd: testDir })
}

describe("lang-js", () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-lang-js-test')

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

  describe('js_package_manager()', () => {
    it('should return "pnpm" when pnpm-lock.yaml exists', () => {
      const pnpmDir = join(testDir, 'pnpm-project')
      mkdirSync(pnpmDir, { recursive: true })
      writeFileSync(join(pnpmDir, 'package.json'), '{"name": "test"}')
      writeFileSync(join(pnpmDir, 'pnpm-lock.yaml'), 'lockfileVersion: 6.0')

      const result = runInTestDir('bash', pnpmDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pnpm')
    })

    it('should return "pnpm" when pnpm-workspace.yaml exists', () => {
      const pnpmDir = join(testDir, 'pnpm-workspace-project')
      mkdirSync(pnpmDir, { recursive: true })
      writeFileSync(join(pnpmDir, 'package.json'), '{"name": "test"}')
      writeFileSync(join(pnpmDir, 'pnpm-workspace.yaml'), 'packages:\n  - "packages/*"')

      const result = runInTestDir('bash', pnpmDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pnpm')
    })

    it('should return "npm" when package-lock.json exists', () => {
      const npmDir = join(testDir, 'npm-project')
      mkdirSync(npmDir, { recursive: true })
      writeFileSync(join(npmDir, 'package.json'), '{"name": "test"}')
      writeFileSync(join(npmDir, 'package-lock.json'), '{"lockfileVersion": 2}')

      const result = runInTestDir('bash', npmDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('npm')
    })

    it('should return "yarn" when yarn.lock exists', () => {
      const yarnDir = join(testDir, 'yarn-project')
      mkdirSync(yarnDir, { recursive: true })
      writeFileSync(join(yarnDir, 'package.json'), '{"name": "test"}')
      writeFileSync(join(yarnDir, 'yarn.lock'), '# yarn lockfile v1')

      const result = runInTestDir('bash', yarnDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('yarn')
    })

    it('should return "bun" when bun.lockb exists', () => {
      const bunDir = join(testDir, 'bun-project')
      mkdirSync(bunDir, { recursive: true })
      writeFileSync(join(bunDir, 'package.json'), '{"name": "test"}')
      writeFileSync(join(bunDir, 'bun.lockb'), 'binary-content')

      const result = runInTestDir('bash', bunDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('bun')
    })

    it('should return "deno" when deno.lock exists', () => {
      const denoDir = join(testDir, 'deno-project')
      mkdirSync(denoDir, { recursive: true })
      writeFileSync(join(denoDir, 'package.json'), '{"name": "test"}')
      writeFileSync(join(denoDir, 'deno.lock'), '{"version": "2"}')

      const result = runInTestDir('bash', denoDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('deno')
    })

    it('should return success with empty output when package.json exists but no lock file', () => {
      const jsDir = join(testDir, 'js-no-lock')
      mkdirSync(jsDir, { recursive: true })
      writeFileSync(join(jsDir, 'package.json'), '{"name": "test"}')

      const result = runInTestDir('bash', jsDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('')
    })

    it('should return 1 when not a JS project', () => {
      const tmpNonJsDir = `/tmp/pkg-mgr-nojs-${Date.now()}`
      mkdirSync(tmpNonJsDir, { recursive: true })
      writeFileSync(join(tmpNonJsDir, 'readme.txt'), 'not a js project')

      try {
        const result = runInTestDir('bash', tmpNonJsDir, 'js_package_manager')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpNonJsDir, { recursive: true, force: true })
      }
    })

    it('should detect package manager from repo root when in subdirectory', () => {
      const repoDir = join(testDir, 'pkg-mgr-subdir-test')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'package.json'), '{"name": "monorepo"}')
      writeFileSync(join(repoDir, 'pnpm-lock.yaml'), 'lockfileVersion: 6.0')
      commitFile(repoDir, 'package.json', '{"name": "monorepo"}', 'init')

      const result = runInTestDir('bash', subDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pnpm')
    })

    it('should prioritize pnpm over npm when both lock files exist', () => {
      // This tests the order of checks in the function
      const mixedDir = join(testDir, 'mixed-locks')
      mkdirSync(mixedDir, { recursive: true })
      writeFileSync(join(mixedDir, 'package.json'), '{"name": "test"}')
      writeFileSync(join(mixedDir, 'pnpm-lock.yaml'), 'lockfileVersion: 6.0')
      writeFileSync(join(mixedDir, 'package-lock.json'), '{"lockfileVersion": 2}')

      const result = runInTestDir('bash', mixedDir, 'js_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pnpm')
    })
  })

  describe('get_package_json()', () => {
    it('should return package.json content from current directory', () => {
      const pkgDir = join(testDir, 'pkg-json-cwd')
      mkdirSync(pkgDir, { recursive: true })
      const pkgContent = '{"name": "test-pkg", "version": "1.0.0"}'
      writeFileSync(join(pkgDir, 'package.json'), pkgContent)

      const result = runInTestDir('bash', pkgDir, 'get_package_json')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(pkgContent)
    })

    it('should return package.json content from repo root when not in cwd', () => {
      const repoDir = join(testDir, 'pkg-json-repo-root')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      const pkgContent = '{"name": "root-pkg", "version": "2.0.0"}'
      writeFileSync(join(repoDir, 'package.json'), pkgContent)
      commitFile(repoDir, 'package.json', pkgContent, 'init')

      const result = runInTestDir('bash', subDir, 'get_package_json')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(pkgContent)
    })

    it('should return 1 when no package.json exists', () => {
      const tmpEmptyDir = `/tmp/pkg-json-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })
      writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'no package.json here')

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'get_package_json')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })

    it('should prefer cwd package.json over repo root', () => {
      const repoDir = join(testDir, 'pkg-json-prefer-cwd')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)

      const rootPkg = '{"name": "root-pkg"}'
      const subPkg = '{"name": "sub-pkg"}'
      writeFileSync(join(repoDir, 'package.json'), rootPkg)
      writeFileSync(join(subDir, 'package.json'), subPkg)
      commitFile(repoDir, 'package.json', rootPkg, 'init')

      const result = runInTestDir('bash', subDir, 'get_package_json')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(subPkg)
    })

    it('should handle package.json with special characters', () => {
      const pkgDir = join(testDir, 'pkg-json-special')
      mkdirSync(pkgDir, { recursive: true })
      const pkgContent = '{"name": "test", "description": "A \\"quoted\\" value"}'
      writeFileSync(join(pkgDir, 'package.json'), pkgContent)

      const result = runInTestDir('bash', pkgDir, 'get_package_json')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(pkgContent)
    })
  })

  describe('has_dev_dependency()', () => {
    it('should return 0 when devDependency exists', () => {
      const pkgDir = join(testDir, 'has-dev-dep')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: {
          "vitest": "^1.0.0",
          "typescript": "^5.0.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_dev_dependency "vitest"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when devDependency does not exist', () => {
      const pkgDir = join(testDir, 'no-dev-dep')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: {
          "vitest": "^1.0.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_dev_dependency "jest"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when devDependencies section does not exist', () => {
      const pkgDir = join(testDir, 'no-dev-deps-section')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        dependencies: {
          "lodash": "^4.0.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_dev_dependency "vitest"')
      expect(result.code).toBe(1)
    })

    it('should not find dependency in wrong section', () => {
      const pkgDir = join(testDir, 'dep-wrong-section')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        dependencies: {
          "lodash": "^4.0.0"
        },
        devDependencies: {}
      }))

      // lodash is in dependencies, not devDependencies
      const result = runInTestDir('bash', pkgDir, 'has_dev_dependency "lodash"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const pkgDir = join(testDir, 'dev-dep-no-arg')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), '{"name": "test"}')

      const result = runInTestDir('bash', pkgDir, 'has_dev_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dependency()', () => {
    it('should return 0 when dependency exists', () => {
      const pkgDir = join(testDir, 'has-dep')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        dependencies: {
          "lodash": "^4.0.0",
          "express": "^4.18.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_dependency "lodash"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency does not exist', () => {
      const pkgDir = join(testDir, 'no-dep')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        dependencies: {
          "lodash": "^4.0.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_dependency "express"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when dependencies section does not exist', () => {
      const pkgDir = join(testDir, 'no-deps-section')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: {
          "vitest": "^1.0.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_dependency "lodash"')
      expect(result.code).toBe(1)
    })

    it('should not find devDependency in dependencies', () => {
      const pkgDir = join(testDir, 'dev-not-in-deps')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        dependencies: {},
        devDependencies: {
          "vitest": "^1.0.0"
        }
      }))

      // vitest is in devDependencies, not dependencies
      const result = runInTestDir('bash', pkgDir, 'has_dependency "vitest"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const pkgDir = join(testDir, 'dep-no-arg')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), '{"name": "test"}')

      const result = runInTestDir('bash', pkgDir, 'has_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_peer_dependency()', () => {
    it('should return 0 when peerDependency exists', () => {
      const pkgDir = join(testDir, 'has-peer-dep')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        peerDependencies: {
          "react": "^18.0.0",
          "react-dom": "^18.0.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_peer_dependency "react"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when peerDependency does not exist', () => {
      const pkgDir = join(testDir, 'no-peer-dep')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        peerDependencies: {
          "react": "^18.0.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_peer_dependency "vue"')
      expect(result.code).toBe(1)
    })

    it('should return 1 when peerDependencies section does not exist', () => {
      const pkgDir = join(testDir, 'no-peer-deps-section')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        dependencies: {
          "lodash": "^4.0.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'has_peer_dependency "react"')
      expect(result.code).toBe(1)
    })

    it('should not find dependency in peerDependencies', () => {
      const pkgDir = join(testDir, 'dep-not-in-peer')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        dependencies: {
          "lodash": "^4.0.0"
        },
        peerDependencies: {}
      }))

      // lodash is in dependencies, not peerDependencies
      const result = runInTestDir('bash', pkgDir, 'has_peer_dependency "lodash"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const pkgDir = join(testDir, 'peer-dep-no-arg')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), '{"name": "test"}')

      const result = runInTestDir('bash', pkgDir, 'has_peer_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('get_js_linter_by_dep()', () => {
    it('should detect eslint in devDependencies', () => {
      const pkgDir = join(testDir, 'linter-dep-eslint')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "eslint": "^8.0.0" }
      }))

      const result = runInTestDir('bash', pkgDir, 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect @biomejs/biome in devDependencies', () => {
      const pkgDir = join(testDir, 'linter-dep-biomejs')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "@biomejs/biome": "^1.9.0" }
      }))

      const result = runInTestDir('bash', pkgDir, 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('biome')
    })

    it('should detect biome (unscoped) in devDependencies', () => {
      const pkgDir = join(testDir, 'linter-dep-biome-unscoped')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "biome": "^1.0.0" }
      }))

      const result = runInTestDir('bash', pkgDir, 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('biome')
    })

    it('should detect oxlint in devDependencies', () => {
      const pkgDir = join(testDir, 'linter-dep-oxlint')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "oxlint": "^0.1.0" }
      }))

      const result = runInTestDir('bash', pkgDir, 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })

    it('should detect tsslint in devDependencies', () => {
      const pkgDir = join(testDir, 'linter-dep-tsslint')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "tsslint": "^1.0.0" }
      }))

      const result = runInTestDir('bash', pkgDir, 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('tsslint')
    })

    it('should return 1 when no linter is found', () => {
      const pkgDir = join(testDir, 'linter-dep-none')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "vitest": "^1.0.0" }
      }))

      const result = runInTestDir('bash', pkgDir, 'get_js_linter_by_dep')
      expect(result.code).toBe(1)
    })

    it('should prioritize oxlint over other linters', () => {
      const pkgDir = join(testDir, 'linter-dep-priority')
      mkdirSync(pkgDir, { recursive: true })
      writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: {
          "@biomejs/biome": "^1.9.0",
          "eslint": "^8.0.0",
          "oxlint": "^0.1.0"
        }
      }))

      const result = runInTestDir('bash', pkgDir, 'get_js_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })
  })

  describe('packages_not_installed()', () => {
    describe('basic functionality', () => {
      it('should return packages not in any dependency section', () => {
        const pkgDir = join(testDir, 'pkgs-not-installed-basic')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {
            "lodash": "^4.0.0"
          },
          devDependencies: {
            "vitest": "^1.0.0"
          }
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "express" "react" "vue"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['express', 'react', 'vue'])
      })

      it('should return empty when all packages are installed', () => {
        const pkgDir = join(testDir, 'pkgs-all-installed')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {
            "lodash": "^4.0.0",
            "express": "^4.0.0"
          },
          devDependencies: {
            "vitest": "^1.0.0"
          }
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "lodash" "express" "vitest"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })

      it('should return all packages when none are installed', () => {
        const pkgDir = join(testDir, 'pkgs-none-installed')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {},
          devDependencies: {}
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "lodash" "express" "vitest"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['lodash', 'express', 'vitest'])
      })
    })

    describe('dependency section coverage', () => {
      it('should filter out packages in dependencies', () => {
        const pkgDir = join(testDir, 'pkgs-in-deps')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {
            "lodash": "^4.0.0",
            "express": "^4.0.0"
          }
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "lodash" "express" "react"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['react'])
      })

      it('should filter out packages in devDependencies', () => {
        const pkgDir = join(testDir, 'pkgs-in-devdeps')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          devDependencies: {
            "vitest": "^1.0.0",
            "typescript": "^5.0.0"
          }
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "vitest" "typescript" "eslint"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['eslint'])
      })

      it('should filter out packages in peerDependencies', () => {
        const pkgDir = join(testDir, 'pkgs-in-peerdeps')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          peerDependencies: {
            "react": "^18.0.0",
            "react-dom": "^18.0.0"
          }
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "react" "react-dom" "vue"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['vue'])
      })

      it('should handle packages mixed across all sections', () => {
        const pkgDir = join(testDir, 'pkgs-mixed-sections')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {
            "lodash": "^4.0.0"
          },
          devDependencies: {
            "vitest": "^1.0.0"
          },
          peerDependencies: {
            "react": "^18.0.0"
          }
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "lodash" "vitest" "react" "express" "vue"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['express', 'vue'])
      })
    })

    describe('input handling', () => {
      it('should handle single package argument', () => {
        const pkgDir = join(testDir, 'pkgs-single-arg')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {}
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "express"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('express')
      })

      it('should handle multiple package arguments', () => {
        const pkgDir = join(testDir, 'pkgs-multi-args')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {}
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "express" "react" "vue"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['express', 'react', 'vue'])
      })

      it('should handle pass-by-reference (array name) and modify in-place', () => {
        const pkgDir = join(testDir, 'pkgs-by-ref')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {
            "lodash": "^4.0.0"
          }
        }))

        // Pass-by-reference should modify array in-place, not output to stdout
        const script = `
          declare -a my_packages=("lodash" "express" "react")
          packages_not_installed my_packages
          echo "\${my_packages[@]}"
        `
        const result = runInTestDir('bash', pkgDir, script)
        expect(result.code).toBe(0)
        // Array should now only contain not-installed packages
        expect(result.stdout).toBe('express react')
      })

      it('should return empty output for empty input', () => {
        const pkgDir = join(testDir, 'pkgs-empty-input')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {}
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })
    })

    describe('edge cases', () => {
      it('should handle scoped packages', () => {
        const pkgDir = join(testDir, 'pkgs-scoped')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          devDependencies: {
            "@biomejs/biome": "^1.9.0"
          }
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "@biomejs/biome" "@typescript-eslint/parser" "react"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['@typescript-eslint/parser', 'react'])
      })

      it('should handle no package.json file', () => {
        const tmpEmptyDir = `/tmp/pkgs-no-pkgjson-${Date.now()}`
        mkdirSync(tmpEmptyDir, { recursive: true })
        writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'no package.json')

        try {
          const result = runInTestDir('bash', tmpEmptyDir, 'packages_not_installed "lodash" "express"')
          // Should return all packages as not installed (or error)
          // Implementation may choose to return error or treat as "all not installed"
          if (result.code === 0) {
            const lines = result.stdout.trim().split('\n').filter(l => l)
            expect(lines).toEqual(['lodash', 'express'])
          } else {
            // Error is also acceptable behavior
            expect(result.code).not.toBe(0)
          }
        } finally {
          rmSync(tmpEmptyDir, { recursive: true, force: true })
        }
      })

      it('should handle package.json with no dependency sections', () => {
        const pkgDir = join(testDir, 'pkgs-no-dep-sections')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          version: "1.0.0"
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "lodash" "express"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['lodash', 'express'])
      })
    })

    describe('output format', () => {
      it('should preserve input order in output', () => {
        const pkgDir = join(testDir, 'pkgs-order')
        mkdirSync(pkgDir, { recursive: true })
        writeFileSync(join(pkgDir, 'package.json'), JSON.stringify({
          name: "test",
          dependencies: {
            "zlib": "^1.0.0"
          }
        }))

        const result = runInTestDir('bash', pkgDir, 'packages_not_installed "zebra" "apple" "mango" "zlib"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['zebra', 'apple', 'mango'])
      })
    })
  })
})
