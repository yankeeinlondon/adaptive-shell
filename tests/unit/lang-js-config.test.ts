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

describe("get_js_linter_by_config_file()", () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-lang-js-config-test')

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

  describe('ESLint detection', () => {
    it('should detect flat config eslint.config.js', () => {
      const eslintDir = join(testDir, 'eslint-flat-js')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'eslint.config.js'), 'export default []')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect flat config eslint.config.mjs', () => {
      const eslintDir = join(testDir, 'eslint-flat-mjs')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'eslint.config.mjs'), 'export default []')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect flat config eslint.config.cjs', () => {
      const eslintDir = join(testDir, 'eslint-flat-cjs')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'eslint.config.cjs'), 'module.exports = []')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect flat config eslint.config.ts', () => {
      const eslintDir = join(testDir, 'eslint-flat-ts')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'eslint.config.ts'), 'export default []')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect flat config eslint.config.mts', () => {
      const eslintDir = join(testDir, 'eslint-flat-mts')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'eslint.config.mts'), 'export default []')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect flat config eslint.config.cts', () => {
      const eslintDir = join(testDir, 'eslint-flat-cts')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, 'eslint.config.cts'), 'export default []')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect legacy config .eslintrc.js', () => {
      const eslintDir = join(testDir, 'eslint-legacy-js')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, '.eslintrc.js'), 'module.exports = {}')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect legacy config .eslintrc.cjs', () => {
      const eslintDir = join(testDir, 'eslint-legacy-cjs')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, '.eslintrc.cjs'), 'module.exports = {}')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect legacy config .eslintrc.yaml', () => {
      const eslintDir = join(testDir, 'eslint-legacy-yaml')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, '.eslintrc.yaml'), 'extends: eslint:recommended')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect legacy config .eslintrc.yml', () => {
      const eslintDir = join(testDir, 'eslint-legacy-yml')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, '.eslintrc.yml'), 'extends: eslint:recommended')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect legacy config .eslintrc.json', () => {
      const eslintDir = join(testDir, 'eslint-legacy-json')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, '.eslintrc.json'), '{"extends": "eslint:recommended"}')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should detect legacy config .eslintrc', () => {
      const eslintDir = join(testDir, 'eslint-legacy-rc')
      mkdirSync(eslintDir, { recursive: true })
      writeFileSync(join(eslintDir, '.eslintrc'), '{"extends": "eslint:recommended"}')

      const result = runInTestDir('bash', eslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })
  })

  describe('Biome detection', () => {
    it('should detect biome.json', () => {
      const biomeDir = join(testDir, 'biome-json')
      mkdirSync(biomeDir, { recursive: true })
      writeFileSync(join(biomeDir, 'biome.json'), '{"linter": {"enabled": true}}')

      const result = runInTestDir('bash', biomeDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('biome')
    })

    it('should detect biome.jsonc', () => {
      const biomeDir = join(testDir, 'biome-jsonc')
      mkdirSync(biomeDir, { recursive: true })
      writeFileSync(join(biomeDir, 'biome.jsonc'), '{"linter": {"enabled": true}}')

      const result = runInTestDir('bash', biomeDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('biome')
    })
  })

  describe('Oxlint detection', () => {
    it('should detect .oxlintrc.json', () => {
      const oxlintDir = join(testDir, 'oxlint-rc')
      mkdirSync(oxlintDir, { recursive: true })
      writeFileSync(join(oxlintDir, '.oxlintrc.json'), '{"rules": {}}')

      const result = runInTestDir('bash', oxlintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })

    it('should detect oxlint.json', () => {
      const oxlintDir = join(testDir, 'oxlint-json')
      mkdirSync(oxlintDir, { recursive: true })
      writeFileSync(join(oxlintDir, 'oxlint.json'), '{"rules": {}}')

      const result = runInTestDir('bash', oxlintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })
  })

  describe('TSLint detection (deprecated)', () => {
    it('should detect tslint.json', () => {
      const tslintDir = join(testDir, 'tslint-json')
      mkdirSync(tslintDir, { recursive: true })
      writeFileSync(join(tslintDir, 'tslint.json'), '{"extends": "tslint:recommended"}')

      const result = runInTestDir('bash', tslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('tslint')
    })

    it('should detect tslint.yaml', () => {
      const tslintDir = join(testDir, 'tslint-yaml')
      mkdirSync(tslintDir, { recursive: true })
      writeFileSync(join(tslintDir, 'tslint.yaml'), 'extends: tslint:recommended')

      const result = runInTestDir('bash', tslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('tslint')
    })

    it('should detect tslint.yml', () => {
      const tslintDir = join(testDir, 'tslint-yml')
      mkdirSync(tslintDir, { recursive: true })
      writeFileSync(join(tslintDir, 'tslint.yml'), 'extends: tslint:recommended')

      const result = runInTestDir('bash', tslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('tslint')
    })
  })

  describe('TSSLint detection', () => {
    it('should detect tsslint.config.ts', () => {
      const tsslintDir = join(testDir, 'tsslint-ts')
      mkdirSync(tsslintDir, { recursive: true })
      writeFileSync(join(tsslintDir, 'tsslint.config.ts'), 'export default {}')

      const result = runInTestDir('bash', tsslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('tsslint')
    })

    it('should detect tsslint.config.js', () => {
      const tsslintDir = join(testDir, 'tsslint-js')
      mkdirSync(tsslintDir, { recursive: true })
      writeFileSync(join(tsslintDir, 'tsslint.config.js'), 'module.exports = {}')

      const result = runInTestDir('bash', tsslintDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('tsslint')
    })
  })

  describe('Priority order', () => {
    it('should prefer oxlint over eslint when both configs exist', () => {
      const mixedDir = join(testDir, 'priority-oxlint-eslint')
      mkdirSync(mixedDir, { recursive: true })
      writeFileSync(join(mixedDir, 'oxlint.json'), '{"rules": {}}')
      writeFileSync(join(mixedDir, 'eslint.config.js'), 'export default []')

      const result = runInTestDir('bash', mixedDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })

    it('should prefer oxlint over biome when both configs exist', () => {
      const mixedDir = join(testDir, 'priority-oxlint-biome')
      mkdirSync(mixedDir, { recursive: true })
      writeFileSync(join(mixedDir, 'oxlint.json'), '{"rules": {}}')
      writeFileSync(join(mixedDir, 'biome.json'), '{"linter": {"enabled": true}}')

      const result = runInTestDir('bash', mixedDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })

    it('should prefer eslint over biome when both configs exist', () => {
      const mixedDir = join(testDir, 'priority-eslint-biome')
      mkdirSync(mixedDir, { recursive: true })
      writeFileSync(join(mixedDir, '.eslintrc.json'), '{"extends": "eslint:recommended"}')
      writeFileSync(join(mixedDir, 'biome.json'), '{"linter": {"enabled": true}}')

      const result = runInTestDir('bash', mixedDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should prefer biome over tsslint when both configs exist', () => {
      const mixedDir = join(testDir, 'priority-biome-tsslint')
      mkdirSync(mixedDir, { recursive: true })
      writeFileSync(join(mixedDir, 'biome.json'), '{"linter": {"enabled": true}}')
      writeFileSync(join(mixedDir, 'tsslint.config.ts'), 'export default {}')

      const result = runInTestDir('bash', mixedDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('biome')
    })

    it('should prefer tsslint over tslint when both configs exist', () => {
      const mixedDir = join(testDir, 'priority-tsslint-tslint')
      mkdirSync(mixedDir, { recursive: true })
      writeFileSync(join(mixedDir, 'tsslint.config.ts'), 'export default {}')
      writeFileSync(join(mixedDir, 'tslint.json'), '{"extends": "tslint:recommended"}')

      const result = runInTestDir('bash', mixedDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('tsslint')
    })
  })

  describe('Repo root fallback', () => {
    it('should find config in repo root when not in CWD', () => {
      const repoDir = join(testDir, 'repo-root-test')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'eslint.config.js'), 'export default []')
      commitFile(repoDir, 'eslint.config.js', 'export default []', 'add eslint config')

      const result = runInTestDir('bash', subDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should prefer CWD config over repo root config', () => {
      const repoDir = join(testDir, 'prefer-cwd-test')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'biome.json'), '{"linter": {"enabled": true}}')
      writeFileSync(join(subDir, 'eslint.config.js'), 'export default []')
      commitFile(repoDir, 'biome.json', '{"linter": {"enabled": true}}', 'add biome config')

      const result = runInTestDir('bash', subDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })

    it('should work when CWD is the repo root', () => {
      const repoDir = join(testDir, 'cwd-is-root')
      mkdirSync(repoDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'oxlint.json'), '{"rules": {}}')
      commitFile(repoDir, 'oxlint.json', '{"rules": {}}', 'add oxlint config')

      const result = runInTestDir('bash', repoDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('oxlint')
    })

    it('should only check CWD when not in a git repo', () => {
      const nonRepoDir = join(testDir, 'non-repo-with-config')
      mkdirSync(nonRepoDir, { recursive: true })
      writeFileSync(join(nonRepoDir, 'eslint.config.js'), 'export default []')

      const result = runInTestDir('bash', nonRepoDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })
  })

  describe('No config found', () => {
    it('should return 1 when no linter config exists', () => {
      const emptyDir = join(testDir, 'no-config')
      mkdirSync(emptyDir, { recursive: true })
      writeFileSync(join(emptyDir, 'package.json'), '{"name": "test"}')

      const result = runInTestDir('bash', emptyDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(1)
    })

    it('should return 1 when in subdirectory and no config in repo root either', () => {
      const repoDir = join(testDir, 'no-config-repo')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'package.json'), '{"name": "monorepo"}')
      commitFile(repoDir, 'package.json', '{"name": "monorepo"}', 'init')

      const result = runInTestDir('bash', subDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(1)
    })
  })

  describe('Edge cases', () => {
    it('should handle empty directory gracefully', () => {
      const emptyDir = join(testDir, 'empty-dir')
      mkdirSync(emptyDir, { recursive: true })

      const result = runInTestDir('bash', emptyDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(1)
    })

    it('should ignore config-like files with wrong names', () => {
      const wrongNameDir = join(testDir, 'wrong-names')
      mkdirSync(wrongNameDir, { recursive: true })
      writeFileSync(join(wrongNameDir, 'eslint-config.js'), 'export default []')  // Wrong name
      writeFileSync(join(wrongNameDir, 'my-eslint.config.js'), 'export default []')  // Wrong prefix

      const result = runInTestDir('bash', wrongNameDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(1)
    })

    it('should detect config even if file is empty', () => {
      const emptyConfigDir = join(testDir, 'empty-config')
      mkdirSync(emptyConfigDir, { recursive: true })
      writeFileSync(join(emptyConfigDir, 'eslint.config.js'), '')  // Empty file

      const result = runInTestDir('bash', emptyConfigDir, 'get_js_linter_by_config_file')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('eslint')
    })
  })
})
