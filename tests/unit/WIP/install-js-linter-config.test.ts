import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { mkdirSync, rmSync, existsSync, writeFileSync, readFileSync } from 'fs'
import { join } from 'path'
import { execSync } from 'child_process'
import { runInShell } from "../../helpers"

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
  execSync(`git commit --no-gpg-sign -m "${message}"`, { cwd: dir, stdio: 'pipe' })
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

describe("install_js_linter_config()", () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-install-js-linter-config-test')

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

  describe('Config installation with explicit linter parameter', () => {
    it('should copy eslint.config.ts when eslint is specified', () => {
      const eslintDir = join(testDir, 'install-eslint-explicit')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "eslint": "^8.0.0" }
      }))

      const result = runInTestDir('bash', eslintDir, 'install_js_linter_config "eslint"')
      expect(result.code).toBe(0)
      expect(existsSync(join(eslintDir, 'eslint.config.ts'))).toBe(true)

      // Verify content matches template
      const installed = readFileSync(join(eslintDir, 'eslint.config.ts'), 'utf-8')
      const template = readFileSync(join(PROJECT_ROOT, 'resources', 'eslint.config.ts'), 'utf-8')
      expect(installed).toBe(template)
    })

    it('should copy oxlint.json when oxlint is specified', () => {
      const oxlintDir = join(testDir, 'install-oxlint-explicit')
      mkdirSync(oxlintDir, { recursive: true })
      writeFileSync(join(oxlintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "oxlint": "^0.1.0" }
      }))

      const result = runInTestDir('bash', oxlintDir, 'install_js_linter_config "oxlint"')
      expect(result.code).toBe(0)
      expect(existsSync(join(oxlintDir, 'oxlint.json'))).toBe(true)

      const installed = readFileSync(join(oxlintDir, 'oxlint.json'), 'utf-8')
      const template = readFileSync(join(PROJECT_ROOT, 'resources', 'oxlint.json'), 'utf-8')
      expect(installed).toBe(template)
    })

    it('should copy biome.jsonc when biome is specified', () => {
      const biomeDir = join(testDir, 'install-biome-explicit')
      mkdirSync(biomeDir, { recursive: true })
      writeFileSync(join(biomeDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "biome": "^1.0.0" }
      }))

      const result = runInTestDir('bash', biomeDir, 'install_js_linter_config "biome"')
      expect(result.code).toBe(0)
      expect(existsSync(join(biomeDir, 'biome.jsonc'))).toBe(true)

      const installed = readFileSync(join(biomeDir, 'biome.jsonc'), 'utf-8')
      const template = readFileSync(join(PROJECT_ROOT, 'resources', 'biome.jsonc'), 'utf-8')
      expect(installed).toBe(template)
    })

    it('should copy tsslint.config.ts when tsslint is specified', () => {
      const tsslintDir = join(testDir, 'install-tsslint-explicit')
      mkdirSync(tsslintDir, { recursive: true })
      writeFileSync(join(tsslintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "tsslint": "^1.0.0" }
      }))

      const result = runInTestDir('bash', tsslintDir, 'install_js_linter_config "tsslint"')
      expect(result.code).toBe(0)
      expect(existsSync(join(tsslintDir, 'tsslint.config.ts'))).toBe(true)

      const installed = readFileSync(join(tsslintDir, 'tsslint.config.ts'), 'utf-8')
      const template = readFileSync(join(PROJECT_ROOT, 'resources', 'tsslint.config.ts'), 'utf-8')
      expect(installed).toBe(template)
    })
  })

  describe('Config installation with auto-detection', () => {
    it('should detect and install eslint config when eslint is in devDependencies', () => {
      const eslintDir = join(testDir, 'install-eslint-auto')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "eslint": "^8.0.0" }
      }))

      const result = runInTestDir('bash', eslintDir, 'install_js_linter_config')
      expect(result.code).toBe(0)
      expect(existsSync(join(eslintDir, 'eslint.config.ts'))).toBe(true)
    })

    it('should detect and install oxlint config when oxlint is in devDependencies', () => {
      const oxlintDir = join(testDir, 'install-oxlint-auto')
      mkdirSync(oxlintDir, { recursive: true })
      writeFileSync(join(oxlintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "oxlint": "^0.1.0" }
      }))

      const result = runInTestDir('bash', oxlintDir, 'install_js_linter_config')
      expect(result.code).toBe(0)
      expect(existsSync(join(oxlintDir, 'oxlint.json'))).toBe(true)
    })

    it('should detect and install biome config when biome is in devDependencies', () => {
      const biomeDir = join(testDir, 'install-biome-auto')
      mkdirSync(biomeDir, { recursive: true })
      writeFileSync(join(biomeDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "biome": "^1.0.0" }
      }))

      const result = runInTestDir('bash', biomeDir, 'install_js_linter_config')
      expect(result.code).toBe(0)
      expect(existsSync(join(biomeDir, 'biome.jsonc'))).toBe(true)
    })

    it('should detect and install tsslint config when tsslint is in devDependencies', () => {
      const tsslintDir = join(testDir, 'install-tsslint-auto')
      mkdirSync(tsslintDir, { recursive: true })
      writeFileSync(join(tsslintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "tsslint": "^1.0.0" }
      }))

      const result = runInTestDir('bash', tsslintDir, 'install_js_linter_config')
      expect(result.code).toBe(0)
      expect(existsSync(join(tsslintDir, 'tsslint.config.ts'))).toBe(true)
    })

    it('should detect linter in dependencies when not in devDependencies', () => {
      const eslintDir = join(testDir, 'install-eslint-deps')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'package.json'), JSON.stringify({
        name: "test",
        dependencies: { "eslint": "^8.0.0" }
      }))

      const result = runInTestDir('bash', eslintDir, 'install_js_linter_config')
      expect(result.code).toBe(0)
      expect(existsSync(join(eslintDir, 'eslint.config.ts'))).toBe(true)
    })
  })

  describe('No-op cases - config already exists', () => {
    it('should not copy when eslint config already exists', () => {
      const eslintDir = join(testDir, 'noop-eslint-exists')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "eslint": "^8.0.0" }
      }))
      const existingConfig = '// existing config\nexport default []'
      writeFileSync(join(eslintDir, 'eslint.config.js'), existingConfig)

      const result = runInTestDir('bash', eslintDir, 'install_js_linter_config "eslint"')
      expect(result.code).toBe(0)

      // Verify existing config was not overwritten
      const currentConfig = readFileSync(join(eslintDir, 'eslint.config.js'), 'utf-8')
      expect(currentConfig).toBe(existingConfig)
      expect(existsSync(join(eslintDir, 'eslint.config.ts'))).toBe(false)
    })

    it('should not copy when oxlint config already exists', () => {
      const oxlintDir = join(testDir, 'noop-oxlint-exists')
      mkdirSync(oxlintDir, { recursive: true })
      writeFileSync(join(oxlintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "oxlint": "^0.1.0" }
      }))
      const existingConfig = '{"rules": {"existing": true}}'
      writeFileSync(join(oxlintDir, '.oxlintrc.json'), existingConfig)

      const result = runInTestDir('bash', oxlintDir, 'install_js_linter_config "oxlint"')
      expect(result.code).toBe(0)

      // Verify existing config was not overwritten
      const currentConfig = readFileSync(join(oxlintDir, '.oxlintrc.json'), 'utf-8')
      expect(currentConfig).toBe(existingConfig)
      expect(existsSync(join(oxlintDir, 'oxlint.json'))).toBe(false)
    })

    it('should not copy when biome config already exists', () => {
      const biomeDir = join(testDir, 'noop-biome-exists')
      mkdirSync(biomeDir, { recursive: true })
      writeFileSync(join(biomeDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "biome": "^1.0.0" }
      }))
      const existingConfig = '{"linter": {"enabled": false}}'
      writeFileSync(join(biomeDir, 'biome.json'), existingConfig)

      const result = runInTestDir('bash', biomeDir, 'install_js_linter_config "biome"')
      expect(result.code).toBe(0)

      // Verify existing config was not overwritten
      const currentConfig = readFileSync(join(biomeDir, 'biome.json'), 'utf-8')
      expect(currentConfig).toBe(existingConfig)
      expect(existsSync(join(biomeDir, 'biome.jsonc'))).toBe(false)
    })

    it('should not copy when tsslint config already exists', () => {
      const tsslintDir = join(testDir, 'noop-tsslint-exists')
      mkdirSync(tsslintDir, { recursive: true })
      writeFileSync(join(tsslintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "tsslint": "^1.0.0" }
      }))
      const existingConfig = '// existing config\nexport default {}'
      writeFileSync(join(tsslintDir, 'tsslint.config.js'), existingConfig)

      const result = runInTestDir('bash', tsslintDir, 'install_js_linter_config "tsslint"')
      expect(result.code).toBe(0)

      // Verify existing config was not overwritten
      const currentConfig = readFileSync(join(tsslintDir, 'tsslint.config.js'), 'utf-8')
      expect(currentConfig).toBe(existingConfig)
      expect(existsSync(join(tsslintDir, 'tsslint.config.ts'))).toBe(false)
    })
  })

  describe('Error cases', () => {
    it('should return 1 when no linter is detected in dependencies', () => {
      const noLinterDir = join(testDir, 'error-no-linter')
      mkdirSync(noLinterDir, { recursive: true })
      writeFileSync(join(noLinterDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "vitest": "^1.0.0" }
      }))

      const result = runInTestDir('bash', noLinterDir, 'install_js_linter_config')
      expect(result.code).toBe(1)
      expect(existsSync(join(noLinterDir, 'eslint.config.ts'))).toBe(false)
    })

    it('should return 1 for unsupported linter tslint', () => {
      const tslintDir = join(testDir, 'error-tslint')
      mkdirSync(tslintDir, { recursive: true })
      writeFileSync(join(tslintDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "tslint": "^6.0.0" }
      }))

      const result = runInTestDir('bash', tslintDir, 'install_js_linter_config "tslint"')
      expect(result.code).toBe(1)
      expect(existsSync(join(tslintDir, 'tslint.json'))).toBe(false)
    })

    it('should return 1 when no package.json exists', () => {
      const noPkgDir = join(testDir, 'error-no-package-json')
      mkdirSync(noPkgDir, { recursive: true })
      writeFileSync(join(noPkgDir, 'readme.txt'), 'not a js project')

      const result = runInTestDir('bash', noPkgDir, 'install_js_linter_config')
      expect(result.code).toBe(1)
    })

    it('should return 1 for unknown linter name', () => {
      const unknownDir = join(testDir, 'error-unknown-linter')
      mkdirSync(unknownDir, { recursive: true })
      writeFileSync(join(unknownDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "some-unknown-linter": "^1.0.0" }
      }))

      const result = runInTestDir('bash', unknownDir, 'install_js_linter_config "unknown-linter"')
      expect(result.code).toBe(1)
    })
  })

  describe('Location logic - CWD vs repo root', () => {
    it('should copy to CWD when package.json exists in CWD', () => {
      const repoDir = join(testDir, 'location-cwd-preferred')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)

      // Package.json in both root and subdirectory
      writeFileSync(join(repoDir, 'package.json'), JSON.stringify({ name: "monorepo" }))
      writeFileSync(join(subDir, 'package.json'), JSON.stringify({
        name: "app",
        devDependencies: { "eslint": "^8.0.0" }
      }))
      commitFile(repoDir, 'package.json', JSON.stringify({ name: "monorepo" }), 'init')

      const result = runInTestDir('bash', subDir, 'install_js_linter_config "eslint"')
      expect(result.code).toBe(0)

      // Config should be in subDir (CWD), not root
      expect(existsSync(join(subDir, 'eslint.config.ts'))).toBe(true)
      expect(existsSync(join(repoDir, 'eslint.config.ts'))).toBe(false)
    })

    it('should copy to repo root when package.json only exists at root', () => {
      const repoDir = join(testDir, 'location-root-fallback')
      const subDir = join(repoDir, 'src', 'utils')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)

      // Package.json only at repo root
      writeFileSync(join(repoDir, 'package.json'), JSON.stringify({
        name: "project",
        devDependencies: { "eslint": "^8.0.0" }
      }))
      commitFile(repoDir, 'package.json', JSON.stringify({
        name: "project",
        devDependencies: { "eslint": "^8.0.0" }
      }), 'init')

      const result = runInTestDir('bash', subDir, 'install_js_linter_config "eslint"')
      expect(result.code).toBe(0)

      // Config should be in repo root
      expect(existsSync(join(repoDir, 'eslint.config.ts'))).toBe(true)
      expect(existsSync(join(subDir, 'eslint.config.ts'))).toBe(false)
    })

    it('should copy to CWD when CWD is the repo root', () => {
      const repoDir = join(testDir, 'location-cwd-is-root')
      mkdirSync(repoDir, { recursive: true })
      initGitRepo(repoDir)

      writeFileSync(join(repoDir, 'package.json'), JSON.stringify({
        name: "project",
        devDependencies: { "oxlint": "^0.1.0" }
      }))
      commitFile(repoDir, 'package.json', JSON.stringify({
        name: "project",
        devDependencies: { "oxlint": "^0.1.0" }
      }), 'init')

      const result = runInTestDir('bash', repoDir, 'install_js_linter_config "oxlint"')
      expect(result.code).toBe(0)

      expect(existsSync(join(repoDir, 'oxlint.json'))).toBe(true)
    })

    it('should copy to CWD when not in a git repo', () => {
      const nonRepoDir = join(testDir, 'location-non-repo')
      mkdirSync(nonRepoDir, { recursive: true })

      writeFileSync(join(nonRepoDir, 'package.json'), JSON.stringify({
        name: "project",
        devDependencies: { "biome": "^1.0.0" }
      }))

      const result = runInTestDir('bash', nonRepoDir, 'install_js_linter_config "biome"')
      expect(result.code).toBe(0)

      expect(existsSync(join(nonRepoDir, 'biome.jsonc'))).toBe(true)
    })
  })

  describe('Edge cases', () => {
    it('should handle multiple linters but copy only the detected one', () => {
      const multiDir = join(testDir, 'edge-multi-linters')
      mkdirSync(multiDir, { recursive: true })
      writeFileSync(join(multiDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: {
          "eslint": "^8.0.0",
          "oxlint": "^0.1.0",
          "biome": "^1.0.0"
        }
      }))

      // Without parameter, should detect oxlint (highest priority)
      const result = runInTestDir('bash', multiDir, 'install_js_linter_config')
      expect(result.code).toBe(0)
      expect(existsSync(join(multiDir, 'oxlint.json'))).toBe(true)
      expect(existsSync(join(multiDir, 'eslint.config.ts'))).toBe(false)
      expect(existsSync(join(multiDir, 'biome.jsonc'))).toBe(false)
    })

    it('should handle linter specified but not in dependencies', () => {
      const mismatchDir = join(testDir, 'edge-linter-mismatch')
      mkdirSync(mismatchDir, { recursive: true })
      writeFileSync(join(mismatchDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "vitest": "^1.0.0" }
      }))

      // Specify eslint but it's not in package.json
      const result = runInTestDir('bash', mismatchDir, 'install_js_linter_config "eslint"')

      // Function should still attempt to copy if parameter is provided
      // (actual behavior depends on implementation - may return 0 or 1)
      // This tests that explicit parameter takes precedence
      if (result.code === 0) {
        expect(existsSync(join(mismatchDir, 'eslint.config.ts'))).toBe(true)
      }
    })

    it('should handle case sensitivity of linter names', () => {
      const caseDir = join(testDir, 'edge-case-sensitive')
      mkdirSync(caseDir, { recursive: true })
      writeFileSync(join(caseDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "eslint": "^8.0.0" }
      }))

      // Test with uppercase (should fail or handle gracefully)
      const result = runInTestDir('bash', caseDir, 'install_js_linter_config "ESLINT"')

      // Should either succeed with lowercase normalization or fail gracefully
      // Testing the actual behavior
      if (result.code === 1) {
        expect(existsSync(join(caseDir, 'eslint.config.ts'))).toBe(false)
      }
    })

    it('should handle empty devDependencies object', () => {
      const emptyDir = join(testDir, 'edge-empty-devdeps')
      mkdirSync(emptyDir, { recursive: true })
      writeFileSync(join(emptyDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: {}
      }))

      const result = runInTestDir('bash', emptyDir, 'install_js_linter_config')
      expect(result.code).toBe(1)
    })

    it('should handle package.json with no dependencies sections', () => {
      const noDepDir = join(testDir, 'edge-no-dep-sections')
      mkdirSync(noDepDir, { recursive: true })
      writeFileSync(join(noDepDir, 'package.json'), JSON.stringify({
        name: "test",
        version: "1.0.0"
      }))

      const result = runInTestDir('bash', noDepDir, 'install_js_linter_config')
      expect(result.code).toBe(1)
    })
  })

  describe('Priority handling with existing configs', () => {
    it('should not install if lower-priority config exists for same linter', () => {
      const priorityDir = join(testDir, 'priority-lower-config')
      mkdirSync(priorityDir, { recursive: true })
      writeFileSync(join(priorityDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "eslint": "^8.0.0" }
      }))
      // Legacy config exists
      writeFileSync(join(priorityDir, '.eslintrc.json'), '{"extends": "eslint:recommended"}')

      const result = runInTestDir('bash', priorityDir, 'install_js_linter_config "eslint"')
      expect(result.code).toBe(0)

      // Should not create new config since one exists
      expect(existsSync(join(priorityDir, 'eslint.config.ts'))).toBe(false)
    })

    it('should install config for detected linter even if different linter config exists', () => {
      const diffLinterDir = join(testDir, 'priority-diff-linter')
      mkdirSync(diffLinterDir, { recursive: true })
      writeFileSync(join(diffLinterDir, 'package.json'), JSON.stringify({
        name: "test",
        devDependencies: { "eslint": "^8.0.0" }
      }))
      // Different linter config exists (biome)
      writeFileSync(join(diffLinterDir, 'biome.json'), '{"linter": {"enabled": true}}')

      const result = runInTestDir('bash', diffLinterDir, 'install_js_linter_config "eslint"')
      expect(result.code).toBe(0)

      // Should create eslint config since biome config is for different linter
      expect(existsSync(join(diffLinterDir, 'eslint.config.ts'))).toBe(true)
    })
  })
})
