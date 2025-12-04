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
    source "${PROJECT_ROOT}/utils/lang-py.sh"
    ${script}
  `, { cwd: testDir })
}

describe("lang-py", () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-lang-py-test')

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

  describe('py_package_manager()', () => {
    it('should return "poetry" when poetry.lock exists', () => {
      const poetryDir = join(testDir, 'poetry-project')
      mkdirSync(poetryDir, { recursive: true })
      writeFileSync(join(poetryDir, 'pyproject.toml'), '[tool.poetry]\nname = "test"')
      writeFileSync(join(poetryDir, 'poetry.lock'), '# Poetry lock file')

      const result = runInTestDir('bash', poetryDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('poetry')
    })

    it('should return "poetry" when pyproject.toml has [tool.poetry] section', () => {
      const poetryDir = join(testDir, 'poetry-no-lock')
      mkdirSync(poetryDir, { recursive: true })
      writeFileSync(join(poetryDir, 'pyproject.toml'), `
[tool.poetry]
name = "test-project"
version = "0.1.0"
`)

      const result = runInTestDir('bash', poetryDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('poetry')
    })

    it('should return "pipenv" when Pipfile.lock exists', () => {
      const pipenvDir = join(testDir, 'pipenv-project')
      mkdirSync(pipenvDir, { recursive: true })
      writeFileSync(join(pipenvDir, 'Pipfile'), '[[source]]\nurl = "https://pypi.org/simple"')
      writeFileSync(join(pipenvDir, 'Pipfile.lock'), '{"_meta": {}}')

      const result = runInTestDir('bash', pipenvDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pipenv')
    })

    it('should return "pipenv" when Pipfile exists', () => {
      const pipenvDir = join(testDir, 'pipenv-no-lock')
      mkdirSync(pipenvDir, { recursive: true })
      writeFileSync(join(pipenvDir, 'Pipfile'), '[[source]]\nurl = "https://pypi.org/simple"')

      const result = runInTestDir('bash', pipenvDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pipenv')
    })

    it('should return "uv" when uv.lock exists', () => {
      const uvDir = join(testDir, 'uv-project')
      mkdirSync(uvDir, { recursive: true })
      writeFileSync(join(uvDir, 'pyproject.toml'), '[project]\nname = "test"')
      writeFileSync(join(uvDir, 'uv.lock'), 'version = 1')

      const result = runInTestDir('bash', uvDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('uv')
    })

    it('should return "pdm" when pdm.lock exists', () => {
      const pdmDir = join(testDir, 'pdm-project')
      mkdirSync(pdmDir, { recursive: true })
      writeFileSync(join(pdmDir, 'pyproject.toml'), '[project]\nname = "test"')
      writeFileSync(join(pdmDir, 'pdm.lock'), '# PDM lock file')

      const result = runInTestDir('bash', pdmDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pdm')
    })

    it('should return "pdm" when pyproject.toml has [tool.pdm] section', () => {
      const pdmDir = join(testDir, 'pdm-no-lock')
      mkdirSync(pdmDir, { recursive: true })
      writeFileSync(join(pdmDir, 'pyproject.toml'), `
[project]
name = "test"

[tool.pdm]
`)

      const result = runInTestDir('bash', pdmDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pdm')
    })

    it('should return "hatch" when pyproject.toml has [tool.hatch] section', () => {
      const hatchDir = join(testDir, 'hatch-project')
      mkdirSync(hatchDir, { recursive: true })
      writeFileSync(join(hatchDir, 'pyproject.toml'), `
[project]
name = "test"

