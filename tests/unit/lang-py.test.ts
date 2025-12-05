import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { join } from 'path'
import { runInShell, isWSL, GitFixtureManager, GitFixtureDef, COMMON_GIT_PATTERNS } from "../helpers"

/** Project root for absolute path references */
const PROJECT_ROOT = process.cwd()

/** Path to permanent fixtures */
const FIXTURES_DIR = join(PROJECT_ROOT, 'tests', 'fixtures', 'lang-py')

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

// =============================================================================
// GIT FIXTURES - Only fixtures that require git repos (created dynamically)
// =============================================================================

const GIT_FIXTURES: Record<string, GitFixtureDef> = {
  'py-pkg-mgr-subdir-test': COMMON_GIT_PATTERNS.pkgMgrSubdir(
    'pyproject.toml', '[tool.poetry]\nname = "monorepo"',
    'poetry.lock', '# Poetry lock file',
    'src/app'
  ),
  'pyproject-repo-root': COMMON_GIT_PATTERNS.repoRoot(
    'pyproject.toml',
    '[project]\nname = "root-pkg"\nversion = "2.0.0"',
    'src/app'
  ),
  'pyproject-prefer-cwd': COMMON_GIT_PATTERNS.preferCwd(
    'pyproject.toml',
    '[project]\nname = "root-pkg"',
    'packages/app',
    '[project]\nname = "sub-pkg"'
  ),
  'requirements-repo-root': COMMON_GIT_PATTERNS.repoRoot(
    'requirements.txt',
    'requests>=2.0.0\nclick',
    'src'
  ),
  'requirements-prefer-cwd': COMMON_GIT_PATTERNS.preferCwd(
    'requirements.txt',
    'requests',
    'packages/app',
    'click'
  )
}

// =============================================================================
// TESTS
// =============================================================================

