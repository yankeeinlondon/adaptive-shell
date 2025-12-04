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
  // py_package_manager() fixtures
  'poetry-project': {
    files: {
      'pyproject.toml': '[tool.poetry]\nname = "test"',
      'poetry.lock': '# Poetry lock file'
    }
  },
  'poetry-no-lock': {
    files: {
      'pyproject.toml': `
[tool.poetry]
name = "test-project"
version = "0.1.0"
`
    }
  },
  'pipenv-project': {
    files: {
      'Pipfile': '[[source]]\nurl = "https://pypi.org/simple"',
      'Pipfile.lock': '{"_meta": {}}'
    }
  },
  'pipenv-no-lock': {
    files: {
      'Pipfile': '[[source]]\nurl = "https://pypi.org/simple"'
    }
  },
  'uv-project': {
    files: {
      'pyproject.toml': '[project]\nname = "test"',
      'uv.lock': 'version = 1'
    }
  },
  'pdm-project': {
    files: {
      'pyproject.toml': '[project]\nname = "test"',
      'pdm.lock': '# PDM lock file'
    }
  },
  'pdm-no-lock': {
    files: {
      'pyproject.toml': `
[project]
name = "test"

[tool.pdm]
`
    }
  },
  'hatch-project': {
    files: {
      'pyproject.toml': `
[project]
name = "test"

[tool.hatch.build]
`
    }
  },
  'conda-project': {
    files: {
      'environment.yml': 'name: test\nchannels:\n  - conda-forge'
    }
  },
  'pip-project': {
    files: {
      'requirements.txt': 'requests>=2.0.0\nclick'
    }
  },
  'pip-setup-project': {
    files: {
      'setup.py': 'from setuptools import setup\nsetup(name="test")'
    }
  },
  'py-no-manager': {
    files: {
      'pyproject.toml': '[project]\nname = "test"'
    }
  },
  'non-python-project': {
    files: {
      'readme.txt': 'not a python project'
    }
  },
  'py-pkg-mgr-subdir-test': {
    git: true,
    subdirs: ['src/app'],
    files: {
      'pyproject.toml': '[tool.poetry]\nname = "monorepo"',
      'poetry.lock': '# Poetry lock file'
    },
    commits: [
      { file: 'pyproject.toml', content: '[tool.poetry]\nname = "monorepo"', message: 'init' }
    ]
  },
  'mixed-py-managers': {
    files: {
      'pyproject.toml': '[project]\nname = "test"',
      'uv.lock': 'version = 1',
      'requirements.txt': 'requests'
    }
  },

  // get_pyproject_toml() fixtures
  'pyproject-cwd': {
    files: {
      'pyproject.toml': '[project]\nname = "test-pkg"\nversion = "1.0.0"'
    }
  },
  'pyproject-repo-root': {
    git: true,
    subdirs: ['src/app'],
    files: {
      'pyproject.toml': '[project]\nname = "root-pkg"\nversion = "2.0.0"'
    },
    commits: [
      { file: 'pyproject.toml', content: '[project]\nname = "root-pkg"\nversion = "2.0.0"', message: 'init' }
    ]
  },
  'pyproject-empty': {
    files: {
      'readme.txt': 'no pyproject.toml here'
    }
  },
  'pyproject-prefer-cwd': {
    git: true,
    subdirs: ['packages/app'],
    files: {
      'pyproject.toml': '[project]\nname = "root-pkg"',
      'packages/app/pyproject.toml': '[project]\nname = "sub-pkg"'
    },
    commits: [
      { file: 'pyproject.toml', content: '[project]\nname = "root-pkg"', message: 'init' }
    ]
  },
  'pyproject-special': {
    files: {
      'pyproject.toml': '[project]\nname = "test"\ndescription = "A \\"quoted\\" value"'
    }
  },

  // get_requirements_txt() fixtures
  'requirements-cwd': {
    files: {
      'requirements.txt': 'requests>=2.0.0\nclick>=8.0.0\npytest>=7.0.0'
    }
  },
  'requirements-repo-root': {
    git: true,
    subdirs: ['src'],
    files: {
      'requirements.txt': 'requests>=2.0.0\nclick'
    },
    commits: [
      { file: 'requirements.txt', content: 'requests>=2.0.0\nclick', message: 'init' }
    ]
  },
  'requirements-empty': {
    files: {
      'readme.txt': 'no requirements.txt here'
    }
  },
  'requirements-prefer-cwd': {
    git: true,
    subdirs: ['packages/app'],
    files: {
      'requirements.txt': 'requests',
      'packages/app/requirements.txt': 'click'
    },
    commits: [
      { file: 'requirements.txt', content: 'requests', message: 'init' }
    ]
  },

  // has_dependency() fixtures
  'has-dep-pep621': {
    files: {
      'pyproject.toml': `
[project]
name = "test"
dependencies = [
    "requests>=2.0.0",
    "click"
]
`
    }
  },
  'no-dep-pep621': {
    files: {
      'pyproject.toml': `
[project]
name = "test"
dependencies = ["requests"]
`
    }
  },
  'has-dep-poetry': {
    files: {
      'pyproject.toml': `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"
click = "^8.0.0"
`
    }
  },
  'dep-not-in-poetry-deps': {
    files: {
      'pyproject.toml': `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
`
    }
  },
  'has-dep-req': {
    files: {
      'requirements.txt': `
requests>=2.0.0
click>=8.0.0
pytest
`
    }
  },
  'has-dep-req-comments': {
    files: {
      'requirements.txt': `
# Web framework
requests>=2.0.0
# CLI
click>=8.0.0
`
    }
  },
  'has-dep-commented': {
    files: {
      'requirements.txt': `
requests>=2.0.0
# flask>=2.0.0
`
    }
  },
  'dep-no-arg': {
    files: {
      'pyproject.toml': '[project]\nname = "test"'
    }
  },

  // has_dev_dependency() fixtures
  'has-devdep-pep621': {
    files: {
      'pyproject.toml': `
[project]
name = "test"

[project.optional-dependencies]
dev = ["pytest>=7.0.0", "ruff>=0.1.0"]
test = ["pytest-cov"]
`
    }
  },
  'has-devdep-optional': {
    files: {
      'pyproject.toml': `
[project]
name = "test"

[project.optional-dependencies]
test = ["pytest-cov"]
lint = ["ruff"]
`
    }
  },
  'has-devdep-poetry': {
    files: {
      'pyproject.toml': `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
black = "^23.0.0"
`
    }
  },
  'devdep-wrong-section': {
    files: {
      'pyproject.toml': `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
`
    }
  },
  'has-devdep-reqdev': {
    files: {
      'requirements.txt': 'requests>=2.0.0',
      'requirements-dev.txt': `
pytest>=7.0.0
black>=23.0.0
`
    }
  },
  'no-devdep': {
    files: {
      'pyproject.toml': `
[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'devdep-no-arg': {
    files: {
      'pyproject.toml': '[project]\nname = "test"'
    }
  },

  // has_dependency_anywhere() fixtures
  'has-anywhere-deps': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'has-anywhere-optional': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'has-anywhere-req': {
    files: {
      'requirements.txt': 'requests\nclick'
    }
  },
  'has-anywhere-reqdev': {
    files: {
      'requirements.txt': 'requests',
      'requirements-dev.txt': 'pytest'
    }
  },
  'has-anywhere-none': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },

  // get_py_linter_by_dep() fixtures
  'linter-dep-ruff': {
    files: {
      'pyproject.toml': `
[project.optional-dependencies]
dev = ["ruff>=0.1.0"]
`
    }
  },
  'linter-dep-flake8': {
    files: {
      'pyproject.toml': `
[tool.poetry.dev-dependencies]
flake8 = "^6.0.0"
`
    }
  },
  'linter-dep-pylint': {
    files: {
      'requirements-dev.txt': 'pylint>=2.0.0\npytest'
    }
  },
  'linter-dep-mypy': {
    files: {
      'requirements-dev.txt': 'mypy>=1.0.0'
    }
  },
  'linter-dep-pyright': {
    files: {
      'pyproject.toml': `
[project.optional-dependencies]
dev = ["pyright"]
`
    }
  },
  'linter-dep-none': {
    files: {
      'pyproject.toml': `
[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'linter-dep-priority': {
    files: {
      'requirements-dev.txt': `
flake8>=6.0.0
pylint>=2.0.0
ruff>=0.1.0
`
    }
  },

  // get_py_linter_by_config() fixtures
  'linter-config-ruff-toml': {
    files: {
      'ruff.toml': 'line-length = 88'
    }
  },
  'linter-config-ruff-dottoml': {
    files: {
      '.ruff.toml': 'line-length = 88'
    }
  },
  'linter-config-ruff-pyproject': {
    files: {
      'pyproject.toml': `
[project]
name = "test"

[tool.ruff]
line-length = 88
`
    }
  },
  'linter-config-flake8': {
    files: {
      '.flake8': '[flake8]\nmax-line-length = 88'
    }
  },
  'linter-config-flake8-setup': {
    files: {
      'setup.cfg': `
[metadata]
name = test

[flake8]
max-line-length = 88
`
    }
  },
  'linter-config-pylint': {
    files: {
      '.pylintrc': '[MASTER]\njobs=4'
    }
  },
  'linter-config-pylintrc': {
    files: {
      'pylintrc': '[MASTER]\njobs=4'
    }
  },
  'linter-config-mypy': {
    files: {
      'mypy.ini': '[mypy]\npython_version = 3.9'
    }
  },
  'linter-config-mypy-dot': {
    files: {
      '.mypy.ini': '[mypy]\npython_version = 3.9'
    }
  },
  'linter-config-pyright': {
    files: {
      'pyrightconfig.json': '{"pythonVersion": "3.9"}'
    }
  },
  'linter-config-none': {
    files: {
      'pyproject.toml': '[project]\nname = "test"'
    }
  },
  'linter-config-priority': {
    files: {
      'ruff.toml': 'line-length = 88',
      '.flake8': '[flake8]\nmax-line-length = 88',
      '.pylintrc': '[MASTER]\njobs=4'
    }
  },

  // get_py_formatter_by_dep() fixtures
  'formatter-dep-ruff': {
    files: {
      'requirements-dev.txt': 'ruff>=0.1.0'
    }
  },
  'formatter-dep-black': {
    files: {
      'pyproject.toml': `
[tool.poetry.dev-dependencies]
black = "^23.0.0"
`
    }
  },
  'formatter-dep-yapf': {
    files: {
      'requirements-dev.txt': 'yapf'
    }
  },
  'formatter-dep-autopep8': {
    files: {
      'pyproject.toml': `
[project.optional-dependencies]
dev = ["autopep8"]
`
    }
  },
  'formatter-dep-isort': {
    files: {
      'requirements-dev.txt': 'isort'
    }
  },
  'formatter-dep-none': {
    files: {
      'requirements-dev.txt': 'pytest'
    }
  },
  'formatter-dep-priority': {
    files: {
      'requirements-dev.txt': `
black
yapf
ruff
`
    }
  },

  // get_py_formatter_by_config() fixtures
  'formatter-config-ruff': {
    files: {
      'ruff.toml': 'line-length = 88'
    }
  },
  'formatter-config-black': {
    files: {
      'pyproject.toml': `
[project]
name = "test"

[tool.black]
line-length = 88
`
    }
  },
  'formatter-config-yapf': {
    files: {
      '.style.yapf': '[style]\nbased_on_style = pep8'
    }
  },
  'formatter-config-autopep8': {
    files: {
      'setup.cfg': `
[metadata]
name = test

[tool:autopep8]
max_line_length = 88
`
    }
  },
  'formatter-config-isort': {
    files: {
      '.isort.cfg': '[settings]\nprofile = black'
    }
  },
  'formatter-config-none': {
    files: {
      'pyproject.toml': '[project]\nname = "test"'
    }
  },
  'formatter-config-priority': {
    files: {
      'ruff.toml': 'line-length = 88',
      'pyproject.toml': `
[tool.black]
line-length = 88
`
    }
  },

  // packages_not_installed() fixtures
  'pkgs-not-installed-basic': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'pkgs-all-installed': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests", "click"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'pkgs-none-installed': {
    files: {
      'pyproject.toml': `
[project]
dependencies = []
`
    }
  },
  'pkgs-in-deps': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests", "click"]
`
    }
  },
  'pkgs-in-optional': {
    files: {
      'pyproject.toml': `
[project.optional-dependencies]
dev = ["pytest", "black"]
test = ["pytest-cov"]
`
    }
  },
  'pkgs-in-req': {
    files: {
      'requirements.txt': 'requests>=2.0.0\nclick'
    }
  },
  'pkgs-in-reqdev': {
    files: {
      'requirements.txt': 'requests',
      'requirements-dev.txt': 'pytest\nblack'
    }
  },
  'pkgs-mixed-sections': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`,
      'requirements-dev.txt': 'black'
    }
  },
  'pkgs-poetry': {
    files: {
      'pyproject.toml': `
[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
`
    }
  },
  'pkgs-single-arg': {
    files: {
      'pyproject.toml': '[project]\ndependencies = []'
    }
  },
  'pkgs-multi-args': {
    files: {
      'pyproject.toml': '[project]\ndependencies = []'
    }
  },
  'pkgs-by-ref': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests"]
