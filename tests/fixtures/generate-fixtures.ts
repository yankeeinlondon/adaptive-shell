/**
 * Fixture Generator & Documentation
 *
 * This script defines the canonical fixture structures for lang-js, lang-py, and lang-rs tests.
 * It generates the permanent (static) fixture directories from the FIXTURES definitions below.
 *
 * Usage:
 *   npx tsx tests/fixtures/generate-fixtures.ts
 *
 * When to run:
 *   - After adding new fixture definitions to regenerate the fixture directories
 *   - To verify fixture structure matches definitions
 *   - If fixtures become corrupted or need updates
 *
 * Architecture:
 *   - Static fixtures: Created once and committed to the repository (~178 fixtures)
 *   - Git fixtures: Must be created dynamically in tests because they require actual
 *     git repository initialization (cannot include .git/ in version control)
 *
 * The TypeScript interfaces (FileFixture, GitFixture) serve as documentation
 * for the expected fixture schema.
 *
 * Note: Git-based fixtures are skipped when running this script; they must be
 * created dynamically in test beforeAll() hooks using the GitFixtureManager utility.
 */

import { mkdirSync, writeFileSync, existsSync } from 'fs'
import { join, dirname } from 'path'

const FIXTURES_DIR = join(process.cwd(), 'tests', 'fixtures')

interface FileFixture {
  files: Record<string, string>
  subdirs?: string[]
}

interface GitFixture extends FileFixture {
  git: true
  commits?: Array<{ file: string; content: string; message: string }>
}

type Fixture = FileFixture | GitFixture

function isGitFixture(fixture: Fixture): fixture is GitFixture {
  return 'git' in fixture && fixture.git === true
}

function createFixture(category: string, name: string, fixture: Fixture): void {
  if (isGitFixture(fixture)) {
    console.log(`  [SKIP] ${name} (requires git)`)
    return
  }

  const fixtureDir = join(FIXTURES_DIR, category, name)

  // Create subdirectories first if specified
  if (fixture.subdirs) {
    for (const subdir of fixture.subdirs) {
      mkdirSync(join(fixtureDir, subdir), { recursive: true })
    }
  } else {
    mkdirSync(fixtureDir, { recursive: true })
  }

  // Write all files
  for (const [filename, content] of Object.entries(fixture.files)) {
    const filePath = join(fixtureDir, filename)
    const fileDir = dirname(filePath)
    if (!existsSync(fileDir)) {
      mkdirSync(fileDir, { recursive: true })
    }
    writeFileSync(filePath, content)
  }

  console.log(`  [OK] ${name}`)
}

// ============================================================================
// LANG-PY FIXTURES
// ============================================================================