// Skip on WSL: These tests require yq which may not be reliably installable on WSL
// in GitHub Actions. The ensure_install() in lang-py.sh calls exit 1 if yq
// installation fails, causing all tests to fail with exit code 1.
describe.skipIf(isWSL)("lang-py", { concurrent: true }, () => {
  // Git fixture manager
  const gitManager = new GitFixtureManager('lang-py-git')

  // Paths to all fixtures (permanent + git)
  const dirs: Record<string, string> = {}

  beforeAll(() => {
    // Set up paths to permanent fixtures
    const permanentFixtures = [
      'poetry-project', 'poetry-no-lock', 'pipenv-project', 'pipenv-no-lock',
      'uv-project', 'pdm-project', 'pdm-no-lock', 'hatch-project', 'conda-project',
      'pip-project', 'pip-setup-project', 'py-no-manager', 'non-python-project',
      'mixed-py-managers', 'pyproject-cwd', 'pyproject-empty', 'pyproject-special',
      'requirements-cwd', 'requirements-empty',
      'has-dep-pep621', 'no-dep-pep621', 'has-dep-poetry', 'dep-not-in-poetry-deps',
      'has-dep-req', 'has-dep-req-comments', 'has-dep-commented', 'dep-no-arg',
      'has-devdep-pep621', 'has-devdep-optional', 'has-devdep-poetry',
      'devdep-wrong-section', 'has-devdep-reqdev', 'no-devdep', 'devdep-no-arg',
      'has-anywhere-deps', 'has-anywhere-optional', 'has-anywhere-req',
      'has-anywhere-reqdev', 'has-anywhere-none',
      'linter-dep-ruff', 'linter-dep-flake8', 'linter-dep-pylint', 'linter-dep-mypy',
      'linter-dep-pyright', 'linter-dep-none', 'linter-dep-priority',
      'linter-config-ruff-toml', 'linter-config-ruff-dottoml', 'linter-config-ruff-pyproject',
      'linter-config-flake8', 'linter-config-flake8-setup', 'linter-config-pylint',
      'linter-config-pylintrc', 'linter-config-mypy', 'linter-config-mypy-dot',
      'linter-config-pyright', 'linter-config-none', 'linter-config-priority',
      'formatter-dep-ruff', 'formatter-dep-black', 'formatter-dep-yapf',
      'formatter-dep-autopep8', 'formatter-dep-isort', 'formatter-dep-none',
      'formatter-dep-priority', 'formatter-config-ruff', 'formatter-config-black',
      'formatter-config-yapf', 'formatter-config-autopep8', 'formatter-config-isort',
      'formatter-config-none', 'formatter-config-priority',
      'pkgs-not-installed-basic', 'pkgs-all-installed', 'pkgs-none-installed',
      'pkgs-in-deps', 'pkgs-in-optional', 'pkgs-in-req', 'pkgs-in-reqdev',
      'pkgs-mixed-sections', 'pkgs-poetry', 'pkgs-single-arg', 'pkgs-multi-args',
      'pkgs-by-ref', 'pkgs-empty-input', 'pkgs-version-spec', 'pkgs-no-files',
      'pkgs-no-dep-sections', 'pkgs-order'
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

  describe('py_package_manager()', () => {
    it('should return "poetry" when poetry.lock exists', () => {
      const result = runInTestDir('bash', dirs['poetry-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('poetry')
    })

    it('should return "poetry" when pyproject.toml has [tool.poetry] section', () => {
      const result = runInTestDir('bash', dirs['poetry-no-lock'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('poetry')
    })

    it('should return "pipenv" when Pipfile.lock exists', () => {
      const result = runInTestDir('bash', dirs['pipenv-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pipenv')
    })

    it('should return "pipenv" when Pipfile exists', () => {
      const result = runInTestDir('bash', dirs['pipenv-no-lock'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pipenv')
    })

    it('should return "uv" when uv.lock exists', () => {
      const result = runInTestDir('bash', dirs['uv-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('uv')
    })

    it('should return "pdm" when pdm.lock exists', () => {
      const result = runInTestDir('bash', dirs['pdm-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pdm')
    })

    it('should return "pdm" when pyproject.toml has [tool.pdm] section', () => {
      const result = runInTestDir('bash', dirs['pdm-no-lock'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pdm')
    })

    it('should return "hatch" when pyproject.toml has [tool.hatch] section', () => {
      const result = runInTestDir('bash', dirs['hatch-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('hatch')
    })

    it('should return "conda" when environment.yml exists', () => {
      const result = runInTestDir('bash', dirs['conda-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('conda')
    })

    it('should return "pip" when only requirements.txt exists', () => {
      const result = runInTestDir('bash', dirs['pip-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pip')
    })

    it('should return "pip" when setup.py exists', () => {
      const result = runInTestDir('bash', dirs['pip-setup-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pip')
    })

    it('should return empty when only pyproject.toml with [project] exists (no specific manager)', () => {
      const result = runInTestDir('bash', dirs['py-no-manager'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('')
    })

    it('should return 1 when not a Python project', () => {
      const result = runInTestDir('bash', dirs['non-python-project'], 'py_package_manager')
      expect(result.code).toBe(1)
    })

    it('should detect package manager from repo root when in subdirectory', () => {
      const subDir = join(dirs['py-pkg-mgr-subdir-test'], 'src', 'app')
      const result = runInTestDir('bash', subDir, 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('poetry')
    })

    it('should prioritize lock files (uv.lock over requirements.txt)', () => {
      const result = runInTestDir('bash', dirs['mixed-py-managers'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('uv')
    })
  })

  describe('get_pyproject_toml()', () => {
    it('should return content from pyproject.toml in cwd', () => {
      const result = runInTestDir('bash', dirs['pyproject-cwd'], 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('[project]')
      expect(result.stdout).toContain('name = "test-pkg"')
    })

    it('should return content from repo root when in subdirectory', () => {
      const subDir = join(dirs['pyproject-repo-root'], 'src', 'app')
      const result = runInTestDir('bash', subDir, 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('name = "root-pkg"')
    })

    it('should return 1 when no pyproject.toml exists', () => {
      const result = runInTestDir('bash', dirs['pyproject-empty'], 'get_pyproject_toml')
      expect(result.code).toBe(1)
    })

    it('should prefer cwd pyproject.toml over repo root', () => {
      const subDir = join(dirs['pyproject-prefer-cwd'], 'packages', 'app')
      const result = runInTestDir('bash', subDir, 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('name = "sub-pkg"')
    })

    it('should handle special characters in pyproject.toml', () => {
      const result = runInTestDir('bash', dirs['pyproject-special'], 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('description')
    })
  })

  describe('get_requirements_txt()', () => {
    it('should return content from requirements.txt in cwd', () => {
      const result = runInTestDir('bash', dirs['requirements-cwd'], 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('requests>=2.0.0')
      expect(result.stdout).toContain('click>=8.0.0')
    })

    it('should return content from repo root when in subdirectory', () => {
      const subDir = join(dirs['requirements-repo-root'], 'src')
      const result = runInTestDir('bash', subDir, 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('requests>=2.0.0')
    })

    it('should return 1 when no requirements.txt exists', () => {
      const result = runInTestDir('bash', dirs['requirements-empty'], 'get_requirements_txt')
      expect(result.code).toBe(1)
    })

    it('should prefer cwd requirements.txt over repo root', () => {
      const subDir = join(dirs['requirements-prefer-cwd'], 'packages', 'app')
      const result = runInTestDir('bash', subDir, 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toContain('click')
      expect(result.stdout).not.toContain('requests')
    })
  })

  describe('has_dependency()', () => {
    it('should return 0 when dependency exists in PEP 621 format', () => {
      const result = runInTestDir('bash', dirs['has-dep-pep621'], 'has_dependency "requests"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-dep-pep621'], 'has_dependency "flask"')
      expect(result.code).toBe(1)
    })

    it('should return 0 when dependency exists in Poetry format', () => {
      const result = runInTestDir('bash', dirs['has-dep-poetry'], 'has_dependency "requests"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency is in dev-dependencies, not dependencies', () => {
      const result = runInTestDir('bash', dirs['dep-not-in-poetry-deps'], 'has_dependency "pytest"')
      expect(result.code).toBe(1)
    })

    it('should return 0 when dependency exists in requirements.txt', () => {
      const result = runInTestDir('bash', dirs['has-dep-req'], 'has_dependency "requests"')
      expect(result.code).toBe(0)
    })

    it('should handle version specifiers in requirements.txt', () => {
      const result = runInTestDir('bash', dirs['has-dep-req-comments'], 'has_dependency "click"')
      expect(result.code).toBe(0)
    })

    it('should not match commented dependencies', () => {
      const result = runInTestDir('bash', dirs['has-dep-commented'], 'has_dependency "flask"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['dep-no-arg'], 'has_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dev_dependency()', () => {
    it('should return 0 when dev dependency exists in PEP 621 optional-dependencies', () => {
      const result = runInTestDir('bash', dirs['has-devdep-pep621'], 'has_dev_dependency "pytest"')
      expect(result.code).toBe(0)
    })

    it('should check all optional-dependency groups', () => {
      const result = runInTestDir('bash', dirs['has-devdep-optional'], 'has_dev_dependency "pytest-cov"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dev dependency exists in Poetry format', () => {
      const result = runInTestDir('bash', dirs['has-devdep-poetry'], 'has_dev_dependency "pytest"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency is in dependencies, not dev-dependencies', () => {
      const result = runInTestDir('bash', dirs['devdep-wrong-section'], 'has_dev_dependency "requests"')
      expect(result.code).toBe(1)
    })

    it('should return 0 when dependency exists in requirements-dev.txt', () => {
      const result = runInTestDir('bash', dirs['has-devdep-reqdev'], 'has_dev_dependency "pytest"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dev dependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-devdep'], 'has_dev_dependency "flask"')
      expect(result.code).toBe(1)
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['devdep-no-arg'], 'has_dev_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dependency_anywhere()', () => {
    it('should return 0 when dependency is in project.dependencies', () => {
      const result = runInTestDir('bash', dirs['has-anywhere-deps'], 'has_dependency_anywhere "requests"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dependency is in optional-dependencies', () => {
      const result = runInTestDir('bash', dirs['has-anywhere-optional'], 'has_dependency_anywhere "pytest"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dependency is in requirements.txt', () => {
      const result = runInTestDir('bash', dirs['has-anywhere-req'], 'has_dependency_anywhere "click"')
      expect(result.code).toBe(0)
    })

    it('should return 0 when dependency is in requirements-dev.txt', () => {
      const result = runInTestDir('bash', dirs['has-anywhere-reqdev'], 'has_dependency_anywhere "pytest"')
      expect(result.code).toBe(0)
    })

    it('should return 1 when dependency does not exist anywhere', () => {
      const result = runInTestDir('bash', dirs['has-anywhere-none'], 'has_dependency_anywhere "flask"')
      expect(result.code).toBe(1)
    })
  })

  describe('get_py_linter_by_dep()', () => {
    it('should detect ruff in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-ruff'], 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect flake8 in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-flake8'], 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('flake8')
    })

    it('should detect pylint in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-pylint'], 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pylint')
    })

    it('should detect mypy in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-mypy'], 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('mypy')
    })

    it('should detect pyright in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['linter-dep-pyright'], 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pyright')
    })

    it('should return 1 when no linter is found', () => {
      const result = runInTestDir('bash', dirs['linter-dep-none'], 'get_py_linter_by_dep')
      expect(result.code).toBe(1)
    })

    it('should prioritize ruff over other linters', () => {
      const result = runInTestDir('bash', dirs['linter-dep-priority'], 'get_py_linter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })
  })

  describe('get_py_linter_by_config()', () => {
    it('should detect ruff by ruff.toml', () => {
      const result = runInTestDir('bash', dirs['linter-config-ruff-toml'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect ruff by .ruff.toml', () => {
      const result = runInTestDir('bash', dirs['linter-config-ruff-dottoml'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect ruff by [tool.ruff] in pyproject.toml', () => {
      const result = runInTestDir('bash', dirs['linter-config-ruff-pyproject'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect flake8 by .flake8', () => {
      const result = runInTestDir('bash', dirs['linter-config-flake8'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('flake8')
    })

    it('should detect flake8 by setup.cfg [flake8] section', () => {
      const result = runInTestDir('bash', dirs['linter-config-flake8-setup'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('flake8')
    })

    it('should detect pylint by .pylintrc', () => {
      const result = runInTestDir('bash', dirs['linter-config-pylint'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pylint')
    })

    it('should detect pylint by pylintrc', () => {
      const result = runInTestDir('bash', dirs['linter-config-pylintrc'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pylint')
    })

    it('should detect mypy by mypy.ini', () => {
      const result = runInTestDir('bash', dirs['linter-config-mypy'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('mypy')
    })

    it('should detect mypy by .mypy.ini', () => {
      const result = runInTestDir('bash', dirs['linter-config-mypy-dot'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('mypy')
    })

    it('should detect pyright by pyrightconfig.json', () => {
      const result = runInTestDir('bash', dirs['linter-config-pyright'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pyright')
    })

    it('should return 1 when no linter config is found', () => {
      const result = runInTestDir('bash', dirs['linter-config-none'], 'get_py_linter_by_config')
      expect(result.code).toBe(1)
    })

    it('should prioritize ruff over other linter configs', () => {
      const result = runInTestDir('bash', dirs['linter-config-priority'], 'get_py_linter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })
  })

  describe('get_py_formatter_by_dep()', () => {
    it('should detect ruff in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['formatter-dep-ruff'], 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect black in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['formatter-dep-black'], 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('black')
    })

    it('should detect yapf in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['formatter-dep-yapf'], 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('yapf')
    })

    it('should detect autopep8 in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['formatter-dep-autopep8'], 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('autopep8')
    })

    it('should detect isort in dev dependencies', () => {
      const result = runInTestDir('bash', dirs['formatter-dep-isort'], 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('isort')
    })

    it('should return 1 when no formatter is found', () => {
      const result = runInTestDir('bash', dirs['formatter-dep-none'], 'get_py_formatter_by_dep')
      expect(result.code).toBe(1)
    })

    it('should prioritize ruff over other formatters', () => {
      const result = runInTestDir('bash', dirs['formatter-dep-priority'], 'get_py_formatter_by_dep')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })
  })

  describe('get_py_formatter_by_config()', () => {
    it('should detect ruff by config file', () => {
      const result = runInTestDir('bash', dirs['formatter-config-ruff'], 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })

    it('should detect black by [tool.black] in pyproject.toml', () => {
      const result = runInTestDir('bash', dirs['formatter-config-black'], 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('black')
    })

    it('should detect yapf by .style.yapf', () => {
      const result = runInTestDir('bash', dirs['formatter-config-yapf'], 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('yapf')
    })

    it('should detect autopep8 by setup.cfg', () => {
      const result = runInTestDir('bash', dirs['formatter-config-autopep8'], 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('autopep8')
    })

    it('should detect isort by .isort.cfg', () => {
      const result = runInTestDir('bash', dirs['formatter-config-isort'], 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('isort')
    })

    it('should return 1 when no formatter config is found', () => {
      const result = runInTestDir('bash', dirs['formatter-config-none'], 'get_py_formatter_by_config')
      expect(result.code).toBe(1)
    })

    it('should prioritize ruff over other formatter configs', () => {
      const result = runInTestDir('bash', dirs['formatter-config-priority'], 'get_py_formatter_by_config')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('ruff')
    })
  })

  describe('packages_not_installed()', () => {
    describe('basic functionality', () => {
      it('should return packages not in any dependency section', () => {
        const result = runInTestDir('bash', dirs['pkgs-not-installed-basic'], 'packages_not_installed "requests" "flask" "pytest"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should return empty when all packages are installed', () => {
        const result = runInTestDir('bash', dirs['pkgs-all-installed'], 'packages_not_installed "requests" "click" "pytest"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('')
      })

      it('should return all packages when none are installed', () => {
        const result = runInTestDir('bash', dirs['pkgs-none-installed'], 'packages_not_installed "flask" "django"')
        expect(result.code).toBe(0)
        expect(result.stdout).toContain('flask')
        expect(result.stdout).toContain('django')
      })
    })

    describe('dependency section coverage', () => {
      it('should filter out packages in project.dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-deps'], 'packages_not_installed "requests" "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should filter out packages in optional-dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-optional'], 'packages_not_installed "pytest" "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should filter out packages in requirements.txt', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-req'], 'packages_not_installed "requests" "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should filter out packages in requirements-dev.txt', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-reqdev'], 'packages_not_installed "pytest" "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should handle packages mixed across all sections', () => {
        const result = runInTestDir('bash', dirs['pkgs-mixed-sections'], 'packages_not_installed "requests" "pytest" "black" "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should handle Poetry format dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-poetry'], 'packages_not_installed "requests" "pytest" "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })
    })

    describe('input handling', () => {
      it('should handle single package argument', () => {
        const result = runInTestDir('bash', dirs['pkgs-single-arg'], 'packages_not_installed "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should handle multiple package arguments', () => {
        const result = runInTestDir('bash', dirs['pkgs-multi-args'], 'packages_not_installed "flask" "django" "fastapi"')
        expect(result.code).toBe(0)
        expect(result.stdout).toContain('flask')
        expect(result.stdout).toContain('django')
        expect(result.stdout).toContain('fastapi')
      })

      it('should handle pass-by-reference (array name) and modify in-place', () => {
        const result = runInTestDir('bash', dirs['pkgs-by-ref'], `
          packages=("requests" "flask")
          packages_not_installed packages
          echo "\${packages[@]}"
        `)
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should return empty output for empty input', () => {
        const result = runInTestDir('bash', dirs['pkgs-empty-input'], 'packages_not_installed')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('')
      })
    })

    describe('edge cases', () => {
      it('should handle packages with version specifiers in dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-version-spec'], 'packages_not_installed "requests" "click" "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should handle no pyproject.toml or requirements.txt files', () => {
        const result = runInTestDir('bash', dirs['pkgs-no-files'], 'packages_not_installed "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })

      it('should handle pyproject.toml with no dependency sections', () => {
        const result = runInTestDir('bash', dirs['pkgs-no-dep-sections'], 'packages_not_installed "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout).toBe('flask')
      })
    })

    describe('output format', () => {
      it('should preserve input order in output', () => {
        const result = runInTestDir('bash', dirs['pkgs-order'], 'packages_not_installed "flask" "django" "zipp"')
        expect(result.code).toBe(0)
        const lines = result.stdout.split('\n').filter(l => l)
        expect(lines).toEqual(['flask', 'django'])
      })
    })
  })
})