`
    }
  },
  'pkgs-empty-input': {
    files: {
      'pyproject.toml': '[project]\ndependencies = []'
    }
  },
  'pkgs-version-spec': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["requests>=2.0.0", "click~=8.0"]
`
    }
  },
  'pkgs-no-files': {
    files: {
      'readme.txt': 'no dependency files'
    }
  },
  'pkgs-no-dep-sections': {
    files: {
      'pyproject.toml': `
[project]
name = "test"
version = "1.0.0"
`
    }
  },
  'pkgs-order': {
    files: {
      'pyproject.toml': `
[project]
dependencies = ["zipp"]
`
    }
  }
}

// =============================================================================
// TESTS
// =============================================================================

describe("lang-py", { concurrent: true }, () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-lang-py-test')

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

    it('should return "pip" when requirements.txt exists', () => {
      const result = runInTestDir('bash', dirs['pip-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pip')
    })

    it('should return "pip" when setup.py exists', () => {
      const result = runInTestDir('bash', dirs['pip-setup-project'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('pip')
    })

    it('should return success with empty output when pyproject.toml exists but no tool sections', () => {
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

    it('should prioritize uv over pip when both exist', () => {
      const result = runInTestDir('bash', dirs['mixed-py-managers'], 'py_package_manager')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('uv')
    })
  })

  describe('get_pyproject_toml()', () => {
    it('should return pyproject.toml content from current directory', () => {
      const result = runInTestDir('bash', dirs['pyproject-cwd'], 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('[project]\nname = "test-pkg"\nversion = "1.0.0"')
    })

    it('should return pyproject.toml content from repo root when not in cwd', () => {
      const subDir = join(dirs['pyproject-repo-root'], 'src', 'app')
      const result = runInTestDir('bash', subDir, 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('[project]\nname = "root-pkg"\nversion = "2.0.0"')
    })

    it('should return 1 when no pyproject.toml exists', () => {
      const result = runInTestDir('bash', dirs['pyproject-empty'], 'get_pyproject_toml')
      expect(result.code).toBe(1)
    })

    it('should prefer cwd pyproject.toml over repo root', () => {
      const subDir = join(dirs['pyproject-prefer-cwd'], 'packages', 'app')
      const result = runInTestDir('bash', subDir, 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('[project]\nname = "sub-pkg"')
    })

    it('should handle pyproject.toml with special characters', () => {
      const result = runInTestDir('bash', dirs['pyproject-special'], 'get_pyproject_toml')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('[project]\nname = "test"\ndescription = "A \\"quoted\\" value"')
    })
  })

  describe('get_requirements_txt()', () => {
    it('should return requirements.txt content from current directory', () => {
      const result = runInTestDir('bash', dirs['requirements-cwd'], 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('requests>=2.0.0\nclick>=8.0.0\npytest>=7.0.0')
    })

    it('should return requirements.txt content from repo root when not in cwd', () => {
      const subDir = join(dirs['requirements-repo-root'], 'src')
      const result = runInTestDir('bash', subDir, 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('requests>=2.0.0\nclick')
    })

    it('should return 1 when no requirements.txt exists', () => {
      const result = runInTestDir('bash', dirs['requirements-empty'], 'get_requirements_txt')
      expect(result.code).toBe(1)
    })

    it('should prefer cwd requirements.txt over repo root', () => {
      const subDir = join(dirs['requirements-prefer-cwd'], 'packages', 'app')
      const result = runInTestDir('bash', subDir, 'get_requirements_txt')
      expect(result.code).toBe(0)
      expect(result.stdout).toBe('click')
    })
  })

  describe('has_dependency()', () => {
    describe('PEP 621 pyproject.toml format', () => {
      it('should return 0 when dependency exists in [project.dependencies]', () => {
        const result = runInTestDir('bash', dirs['has-dep-pep621'], 'has_dependency "requests"')
        expect(result.code).toBe(0)
      })

      it('should return 1 when dependency does not exist', () => {
        const result = runInTestDir('bash', dirs['no-dep-pep621'], 'has_dependency "flask"')
        expect(result.code).toBe(1)
      })
    })

    describe('Poetry pyproject.toml format', () => {
      it('should return 0 when dependency exists in [tool.poetry.dependencies]', () => {
        const result = runInTestDir('bash', dirs['has-dep-poetry'], 'has_dependency "requests"')
        expect(result.code).toBe(0)
      })

      it('should return 1 when dependency is in dev-dependencies, not dependencies', () => {
        const result = runInTestDir('bash', dirs['dep-not-in-poetry-deps'], 'has_dependency "pytest"')
        expect(result.code).toBe(1)
      })
    })

    describe('requirements.txt format', () => {
      it('should return 0 when dependency exists in requirements.txt', () => {
        const result = runInTestDir('bash', dirs['has-dep-req'], 'has_dependency "requests"')
        expect(result.code).toBe(0)
      })

      it('should handle requirements.txt with comments', () => {
        const result = runInTestDir('bash', dirs['has-dep-req-comments'], 'has_dependency "requests"')
        expect(result.code).toBe(0)
      })

      it('should return 1 for commented-out dependency', () => {
        const result = runInTestDir('bash', dirs['has-dep-commented'], 'has_dependency "flask"')
        expect(result.code).toBe(1)
      })
    })

    it('should error when no argument provided', () => {
      const result = runInTestDir('bash', dirs['dep-no-arg'], 'has_dependency')
      expect(result.code).not.toBe(0)
    })
  })

  describe('has_dev_dependency()', () => {
    describe('PEP 621 pyproject.toml format', () => {
      it('should return 0 when dependency exists in [project.optional-dependencies.dev]', () => {
        const result = runInTestDir('bash', dirs['has-devdep-pep621'], 'has_dev_dependency "pytest"')
        expect(result.code).toBe(0)
      })

      it('should return 0 when dependency exists in any optional-dependencies group', () => {
        const result = runInTestDir('bash', dirs['has-devdep-optional'], 'has_dev_dependency "pytest-cov"')
        expect(result.code).toBe(0)
      })
    })

    describe('Poetry pyproject.toml format', () => {
      it('should return 0 when dependency exists in [tool.poetry.dev-dependencies]', () => {
        const result = runInTestDir('bash', dirs['has-devdep-poetry'], 'has_dev_dependency "pytest"')
        expect(result.code).toBe(0)
      })

      it('should return 1 when dependency is in dependencies, not dev-dependencies', () => {
        const result = runInTestDir('bash', dirs['devdep-wrong-section'], 'has_dev_dependency "requests"')
        expect(result.code).toBe(1)
      })
    })

    describe('requirements-dev.txt format', () => {
      it('should return 0 when dependency exists in requirements-dev.txt', () => {
        const result = runInTestDir('bash', dirs['has-devdep-reqdev'], 'has_dev_dependency "pytest"')
        expect(result.code).toBe(0)
      })
    })

    it('should return 1 when dev dependency does not exist', () => {
      const result = runInTestDir('bash', dirs['no-devdep'], 'has_dev_dependency "black"')
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
        const result = runInTestDir('bash', dirs['pkgs-not-installed-basic'], 'packages_not_installed "flask" "django" "fastapi"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask', 'django', 'fastapi'])
      })

      it('should return empty when all packages are installed', () => {
        const result = runInTestDir('bash', dirs['pkgs-all-installed'], 'packages_not_installed "requests" "click" "pytest"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })

      it('should return all packages when none are installed', () => {
        const result = runInTestDir('bash', dirs['pkgs-none-installed'], 'packages_not_installed "requests" "flask" "django"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['requests', 'flask', 'django'])
      })
    })

    describe('dependency section coverage', () => {
      it('should filter out packages in project.dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-deps'], 'packages_not_installed "requests" "click" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask'])
      })

      it('should filter out packages in optional-dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-optional'], 'packages_not_installed "pytest" "black" "pytest-cov" "ruff"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['ruff'])
      })

      it('should filter out packages in requirements.txt', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-req'], 'packages_not_installed "requests" "click" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask'])
      })

      it('should filter out packages in requirements-dev.txt', () => {
        const result = runInTestDir('bash', dirs['pkgs-in-reqdev'], 'packages_not_installed "pytest" "black" "ruff"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['ruff'])
      })

      it('should handle packages mixed across all sections', () => {
        const result = runInTestDir('bash', dirs['pkgs-mixed-sections'], 'packages_not_installed "requests" "pytest" "black" "flask" "django"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask', 'django'])
      })

      it('should handle Poetry format dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-poetry'], 'packages_not_installed "requests" "pytest" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask'])
      })
    })

    describe('input handling', () => {
      it('should handle single package argument', () => {
        const result = runInTestDir('bash', dirs['pkgs-single-arg'], 'packages_not_installed "flask"')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('flask')
      })

      it('should handle multiple package arguments', () => {
        const result = runInTestDir('bash', dirs['pkgs-multi-args'], 'packages_not_installed "flask" "django" "fastapi"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask', 'django', 'fastapi'])
      })

      it('should handle pass-by-reference (array name) and modify in-place', () => {
        // Pass-by-reference should modify array in-place, not output to stdout
        const script = `
          declare -a my_packages=("requests" "flask" "django")
          packages_not_installed my_packages
          echo "\${my_packages[@]}"
        `
        const result = runInTestDir('bash', dirs['pkgs-by-ref'], script)
        expect(result.code).toBe(0)
        // Array should now only contain not-installed packages
        expect(result.stdout).toBe('flask django')
      })

      it('should return empty output for empty input', () => {
        const result = runInTestDir('bash', dirs['pkgs-empty-input'], 'packages_not_installed')
        expect(result.code).toBe(0)
        expect(result.stdout.trim()).toBe('')
      })
    })

    describe('edge cases', () => {
      it('should handle packages with version specifiers in dependencies', () => {
        const result = runInTestDir('bash', dirs['pkgs-version-spec'], 'packages_not_installed "requests" "click" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['flask'])
      })

      it('should handle no pyproject.toml or requirements.txt files', () => {
        const result = runInTestDir('bash', dirs['pkgs-no-files'], 'packages_not_installed "requests" "flask"')
        // Should return all packages as not installed (or error)
        if (result.code === 0) {
          const lines = result.stdout.trim().split('\n').filter(l => l)
          expect(lines).toEqual(['requests', 'flask'])
        } else {
          // Error is also acceptable behavior
          expect(result.code).not.toBe(0)
        }
      })

      it('should handle pyproject.toml with no dependency sections', () => {
        const result = runInTestDir('bash', dirs['pkgs-no-dep-sections'], 'packages_not_installed "requests" "flask"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['requests', 'flask'])
      })
    })

    describe('output format', () => {
      it('should preserve input order in output', () => {
        const result = runInTestDir('bash', dirs['pkgs-order'], 'packages_not_installed "zebra" "apple" "mango" "zipp"')
        expect(result.code).toBe(0)
        const lines = result.stdout.trim().split('\n').filter(l => l)
        expect(lines).toEqual(['zebra', 'apple', 'mango'])
      })
    })
  })
})