[tool.hatch.build]
`)

      const result = runInTestDir('bash', hatchDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('hatch')
    })

    it('should return "conda" when environment.yml exists', () => {
      const condaDir = join(testDir, 'conda-project')
      mkdirSync(condaDir, { recursive: true })
      writeFileSync(join(condaDir, 'environment.yml'), 'name: test\nchannels:\n  - conda-forge')

      const result = runInTestDir('bash', condaDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('conda')
    })

    it('should return "pip" when requirements.txt exists', () => {
      const pipDir = join(testDir, 'pip-project')
      mkdirSync(pipDir, { recursive: true })
      writeFileSync(join(pipDir, 'requirements.txt'), 'requests>=2.0.0\nclick')

      const result = runInTestDir('bash', pipDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pip')
    })

    it('should return "pip" when setup.py exists', () => {
      const pipDir = join(testDir, 'pip-setup-project')
      mkdirSync(pipDir, { recursive: true })
      writeFileSync(join(pipDir, 'setup.py'), 'from setuptools import setup\nsetup(name="test")')

      const result = runInTestDir('bash', pipDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pip')
    })

    it('should return success with empty output when pyproject.toml exists but no tool sections', () => {
      const pyDir = join(testDir, 'py-no-manager')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), '[project]\nname = "test"')

      const result = runInTestDir('bash', pyDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('')
    })

    it('should return 1 when not a Python project', () => {
      const tmpNonPyDir = `/tmp/pkg-mgr-nopy-${Date.now()}`
      mkdirSync(tmpNonPyDir, { recursive: true })
      writeFileSync(join(tmpNonPyDir, 'readme.txt'), 'not a python project')

      try {
        const result = runInTestDir('bash', tmpNonPyDir, 'py_package_manager')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpNonPyDir, { recursive: true, force: true })
      }
    })

    it('should detect package manager from repo root when in subdirectory', () => {
      const repoDir = join(testDir, 'py-pkg-mgr-subdir-test')
      const subDir = join(repoDir, 'src', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      writeFileSync(join(repoDir, 'pyproject.toml'), '[tool.poetry]\nname = "monorepo"')
      writeFileSync(join(repoDir, 'poetry.lock'), '# Poetry lock file')
      commitFile(repoDir, 'pyproject.toml', '[tool.poetry]\nname = "monorepo"', 'init')

      const result = runInTestDir('bash', subDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('poetry')
    })

    it('should prioritize uv over pip when both exist', () => {
      const mixedDir = join(testDir, 'mixed-py-managers')
      mkdirSync(mixedDir, { recursive: true })
      writeFileSync(join(mixedDir, 'pyproject.toml'), '[project]\nname = "test"')
      writeFileSync(join(mixedDir, 'uv.lock'), 'version = 1')
      writeFileSync(join(mixedDir, 'requirements.txt'), 'requests')

      const result = runInTestDir('bash', mixedDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('uv')
    })
  })

  describe('get_pyproject_toml()', () => {
    it('should return pyproject.toml content from current directory', () => {
      const pyDir = join(testDir, 'pyproject-cwd')
      mkdirSync(pyDir, { recursive: true })
      const pyprojectContent = '[project]\nname = "test-pkg"\nversion = "1.0.0"'
      writeFileSync(join(pyDir, 'pyproject.toml'), pyprojectContent)

      const result = runInTestDir('bash', pyDir, 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(pyprojectContent)
    })

    it('should return pyproject.toml content from repo root when not in cwd', () => {
      const repoDir = join(testDir, 'pyproject-repo-root')
      const subDir = join(repoDir, 'src', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      const pyprojectContent = '[project]\nname = "root-pkg"\nversion = "2.0.0"'
      writeFileSync(join(repoDir, 'pyproject.toml'), pyprojectContent)
      commitFile(repoDir, 'pyproject.toml', pyprojectContent, 'init')

      const result = runInTestDir('bash', subDir, 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(pyprojectContent)
    })

    it('should return 1 when no pyproject.toml exists', () => {
      const tmpEmptyDir = `/tmp/pyproject-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })
      writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'no pyproject.toml here')

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'get_pyproject_toml')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })

    it('should prefer cwd pyproject.toml over repo root', () => {
      const repoDir = join(testDir, 'pyproject-prefer-cwd')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)

      const rootPyproject = '[project]\nname = "root-pkg"'
      const subPyproject = '[project]\nname = "sub-pkg"'
      writeFileSync(join(repoDir, 'pyproject.toml'), rootPyproject)
      writeFileSync(join(subDir, 'pyproject.toml'), subPyproject)
      commitFile(repoDir, 'pyproject.toml', rootPyproject, 'init')

      const result = runInTestDir('bash', subDir, 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(subPyproject)
    })

    it('should handle pyproject.toml with special characters', () => {
      const pyDir = join(testDir, 'pyproject-special')
      mkdirSync(pyDir, { recursive: true })
      const pyprojectContent = '[project]\nname = "test"\ndescription = "A \\"quoted\\" value"'
      writeFileSync(join(pyDir, 'pyproject.toml'), pyprojectContent)

      const result = runInTestDir('bash', pyDir, 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(pyprojectContent)
    })
  })

  describe('get_requirements_txt()', () => {
    it('should return requirements.txt content from current directory', () => {
      const pyDir = join(testDir, 'requirements-cwd')
      mkdirSync(pyDir, { recursive: true })
      const reqContent = 'requests>=2.0.0\nclick>=8.0.0\npytest>=7.0.0'
      writeFileSync(join(pyDir, 'requirements.txt'), reqContent)

      const result = runInTestDir('bash', pyDir, 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(reqContent)
    })

    it('should return requirements.txt content from repo root when not in cwd', () => {
      const repoDir = join(testDir, 'requirements-repo-root')
      const subDir = join(repoDir, 'src')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)
      const reqContent = 'requests>=2.0.0\nclick'
      writeFileSync(join(repoDir, 'requirements.txt'), reqContent)
      commitFile(repoDir, 'requirements.txt', reqContent, 'init')

      const result = runInTestDir('bash', subDir, 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(reqContent)
    })

    it('should return 1 when no requirements.txt exists', () => {
      const tmpEmptyDir = `/tmp/requirements-empty-${Date.now()}`
      mkdirSync(tmpEmptyDir, { recursive: true })
      writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'no requirements.txt here')

      try {
        const result = runInTestDir('bash', tmpEmptyDir, 'get_requirements_txt')
        expect(result.code).toBe(1)
      } finally {
        rmSync(tmpEmptyDir, { recursive: true, force: true })
      }
    })

    it('should prefer cwd requirements.txt over repo root', () => {
      const repoDir = join(testDir, 'requirements-prefer-cwd')
      const subDir = join(repoDir, 'packages', 'app')
      mkdirSync(subDir, { recursive: true })
      initGitRepo(repoDir)

      const rootReq = 'requests'
      const subReq = 'click'
      writeFileSync(join(repoDir, 'requirements.txt'), rootReq)
      writeFileSync(join(subDir, 'requirements.txt'), subReq)
      commitFile(repoDir, 'requirements.txt', rootReq, 'init')

      const result = runInTestDir('bash', subDir, 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe(subReq)
    })
  })

  describe('has_dependency()', () => {
    describe('PEP 621 pyproject.toml format', () => {
      it('should return 0 when dependency exists in [project.dependencies]', () => {
        const pyDir = join(testDir, 'has-dep-pep621')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
name = "test"
dependencies = [
    "requests>=2.0.0",
    "click"
]
`)

        const result = runInTestDir('bash', pyDir, 'has_dependency "requests"')
        expect(result.code).toBe(0)
      })

      it('should return 1 when dependency does not exist', () => {
        const pyDir = join(testDir, 'no-dep-pep621')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
name = "test"
dependencies = ["requests"]
`)

        const result = runInTestDir('bash', pyDir, 'has_dependency "flask"')
        expect(result.code).toBe(1)
      })
    })

    describe('Poetry pyproject.toml format', () => {
      it('should return 0 when dependency exists in [tool.poetry.dependencies]', () => {
        const pyDir = join(testDir, 'has-dep-poetry')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"
click = "^8.0.0"
`)

        const result = runInTestDir('bash', pyDir, 'has_dependency "requests"')
        expect(result.code).toBe(0)
      })

      it('should return 1 when dependency is in dev-dependencies, not dependencies', () => {
        const pyDir = join(testDir, 'dep-not-in-poetry-deps')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
`)

        const result = runInTestDir('bash', pyDir, 'has_dependency "pytest"')
        expect(result.code).toBe(1)
      })
    })

    describe('requirements.txt format', () => {
      it('should return 0 when dependency exists in requirements.txt', () => {
        const pyDir = join(testDir, 'has-dep-req')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'requirements.txt'), `
requests>=2.0.0
click>=8.0.0
pytest
`)

        const result = runInTestDir('bash', pyDir, 'has_dependency "requests"')
        expect(result.code).toBe(0)
      })

      it('should handle requirements.txt with comments', () => {
        const pyDir = join(testDir, 'has-dep-req-comments')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'requirements.txt'), `
# Web framework
requests>=2.0.0
# CLI
click>=8.0.0
`)

        const result = runInTestDir('bash', pyDir, 'has_dependency "requests"')
        expect(result.code).toBe(0)
      })

      it('should return 1 for commented-out dependency', () => {
        const pyDir = join(testDir, 'has-dep-commented')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'requirements.txt'), `
requests>=2.0.0
# flask>=2.0.0
`)

        const result = runInTestDir('bash', pyDir, 'has_dependency "flask"')
        expect(result.code).toBe(1)
      })
    })

    it('should error when no argument provided', () => {
      const pyDir = join(testDir, 'dep-no-arg')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), '[project]\nname = "test"')

      const result = runInTestDir('bash', pyDir, 'has_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dev_dependency()', () => {
    describe('PEP 621 pyproject.toml format', () => {
      it('should return 0 when dependency exists in [project.optional-dependencies.dev]', () => {
        const pyDir = join(testDir, 'has-devdep-pep621')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
name = "test"

[project.optional-dependencies]
dev = ["pytest>=7.0.0", "ruff>=0.1.0"]
test = ["pytest-cov"]
`)

        const result = runInTestDir('bash', pyDir, 'has_dev_dependency "pytest"')
        expect(result.code).toBe(0)
      })

      it('should return 0 when dependency exists in any optional-dependencies group', () => {
        const pyDir = join(testDir, 'has-devdep-optional')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
name = "test"

[project.optional-dependencies]
test = ["pytest-cov"]
lint = ["ruff"]
`)

        const result = runInTestDir('bash', pyDir, 'has_dev_dependency "pytest-cov"')
        expect(result.code).toBe(0)
      })
    })

    describe('Poetry pyproject.toml format', () => {
      it('should return 0 when dependency exists in [tool.poetry.dev-dependencies]', () => {
        const pyDir = join(testDir, 'has-devdep-poetry')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
black = "^23.0.0"
`)

        const result = runInTestDir('bash', pyDir, 'has_dev_dependency "pytest"')
        expect(result.code).toBe(0)
      })

      it('should return 1 when dependency is in dependencies, not dev-dependencies', () => {
        const pyDir = join(testDir, 'devdep-wrong-section')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
`)

        const result = runInTestDir('bash', pyDir, 'has_dev_dependency "requests"')
        expect(result.code).toBe(1)
      })
    })

    describe('requirements-dev.txt format', () => {
      it('should return 0 when dependency exists in requirements-dev.txt', () => {
        const pyDir = join(testDir, 'has-devdep-reqdev')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'requirements.txt'), 'requests>=2.0.0')
        writeFileSync(join(pyDir, 'requirements-dev.txt'), `
pytest>=7.0.0
black>=23.0.0
`)

        const result = runInTestDir('bash', pyDir, 'has_dev_dependency "pytest"')
        expect(result.code).toBe(0)
      })
    })

    it('should return 1 when dev dependency does not exist', () => {
      const pyDir = join(testDir, 'no-devdep')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project.optional-dependencies]
dev = ["pytest"]
`)

      const result = runInTestDir('bash', pyDir, 'has_dev_dependency "black"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const pyDir = join(testDir, 'devdep-no-arg')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), '[project]\nname = "test"')

      const result = runInTestDir('bash', pyDir, 'has_dev_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dependency_anywhere()', () => {
    it('should return 0 when dependency is in project.dependencies', () => {
      const pyDir = join(testDir, 'has-anywhere-deps')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`)

      const result = runInTestDir('bash', pyDir, 'has_dependency_anywhere "requests"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dependency is in optional-dependencies', () => {
      const pyDir = join(testDir, 'has-anywhere-optional')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`)

      const result = runInTestDir('bash', pyDir, 'has_dependency_anywhere "pytest"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dependency is in requirements.txt', () => {
      const pyDir = join(testDir, 'has-anywhere-req')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements.txt'), 'requests\nclick')

      const result = runInTestDir('bash', pyDir, 'has_dependency_anywhere "click"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dependency is in requirements-dev.txt', () => {
      const pyDir = join(testDir, 'has-anywhere-reqdev')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements.txt'), 'requests')
      writeFileSync(join(pyDir, 'requirements-dev.txt'), 'pytest')

      const result = runInTestDir('bash', pyDir, 'has_dependency_anywhere "pytest"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency does not exist anywhere', () => {
      const pyDir = join(testDir, 'has-anywhere-none')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`)

      const result = runInTestDir('bash', pyDir, 'has_dependency_anywhere "flask"')
      expect(result.code).toBe(1)
    })
  })

  describe('get_py_linter_by_dep()', () => {
    it('should detect ruff in dev dependencies', () => {
      const pyDir = join(testDir, 'linter-dep-ruff')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project.optional-dependencies]
dev = ["ruff>=0.1.0"]
`)

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect flake8 in dev dependencies', () => {
      const pyDir = join(testDir, 'linter-dep-flake8')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[tool.poetry.dev-dependencies]
flake8 = "^6.0.0"
`)

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('flake8')
    })

    it('should detect pylint in dev dependencies', () => {
      const pyDir = join(testDir, 'linter-dep-pylint')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements-dev.txt'), 'pylint>=2.0.0\npytest')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pylint')
    })

    it('should detect mypy in dev dependencies', () => {
      const pyDir = join(testDir, 'linter-dep-mypy')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements-dev.txt'), 'mypy>=1.0.0')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('mypy')
    })

    it('should detect pyright in dev dependencies', () => {
      const pyDir = join(testDir, 'linter-dep-pyright')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project.optional-dependencies]
dev = ["pyright"]
`)

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pyright')
    })

    it('should return 1 when no linter is found', () => {
      const pyDir = join(testDir, 'linter-dep-none')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project.optional-dependencies]
dev = ["pytest"]
`)

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_dep')
      expect(result.code).toBe(1)
    })

    it('should prioritize ruff over other linters', () => {
      const pyDir = join(testDir, 'linter-dep-priority')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements-dev.txt'), `
flake8>=6.0.0
pylint>=2.0.0
ruff>=0.1.0
`)

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })
  })

  describe('get_py_linter_by_config()', () => {
    it('should detect ruff by ruff.toml', () => {
      const pyDir = join(testDir, 'linter-config-ruff-toml')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'ruff.toml'), 'line-length = 88')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect ruff by .ruff.toml', () => {
      const pyDir = join(testDir, 'linter-config-ruff-dottoml')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, '.ruff.toml'), 'line-length = 88')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect ruff by [tool.ruff] in pyproject.toml', () => {
      const pyDir = join(testDir, 'linter-config-ruff-pyproject')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
name = "test"

[tool.ruff]
line-length = 88
`)

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect flake8 by .flake8', () => {
      const pyDir = join(testDir, 'linter-config-flake8')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, '.flake8'), '[flake8]\nmax-line-length = 88')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('flake8')
    })

    it('should detect flake8 by setup.cfg [flake8] section', () => {
      const pyDir = join(testDir, 'linter-config-flake8-setup')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'setup.cfg'), `
[metadata]
name = test

[flake8]
max-line-length = 88
`)

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('flake8')
    })

    it('should detect pylint by .pylintrc', () => {
      const pyDir = join(testDir, 'linter-config-pylint')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, '.pylintrc'), '[MASTER]\njobs=4')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pylint')
    })

    it('should detect pylint by pylintrc', () => {
      const pyDir = join(testDir, 'linter-config-pylintrc')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pylintrc'), '[MASTER]\njobs=4')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pylint')
    })

    it('should detect mypy by mypy.ini', () => {
      const pyDir = join(testDir, 'linter-config-mypy')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'mypy.ini'), '[mypy]\npython_version = 3.9')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('mypy')
    })

    it('should detect mypy by .mypy.ini', () => {
      const pyDir = join(testDir, 'linter-config-mypy-dot')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, '.mypy.ini'), '[mypy]\npython_version = 3.9')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('mypy')
    })

    it('should detect pyright by pyrightconfig.json', () => {
      const pyDir = join(testDir, 'linter-config-pyright')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyrightconfig.json'), '{"pythonVersion": "3.9"}')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pyright')
    })

    it('should return 1 when no linter config is found', () => {
      const pyDir = join(testDir, 'linter-config-none')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), '[project]\nname = "test"')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(1)
    })

    it('should prioritize ruff over other linter configs', () => {
      const pyDir = join(testDir, 'linter-config-priority')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'ruff.toml'), 'line-length = 88')
      writeFileSync(join(pyDir, '.flake8'), '[flake8]\nmax-line-length = 88')
      writeFileSync(join(pyDir, '.pylintrc'), '[MASTER]\njobs=4')

      const result = runInTestDir('bash', pyDir, 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })
  })

  describe('get_py_formatter_by_dep()', () => {
    it('should detect ruff in dev dependencies', () => {
      const pyDir = join(testDir, 'formatter-dep-ruff')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements-dev.txt'), 'ruff>=0.1.0')

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect black in dev dependencies', () => {
      const pyDir = join(testDir, 'formatter-dep-black')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[tool.poetry.dev-dependencies]
black = "^23.0.0"
`)

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('black')
    })

    it('should detect yapf in dev dependencies', () => {
      const pyDir = join(testDir, 'formatter-dep-yapf')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements-dev.txt'), 'yapf')

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('yapf')
    })

    it('should detect autopep8 in dev dependencies', () => {
      const pyDir = join(testDir, 'formatter-dep-autopep8')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project.optional-dependencies]
dev = ["autopep8"]
`)

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('autopep8')
    })

    it('should detect isort in dev dependencies', () => {
      const pyDir = join(testDir, 'formatter-dep-isort')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements-dev.txt'), 'isort')

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('isort')
    })

    it('should return 1 when no formatter is found', () => {
      const pyDir = join(testDir, 'formatter-dep-none')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements-dev.txt'), 'pytest')

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_dep')
      expect(result.code).toBe(1)
    })

    it('should prioritize ruff over other formatters', () => {
      const pyDir = join(testDir, 'formatter-dep-priority')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'requirements-dev.txt'), `
black
yapf
ruff
`)

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })
  })

  describe('get_py_formatter_by_config()', () => {
    it('should detect ruff by config file', () => {
      const pyDir = join(testDir, 'formatter-config-ruff')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'ruff.toml'), 'line-length = 88')

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect black by [tool.black] in pyproject.toml', () => {
      const pyDir = join(testDir, 'formatter-config-black')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
name = "test"

[tool.black]
line-length = 88
`)

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('black')
    })

    it('should detect yapf by .style.yapf', () => {
      const pyDir = join(testDir, 'formatter-config-yapf')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, '.style.yapf'), '[style]\nbased_on_style = pep8')

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('yapf')
    })

    it('should detect autopep8 by setup.cfg', () => {
      const pyDir = join(testDir, 'formatter-config-autopep8')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'setup.cfg'), `
[metadata]
name = test

[tool:autopep8]
max_line_length = 88
`)

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('autopep8')
    })

    it('should detect isort by .isort.cfg', () => {
      const pyDir = join(testDir, 'formatter-config-isort')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, '.isort.cfg'), '[settings]\nprofile = black')

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('isort')
    })

    it('should return 1 when no formatter config is found', () => {
      const pyDir = join(testDir, 'formatter-config-none')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'pyproject.toml'), '[project]\nname = "test"')

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_config')
      expect(result.code).toBe(1)
    })

    it('should prioritize ruff over other formatter configs', () => {
      const pyDir = join(testDir, 'formatter-config-priority')
      mkdirSync(pyDir, { recursive: true })
      writeFileSync(join(pyDir, 'ruff.toml'), 'line-length = 88')
      writeFileSync(join(pyDir, 'pyproject.toml'), `
[tool.black]
line-length = 88
`)

      const result = runInTestDir('bash', pyDir, 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })
  })

  describe('packages_not_installed()', () => {
    describe('basic functionality', () => {
      it('should return packages not in any dependency section', () => {
        const pyDir = join(testDir, 'pkgs-not-installed-basic')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "flask" "django" "fastapi"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask', 'django', 'fastapi'])
      })

      it('should return empty when all packages are installed', () => {
        const pyDir = join(testDir, 'pkgs-all-installed')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests", "click"]

[project.optional-dependencies]
dev = ["pytest"]
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "requests" "click" "pytest"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })

      it('should return all packages when none are installed', () => {
        const pyDir = join(testDir, 'pkgs-none-installed')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = []
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "requests" "flask" "django"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['requests', 'flask', 'django'])
      })
    })

    describe('dependency section coverage', () => {
      it('should filter out packages in project.dependencies', () => {
        const pyDir = join(testDir, 'pkgs-in-deps')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests", "click"]
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "requests" "click" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask'])
      })

      it('should filter out packages in optional-dependencies', () => {
        const pyDir = join(testDir, 'pkgs-in-optional')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project.optional-dependencies]
dev = ["pytest", "black"]
test = ["pytest-cov"]
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "pytest" "black" "pytest-cov" "ruff"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['ruff'])
      })

      it('should filter out packages in requirements.txt', () => {
        const pyDir = join(testDir, 'pkgs-in-req')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'requirements.txt'), 'requests>=2.0.0\nclick')

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "requests" "click" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask'])
      })

      it('should filter out packages in requirements-dev.txt', () => {
        const pyDir = join(testDir, 'pkgs-in-reqdev')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'requirements.txt'), 'requests')
        writeFileSync(join(pyDir, 'requirements-dev.txt'), 'pytest\nblack')

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "pytest" "black" "ruff"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['ruff'])
      })

      it('should handle packages mixed across all sections', () => {
        const pyDir = join(testDir, 'pkgs-mixed-sections')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`)
        writeFileSync(join(pyDir, 'requirements-dev.txt'), 'black')

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "requests" "pytest" "black" "flask" "django"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask', 'django'])
      })

      it('should handle Poetry format dependencies', () => {
        const pyDir = join(testDir, 'pkgs-poetry')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "requests" "pytest" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask'])
      })
    })

    describe('input handling', () => {
      it('should handle single package argument', () => {
        const pyDir = join(testDir, 'pkgs-single-arg')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), '[project]\ndependencies = []')

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('flask')
      })

      it('should handle multiple package arguments', () => {
        const pyDir = join(testDir, 'pkgs-multi-args')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), '[project]\ndependencies = []')

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "flask" "django" "fastapi"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask', 'django', 'fastapi'])
      })

      it('should handle pass-by-reference (array name) and modify in-place', () => {
        const pyDir = join(testDir, 'pkgs-by-ref')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests"]
`)

        // Pass-by-reference should modify array in-place, not output to stdout
        const script = `
          declare -a my_packages=("requests" "flask" "django")
          packages_not_installed my_packages
          echo "\${my_packages[@]}"
        `
        const result = runInTestDir('bash', pyDir, script)
        expect(result.code).toBe(0)
        // Array should now only contain not-installed packages
        expect(result.stdout).toBe('flask django')
      })

      it('should return empty output for empty input', () => {
        const pyDir = join(testDir, 'pkgs-empty-input')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), '[project]\ndependencies = []')

        const result = runInTestDir('bash', pyDir, 'packages_not_installed')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })
    })

    describe('edge cases', () => {
      it('should handle packages with version specifiers in dependencies', () => {
        const pyDir = join(testDir, 'pkgs-version-spec')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["requests>=2.0.0", "click~=8.0"]
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "requests" "click" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask'])
      })

      it('should handle no pyproject.toml or requirements.txt files', () => {
        const tmpEmptyDir = `/tmp/pkgs-no-files-${Date.now()}`
        mkdirSync(tmpEmptyDir, { recursive: true })
        writeFileSync(join(tmpEmptyDir, 'readme.txt'), 'no dependency files')

        try {
          const result = runInTestDir('bash', tmpEmptyDir, 'packages_not_installed "requests" "flask"')
          // Should return all packages as not installed (or error)
          if (result.code === 0) {
            const lines = result.stdout.trim().split('\n').filter(l => l)
            expect(lines).toEqual(['requests', 'flask'])
          } else {
            // Error is also acceptable behavior
            expect(result.code).not.toBe(0)
          }
        } finally {
          rmSync(tmpEmptyDir, { recursive: true, force: true })
        }
      })

      it('should handle pyproject.toml with no dependency sections', () => {
        const pyDir = join(testDir, 'pkgs-no-dep-sections')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
name = "test"
version = "1.0.0"
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "requests" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['requests', 'flask'])
      })
    })

    describe('output format', () => {
      it('should preserve input order in output', () => {
        const pyDir = join(testDir, 'pkgs-order')
        mkdirSync(pyDir, { recursive: true })
        writeFileSync(join(pyDir, 'pyproject.toml'), `
[project]
dependencies = ["zipp"]
`)

        const result = runInTestDir('bash', pyDir, 'packages_not_installed "zebra" "apple" "mango" "zipp"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['zebra', 'apple', 'mango'])
      })
    })
  })
})