const LANG_PY_FIXTURES: Record<string, Fixture> = {
  // py_package_manager() fixtures
  'poetry-project': {
    files: {
      'pyproject.toml': '[tool.poetry]\nname = "test"',
      'poetry.lock': '# Poetry lock file'
    }
  },
  'poetry-no-lock': {
    files: {
      'pyproject.toml': `[tool.poetry]
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
      'pyproject.toml': `[project]
name = "test"

[tool.pdm]
`
    }
  },
  'hatch-project': {
    files: {
      'pyproject.toml': `[project]
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
  'has-dep-pep621': {
    files: {
      'pyproject.toml': `[project]
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
      'pyproject.toml': `[project]
name = "test"
dependencies = ["requests"]
`
    }
  },
  'has-dep-poetry': {
    files: {
      'pyproject.toml': `[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"
click = "^8.0.0"
`
    }
  },
  'dep-not-in-poetry-deps': {
    files: {
      'pyproject.toml': `[tool.poetry.dependencies]
python = "^3.9"
requests = "^2.28.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
`
    }
  },
  'has-dep-req': {
    files: {
      'requirements.txt': `requests>=2.0.0
click>=8.0.0
pytest
`
    }
  },
  'has-dep-req-comments': {
    files: {
      'requirements.txt': `# Web framework
requests>=2.0.0
# CLI
click>=8.0.0
`
    }
  },
  'has-dep-commented': {
    files: {
      'requirements.txt': `requests>=2.0.0
# flask>=2.0.0
`
    }
  },
  'dep-no-arg': {
    files: {
      'pyproject.toml': '[project]\nname = "test"'
    }
  },
  'has-devdep-pep621': {
    files: {
      'pyproject.toml': `[project]
name = "test"

[project.optional-dependencies]
dev = ["pytest>=7.0.0", "ruff>=0.1.0"]
test = ["pytest-cov"]
`
    }
  },
  'has-devdep-optional': {
    files: {
      'pyproject.toml': `[project]
name = "test"

[project.optional-dependencies]
test = ["pytest-cov"]
lint = ["ruff"]
`
    }
  },
  'has-devdep-poetry': {
    files: {
      'pyproject.toml': `[tool.poetry.dependencies]
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
      'pyproject.toml': `[tool.poetry.dependencies]
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
      'requirements-dev.txt': `pytest>=7.0.0
black>=23.0.0
`
    }
  },
  'no-devdep': {
    files: {
      'pyproject.toml': `[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'devdep-no-arg': {
    files: {
      'pyproject.toml': '[project]\nname = "test"'
    }
  },
  'has-anywhere-deps': {
    files: {
      'pyproject.toml': `[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'has-anywhere-optional': {
    files: {
      'pyproject.toml': `[project]
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
      'pyproject.toml': `[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'linter-dep-ruff': {
    files: {
      'pyproject.toml': `[project.optional-dependencies]
dev = ["ruff>=0.1.0"]
`
    }
  },
  'linter-dep-flake8': {
    files: {
      'pyproject.toml': `[tool.poetry.dev-dependencies]
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
      'pyproject.toml': `[project.optional-dependencies]
dev = ["pyright"]
`
    }
  },
  'linter-dep-none': {
    files: {
      'pyproject.toml': `[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'linter-dep-priority': {
    files: {
      'requirements-dev.txt': `flake8>=6.0.0
pylint>=2.0.0
ruff>=0.1.0
`
    }
  },
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
      'pyproject.toml': `[project]
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
      'setup.cfg': `[metadata]
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
  'formatter-dep-ruff': {
    files: {
      'requirements-dev.txt': 'ruff>=0.1.0'
    }
  },
  'formatter-dep-black': {
    files: {
      'pyproject.toml': `[tool.poetry.dev-dependencies]
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
      'pyproject.toml': `[project.optional-dependencies]
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
      'requirements-dev.txt': `black
yapf
ruff
`
    }
  },
  'formatter-config-ruff': {
    files: {
      'ruff.toml': 'line-length = 88'
    }
  },
  'formatter-config-black': {
    files: {
      'pyproject.toml': `[project]
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
      'setup.cfg': `[metadata]
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
      'pyproject.toml': `[tool.black]
line-length = 88
`
    }
  },
  'pkgs-not-installed-basic': {
    files: {
      'pyproject.toml': `[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'pkgs-all-installed': {
    files: {
      'pyproject.toml': `[project]
dependencies = ["requests", "click"]

[project.optional-dependencies]
dev = ["pytest"]
`
    }
  },
  'pkgs-none-installed': {
    files: {
      'pyproject.toml': `[project]
dependencies = []
`
    }
  },
  'pkgs-in-deps': {
    files: {
      'pyproject.toml': `[project]
dependencies = ["requests", "click"]
`
    }
  },
  'pkgs-in-optional': {
    files: {
      'pyproject.toml': `[project.optional-dependencies]
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
      'pyproject.toml': `[project]
dependencies = ["requests"]

[project.optional-dependencies]
dev = ["pytest"]
`,
      'requirements-dev.txt': 'black'
    }
  },
  'pkgs-poetry': {
    files: {
      'pyproject.toml': `[tool.poetry.dependencies]
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
      'pyproject.toml': `[project]
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
      'pyproject.toml': `[project]
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
      'pyproject.toml': `[project]
name = "test"
version = "1.0.0"
`
    }
  },
  'pkgs-order': {
    files: {
      'pyproject.toml': `[project]
dependencies = ["zipp"]
`
    }
  }
}

// ============================================================================
// LANG-RS FIXTURES
// ============================================================================

const LANG_RS_FIXTURES: Record<string, Fixture> = {
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

// ============================================================================
// LANG-JS FIXTURES
// ============================================================================

const LANG_JS_FIXTURES: Record<string, Fixture> = {
  // js_package_manager() fixtures
  'pnpm-project': {
    files: {
      'package.json': '{"name": "test"}',
      'pnpm-lock.yaml': 'lockfileVersion: 6.0'
    }
  },
  'pnpm-workspace-project': {
    files: {
      'package.json': '{"name": "test"}',
      'pnpm-workspace.yaml': 'packages:\n  - "packages/*"'
    }
  },
  'npm-project': {
    files: {
      'package.json': '{"name": "test"}',
      'package-lock.json': '{"lockfileVersion": 2}'
    }
  },
  'yarn-project': {
    files: {
      'package.json': '{"name": "test"}',
      'yarn.lock': '# yarn lockfile v1'
    }
  },
  'bun-project': {
    files: {
      'package.json': '{"name": "test"}',
      'bun.lockb': ''
    }
  },
  'deno-project': {
    files: {
      'package.json': '{"name": "test"}',
      'deno.lock': '{"version": "2"}'
    }
  },
  'js-no-lock': {
    files: {
      'package.json': '{"name": "test"}'
    }
  },
  'non-js-project': {
    files: {
      'readme.txt': 'not a js project'
    }
  },
  'mixed-locks': {
    files: {
      'package.json': '{"name": "test"}',
      'pnpm-lock.yaml': 'lockfileVersion: 6.0',
      'package-lock.json': '{"lockfileVersion": 2}'
    }
  },
  'no-lockfile': {
    files: {
      'package.json': '{"name": "test"}'
    }
  },
  'pkg-json-cwd': {
    files: {
      'package.json': '{"name": "test-pkg", "version": "1.0.0"}'
    }
  },
  'pkg-json-empty': {
    files: {
      'readme.txt': 'no package.json here'
    }
  },
  'pkg-json-special': {
    files: {
      'package.json': '{"name": "test", "description": "A \\"quoted\\" value"}'
    }
  },

  // has_dev_dependency() fixtures
  'has-dev-dep': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "vitest": "^1.0.0", "typescript": "^5.0.0" }
      })
    }
  },
  'no-dev-dep': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "vitest": "^1.0.0" }
      })
    }
  },
  'no-dev-deps-section': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0" }
      })
    }
  },
  'dep-wrong-section': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0" },
        devDependencies: {}
      })
    }
  },
  'dev-dep-no-arg': {
    files: {
      'package.json': '{"name": "test"}'
    }
  },

  // has_dependency() fixtures
  'has-dep': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0", "express": "^4.18.0" }
      })
    }
  },
  'no-dep': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0" }
      })
    }
  },
  'no-deps-section': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "vitest": "^1.0.0" }
      })
    }
  },
  'dev-not-in-deps': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: {},
        devDependencies: { "vitest": "^1.0.0" }
      })
    }
  },
  'dep-no-arg': {
    files: {
      'package.json': '{"name": "test"}'
    }
  },

  // has_peer_dependency() fixtures
  'has-peer-dep': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        peerDependencies: { "react": "^18.0.0", "react-dom": "^18.0.0" }
      })
    }
  },
  'no-peer-dep': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        peerDependencies: { "react": "^18.0.0" }
      })
    }
  },
  'no-peer-deps-section': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0" }
      })
    }
  },
  'dep-not-in-peer': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0" },
        peerDependencies: {}
      })
    }
  },
  'peer-dep-no-arg': {
    files: {
      'package.json': '{"name": "test"}'
    }
  },

  // get_js_linter_by_dep() fixtures
  'linter-dep-eslint': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "eslint": "^8.0.0" }
      })
    }
  },
  'linter-dep-biomejs': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "@biomejs/biome": "^1.9.0" }
      })
    }
  },
  'linter-dep-biome-unscoped': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "biome": "^1.0.0" }
      })
    }
  },
  'linter-dep-oxlint': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "oxlint": "^0.1.0" }
      })
    }
  },
  'linter-dep-tsslint': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "tsslint": "^1.0.0" }
      })
    }
  },
  'linter-dep-none': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "vitest": "^1.0.0" }
      })
    }
  },
  'linter-dep-priority': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: {
          "@biomejs/biome": "^1.9.0",
          "eslint": "^8.0.0",
          "oxlint": "^0.1.0"
        }
      })
    }
  },

  // packages_not_installed() fixtures
  'pkgs-not-installed-basic': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0" },
        devDependencies: { "vitest": "^1.0.0" }
      })
    }
  },
  'pkgs-all-installed': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0", "express": "^4.0.0" },
        devDependencies: { "vitest": "^1.0.0" }
      })
    }
  },
  'pkgs-none-installed': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: {},
        devDependencies: {}
      })
    }
  },
  'pkgs-in-deps': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0", "express": "^4.0.0" }
      })
    }
  },
  'pkgs-in-devdeps': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "vitest": "^1.0.0", "typescript": "^5.0.0" }
      })
    }
  },
  'pkgs-in-peerdeps': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        peerDependencies: { "react": "^18.0.0", "react-dom": "^18.0.0" }
      })
    }
  },
  'pkgs-mixed-sections': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0" },
        devDependencies: { "vitest": "^1.0.0" },
        peerDependencies: { "react": "^18.0.0" }
      })
    }
  },
  'pkgs-single-arg': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: {}
      })
    }
  },
  'pkgs-multi-args': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: {}
      })
    }
  },
  'pkgs-by-ref': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "lodash": "^4.0.0" }
      })
    }
  },
  'pkgs-empty-input': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: {}
      })
    }
  },
  'pkgs-scoped': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        devDependencies: { "@biomejs/biome": "^1.9.0" }
      })
    }
  },
  'pkgs-no-dep-sections': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        version: "1.0.0"
      })
    }
  },
  'pkgs-order': {
    files: {
      'package.json': JSON.stringify({
        name: "test",
        dependencies: { "zlib": "^1.0.0" }
      })
    }
  }
}

// ============================================================================
// MAIN
// ============================================================================

console.log('Generating fixtures...\n')

console.log('lang-py fixtures:')
for (const [name, fixture] of Object.entries(LANG_PY_FIXTURES)) {
  createFixture('lang-py', name, fixture)
}

console.log('\nlang-rs fixtures:')
for (const [name, fixture] of Object.entries(LANG_RS_FIXTURES)) {
  createFixture('lang-rs', name, fixture)
}

console.log('\nlang-js fixtures:')
for (const [name, fixture] of Object.entries(LANG_JS_FIXTURES)) {
  createFixture('lang-js', name, fixture)
}

console.log('\nDone! Git-based fixtures must still be created dynamically in tests.')
