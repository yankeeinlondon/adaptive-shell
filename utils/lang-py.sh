#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__LANG_PY_SH_LOADED:-}" ]] && declare -f "get_pyproject_toml" > /dev/null && return
__LANG_PY_SH_LOADED=1

if [ -z "${ADAPTIVE_SHELL}" ] || [[ "${ADAPTIVE_SHELL}" == "" ]]; then
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "${UTILS}" == *"/utils" ]];then
        ROOT="${UTILS%"/utils"}"
    else
        ROOT="$UTILS"
    fi
else
    ROOT="${ADAPTIVE_SHELL}"
    UTILS="${ROOT}/utils"
fi

# get_pyproject_toml()
#
# Attempts to read in content from pyproject.toml from current working
# directory and if that fails but the cwd is a repo then it will look
# for the pyproject.toml in the repo's root.
function get_pyproject_toml() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/filesystem.sh"
    source "${UTILS}/detection.sh"
    local content

    if [[ -f "./pyproject.toml" ]]; then
        content=$(get_file "./pyproject.toml")
    elif is_git_repo "." && [[ -f "$(repo_root ".")/pyproject.toml" ]]; then
        content=$(get_file "$(repo_root ".")/pyproject.toml")
    else
        return 1
    fi

    echo "${content}"
    return 0
}

# get_requirements_txt()
#
# Attempts to read in content from requirements.txt from current working
# directory and if that fails but the cwd is a repo then it will look
# for the requirements.txt in the repo's root.
function get_requirements_txt() {
    source "${UTILS}/logging.sh"
    source "${UTILS}/filesystem.sh"
    source "${UTILS}/detection.sh"
    local content

    if [[ -f "./requirements.txt" ]]; then
        content=$(get_file "./requirements.txt")
    elif is_git_repo "." && [[ -f "$(repo_root ".")/requirements.txt" ]]; then
        content=$(get_file "$(repo_root ".")/requirements.txt")
    else
        return 1
    fi

    echo "${content}"
    return 0
}

# _has_pyproject_dependency <dep>
#
# Check if a dependency exists in pyproject.toml (PEP 621 format).
# Searches in [project.dependencies] section.
_has_pyproject_dependency() {
    local dep="${1:?dependency name required}"
    local pyproject

    pyproject=$(get_pyproject_toml 2>/dev/null) || return 1

    # Check [project.dependencies] - array format like dependencies = ["requests>=2.0", "click"]
    # Match the package name at start of string or after quote, allowing for version specifiers
    if echo "$pyproject" | grep -E "^\s*dependencies\s*=\s*\[" >/dev/null 2>&1; then
        if echo "$pyproject" | grep -E "\"${dep}([<>=!~\[]|\")" >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

# _has_poetry_dependency <dep>
#
# Check if a dependency exists in Poetry format pyproject.toml.
# Searches in [tool.poetry.dependencies] section.
_has_poetry_dependency() {
    local dep="${1:?dependency name required}"
    local pyproject

    pyproject=$(get_pyproject_toml 2>/dev/null) || return 1

    # Check if we have [tool.poetry.dependencies] section
    if echo "$pyproject" | grep -qE '^\[tool\.poetry\.dependencies\]'; then
        # Extract the section and check for the dependency
        local in_section=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[tool\.poetry\.dependencies\] ]]; then
                in_section=1
                continue
            fi
            if [[ "$line" =~ ^\[.*\] ]] && [[ $in_section -eq 1 ]]; then
                break
            fi
            if [[ $in_section -eq 1 ]]; then
                # Match dependency = "version" or dependency = { ... }
                if [[ "$line" =~ ^${dep}[[:space:]]*= ]]; then
                    return 0
                fi
            fi
        done <<< "$pyproject"
    fi

    return 1
}

# _has_requirements_dependency <dep> [requirements_file]
#
# Check if a dependency exists in requirements.txt (or specified file).
# Handles version specifiers and ignores comments.
_has_requirements_dependency() {
    local dep="${1:?dependency name required}"
    local req_file="${2:-requirements.txt}"
    local content
    source "${UTILS}/detection.sh"

    # Try to find the requirements file
    local file_path=""
    if [[ -f "./${req_file}" ]]; then
        file_path="./${req_file}"
    elif is_git_repo "." && [[ -f "$(repo_root ".")/${req_file}" ]]; then
        file_path="$(repo_root ".")/${req_file}"
    fi

    [[ -z "$file_path" ]] && return 1

    content=$(cat "$file_path" 2>/dev/null) || return 1

    # Check each line, ignoring comments and empty lines
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Extract package name (before any version specifier)
        local pkg_name
        pkg_name=$(echo "$line" | sed -E 's/^[[:space:]]*([a-zA-Z0-9_-]+).*/\1/')

        if [[ "$pkg_name" == "$dep" ]]; then
            return 0
        fi
    done <<< "$content"

    return 1
}

# has_dependency <dep>
#
# Validates that `dep` exists in the main dependencies section
# of pyproject.toml (PEP 621 or Poetry format) or requirements.txt.
function has_dependency() {
    local -r dep="${1:?no package sent into has_dependency()!}"

    # Check pyproject.toml PEP 621 format
    if _has_pyproject_dependency "$dep"; then
        return 0
    fi

    # Check Poetry format
    if _has_poetry_dependency "$dep"; then
        return 0
    fi

    # Check requirements.txt
    if _has_requirements_dependency "$dep" "requirements.txt"; then
        return 0
    fi

    return 1
}

# _has_pyproject_optional_dependency <dep>
#
# Check if a dependency exists in any [project.optional-dependencies] group.
_has_pyproject_optional_dependency() {
    local dep="${1:?dependency name required}"
    local pyproject

    pyproject=$(get_pyproject_toml 2>/dev/null) || return 1

    # Check [project.optional-dependencies] section
    # Format: [project.optional-dependencies]
    #         dev = ["pytest", "black"]
    #         test = ["pytest-cov"]
    if echo "$pyproject" | grep -qE '^\[project\.optional-dependencies\]'; then
        local in_section=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[project\.optional-dependencies\] ]]; then
                in_section=1
                continue
            fi
            if [[ "$line" =~ ^\[.*\] ]] && [[ $in_section -eq 1 ]]; then
                break
            fi
            if [[ $in_section -eq 1 ]]; then
                # Check if the dependency appears in any array in this section
                if echo "$line" | grep -qE "\"${dep}([<>=!~\[]|\")"; then
                    return 0
                fi
            fi
        done <<< "$pyproject"
    fi

    return 1
}

# _has_poetry_dev_dependency <dep>
#
# Check if a dependency exists in Poetry dev-dependencies.
_has_poetry_dev_dependency() {
    local dep="${1:?dependency name required}"
    local pyproject

    pyproject=$(get_pyproject_toml 2>/dev/null) || return 1

    # Check if we have [tool.poetry.dev-dependencies] section
    if echo "$pyproject" | grep -qE '^\[tool\.poetry\.dev-dependencies\]'; then
        local in_section=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[tool\.poetry\.dev-dependencies\] ]]; then
                in_section=1
                continue
            fi
            if [[ "$line" =~ ^\[.*\] ]] && [[ $in_section -eq 1 ]]; then
                break
            fi
            if [[ $in_section -eq 1 ]]; then
                # Match dependency = "version" or dependency = { ... }
                if [[ "$line" =~ ^${dep}[[:space:]]*= ]]; then
                    return 0
                fi
            fi
        done <<< "$pyproject"
    fi

    return 1
}

# has_dev_dependency <dep>
#
# Validates that `dep` exists in dev/optional dependencies.
# Checks: [project.optional-dependencies], [tool.poetry.dev-dependencies],
# and requirements-dev.txt.
function has_dev_dependency() {
    local -r dep="${1:?no package sent into has_dev_dependency()!}"

    # Check pyproject.toml optional-dependencies
    if _has_pyproject_optional_dependency "$dep"; then
        return 0
    fi

    # Check Poetry dev-dependencies
    if _has_poetry_dev_dependency "$dep"; then
        return 0
    fi

    # Check requirements-dev.txt
    if _has_requirements_dependency "$dep" "requirements-dev.txt"; then
        return 0
    fi

    return 1
}

# has_dependency_anywhere <dep>
#
# Validates that `dep` exists in any dependency location.
function has_dependency_anywhere() {
    local -r dep="${1:?no package sent into has_dependency_anywhere()!}"

    if has_dependency "$dep" || has_dev_dependency "$dep"; then
        return 0
    else
        return 1
    fi
}

# packages_not_installed <pkg1> [pkg2] ... OR packages_not_installed <array_name>
#
# Receives a list of package names and returns only those which are not
# already in the project's dependency files.
#
# NOTE: Package list can be passed in _by ref_ (array name) or _by value_ (direct args)
#   - By reference: modifies the array IN-PLACE to contain only not-installed packages
#   - By value: outputs not-installed packages to stdout (newline-separated)
function packages_not_installed() {
    local first_arg="${1:-}"

    # No arguments - return empty
    if [[ -z "$first_arg" ]]; then
        return 0
    fi

    # Check if first arg is an array name (pass-by-reference)
    if [[ $# -eq 1 ]] && declare -p "$first_arg" 2>/dev/null | grep -q '^declare -a'; then
        # It's an array reference - modify in-place using eval for Bash 3.x compatibility
        local not_installed=()
        local pkg

        eval 'for pkg in "${'"$first_arg"'[@]}"; do
            if ! has_dependency_anywhere "$pkg"; then
                not_installed+=("$pkg")
            fi
        done'

        # Modify the original array in-place using eval
        eval "$first_arg"'=("${not_installed[@]}")'
    else
        # Direct arguments (pass-by-value) - output to stdout
        local pkg
        for pkg in "$@"; do
            if ! has_dependency_anywhere "$pkg"; then
                echo "$pkg"
            fi
        done
    fi

    return 0
}

# py_package_manager()
#
# Returns the Python package manager being used in this project:
#   - returns error code if this is NOT a Python project directory
#   - on success returns "poetry", "pipenv", "uv", "pdm", "hatch", "conda", or "pip"
#   - if unable to determine (but it IS a Python project directory) then will
#     output nothing but exit code will be successful
function py_package_manager() {
    source "${UTILS}/detection.sh"

    # Determine the repo root if in a git repo
    local root=""
    if is_git_repo "."; then
        root=$(repo_root ".")
    fi

    # Check if this looks like a Python project (check CWD first, then repo root)
    local is_python_project=0
    if [[ -f "./pyproject.toml" ]] || [[ -f "./requirements.txt" ]] || \
       [[ -f "./setup.py" ]] || [[ -f "./setup.cfg" ]] || [[ -f "./Pipfile" ]] || \
       [[ -f "./environment.yml" ]] || [[ -f "./poetry.lock" ]] || \
       [[ -f "./uv.lock" ]] || [[ -f "./pdm.lock" ]] || [[ -f "./Pipfile.lock" ]]; then
        is_python_project=1
    elif [[ -n "$root" ]]; then
        if [[ -f "${root}/pyproject.toml" ]] || [[ -f "${root}/requirements.txt" ]] || \
           [[ -f "${root}/setup.py" ]] || [[ -f "${root}/setup.cfg" ]] || [[ -f "${root}/Pipfile" ]] || \
           [[ -f "${root}/environment.yml" ]] || [[ -f "${root}/poetry.lock" ]] || \
           [[ -f "${root}/uv.lock" ]] || [[ -f "${root}/pdm.lock" ]] || [[ -f "${root}/Pipfile.lock" ]]; then
            is_python_project=1
        fi
    fi

    if [[ $is_python_project -eq 0 ]]; then
        return 1
    fi

    # Check lock files first (most definitive), then config files
    # Priority: poetry > pipenv > uv > pdm > hatch > conda > pip

    # Poetry: poetry.lock or [tool.poetry] in pyproject.toml
    if [[ -f "./poetry.lock" ]] || [[ -n "$root" && -f "${root}/poetry.lock" ]]; then
        echo "poetry"
        return 0
    fi
    if [[ -f "./pyproject.toml" ]] && grep -qE '^\[tool\.poetry\]' "./pyproject.toml" 2>/dev/null; then
        echo "poetry"
        return 0
    fi
    if [[ -n "$root" && -f "${root}/pyproject.toml" ]] && grep -qE '^\[tool\.poetry\]' "${root}/pyproject.toml" 2>/dev/null; then
        echo "poetry"
        return 0
    fi

    # Pipenv: Pipfile.lock or Pipfile
    if [[ -f "./Pipfile.lock" ]] || [[ -n "$root" && -f "${root}/Pipfile.lock" ]]; then
        echo "pipenv"
        return 0
    fi
    if [[ -f "./Pipfile" ]] || [[ -n "$root" && -f "${root}/Pipfile" ]]; then
        echo "pipenv"
        return 0
    fi

    # UV: uv.lock
    if [[ -f "./uv.lock" ]] || [[ -n "$root" && -f "${root}/uv.lock" ]]; then
        echo "uv"
        return 0
    fi

    # PDM: pdm.lock or [tool.pdm] in pyproject.toml
    if [[ -f "./pdm.lock" ]] || [[ -n "$root" && -f "${root}/pdm.lock" ]]; then
        echo "pdm"
        return 0
    fi
    if [[ -f "./pyproject.toml" ]] && grep -qE '^\[tool\.pdm\]' "./pyproject.toml" 2>/dev/null; then
        echo "pdm"
        return 0
    fi
    if [[ -n "$root" && -f "${root}/pyproject.toml" ]] && grep -qE '^\[tool\.pdm\]' "${root}/pyproject.toml" 2>/dev/null; then
        echo "pdm"
        return 0
    fi

    # Hatch: [tool.hatch] in pyproject.toml
    if [[ -f "./pyproject.toml" ]] && grep -qE '^\[tool\.hatch' "./pyproject.toml" 2>/dev/null; then
        echo "hatch"
        return 0
    fi
    if [[ -n "$root" && -f "${root}/pyproject.toml" ]] && grep -qE '^\[tool\.hatch' "${root}/pyproject.toml" 2>/dev/null; then
        echo "hatch"
        return 0
    fi

    # Conda: environment.yml
    if [[ -f "./environment.yml" ]] || [[ -n "$root" && -f "${root}/environment.yml" ]]; then
        echo "conda"
        return 0
    fi

    # Pip: requirements.txt or setup.py (fallback)
    if [[ -f "./requirements.txt" ]] || [[ -n "$root" && -f "${root}/requirements.txt" ]]; then
        echo "pip"
        return 0
    fi
    if [[ -f "./setup.py" ]] || [[ -n "$root" && -f "${root}/setup.py" ]]; then
        echo "pip"
        return 0
    fi

    # Python project but no recognized package manager
    return 0
}

# get_py_linter_by_dep()
#
# Attempts to determine the linter being used on a Python project
# by looking in the dev dependencies.
# Priority: ruff > flake8 > pylint > mypy > pyright
function get_py_linter_by_dep() {
    source "${UTILS}/logging.sh"

    if has_dev_dependency "ruff" || has_dependency "ruff"; then
        echo "ruff"
        return 0
    elif has_dev_dependency "flake8" || has_dependency "flake8"; then
        echo "flake8"
        return 0
    elif has_dev_dependency "pylint" || has_dependency "pylint"; then
        echo "pylint"
        return 0
    elif has_dev_dependency "mypy" || has_dependency "mypy"; then
        echo "mypy"
        return 0
    elif has_dev_dependency "pyright" || has_dependency "pyright"; then
        echo "pyright"
        return 0
    else
        return 1
    fi
}

# get_py_linter_by_config()
#
# Attempts to determine the linter being used on a Python project
# by looking for the associated configuration file(s).
# Checks CWD first, then repo root if in a git repository.
# Priority: ruff > flake8 > pylint > mypy > pyright
function get_py_linter_by_config() {
    source "${UTILS}/detection.sh"

    # Helper to check if a file exists in search directories
    _check_file() {
        local filename="$1"
        if [[ -f "./${filename}" ]]; then
            return 0
        fi
        local root
        if root=$(repo_root "." 2>/dev/null); then
            if [[ -f "${root}/${filename}" ]]; then
                return 0
            fi
        fi
        return 1
    }

    # Helper to check if pyproject.toml has a specific tool section
    _has_pyproject_tool() {
        local tool="$1"
        local pyproject
        pyproject=$(get_pyproject_toml 2>/dev/null) || return 1
        if echo "$pyproject" | grep -qE "^\[tool\.${tool}"; then
            return 0
        fi
        return 1
    }

    # Helper to check if setup.cfg has a specific section
    _has_setup_cfg_section() {
        local section="$1"
        local setup_cfg=""
        if [[ -f "./setup.cfg" ]]; then
            setup_cfg=$(cat "./setup.cfg")
        elif is_git_repo "." && [[ -f "$(repo_root ".")/setup.cfg" ]]; then
            setup_cfg=$(cat "$(repo_root ".")/setup.cfg")
        fi
        [[ -z "$setup_cfg" ]] && return 1
        if echo "$setup_cfg" | grep -qE "^\[${section}\]"; then
            return 0
        fi
        return 1
    }

    # Ruff
    if _check_file "ruff.toml" || _check_file ".ruff.toml" || _has_pyproject_tool "ruff"; then
        echo "ruff"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    # Flake8
    if _check_file ".flake8" || _has_setup_cfg_section "flake8"; then
        echo "flake8"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    # Pylint
    if _check_file ".pylintrc" || _check_file "pylintrc" || _has_pyproject_tool "pylint"; then
        echo "pylint"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    # Mypy
    if _check_file "mypy.ini" || _check_file ".mypy.ini" || _has_pyproject_tool "mypy"; then
        echo "mypy"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    # Pyright
    if _check_file "pyrightconfig.json" || _has_pyproject_tool "pyright"; then
        echo "pyright"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
    return 1
}

# get_py_formatter_by_dep()
#
# Attempts to determine the formatter being used on a Python project
# by looking in the dev dependencies.
# Priority: ruff > black > yapf > autopep8 > isort
function get_py_formatter_by_dep() {
    source "${UTILS}/logging.sh"

    if has_dev_dependency "ruff" || has_dependency "ruff"; then
        echo "ruff"
        return 0
    elif has_dev_dependency "black" || has_dependency "black"; then
        echo "black"
        return 0
    elif has_dev_dependency "yapf" || has_dependency "yapf"; then
        echo "yapf"
        return 0
    elif has_dev_dependency "autopep8" || has_dependency "autopep8"; then
        echo "autopep8"
        return 0
    elif has_dev_dependency "isort" || has_dependency "isort"; then
        echo "isort"
        return 0
    else
        return 1
    fi
}

# get_py_formatter_by_config()
#
# Attempts to determine the formatter being used on a Python project
# by looking for the associated configuration file(s).
# Priority: ruff > black > yapf > autopep8 > isort
function get_py_formatter_by_config() {
    source "${UTILS}/detection.sh"

    # Helper to check if a file exists in search directories
    _check_file() {
        local filename="$1"
        if [[ -f "./${filename}" ]]; then
            return 0
        fi
        local root
        if root=$(repo_root "." 2>/dev/null); then
            if [[ -f "${root}/${filename}" ]]; then
                return 0
            fi
        fi
        return 1
    }

    # Helper to check if pyproject.toml has a specific tool section
    _has_pyproject_tool() {
        local tool="$1"
        local pyproject
        pyproject=$(get_pyproject_toml 2>/dev/null) || return 1
        if echo "$pyproject" | grep -qE "^\[tool\.${tool}"; then
            return 0
        fi
        return 1
    }

    # Helper to check if setup.cfg has a specific section
    _has_setup_cfg_section() {
        local section="$1"
        local setup_cfg=""
        if [[ -f "./setup.cfg" ]]; then
            setup_cfg=$(cat "./setup.cfg")
        elif is_git_repo "." && [[ -f "$(repo_root ".")/setup.cfg" ]]; then
            setup_cfg=$(cat "$(repo_root ".")/setup.cfg")
        fi
        [[ -z "$setup_cfg" ]] && return 1
        if echo "$setup_cfg" | grep -qE "^\[${section}\]"; then
            return 0
        fi
        return 1
    }

    # Ruff (handles both linting and formatting)
    if _check_file "ruff.toml" || _check_file ".ruff.toml" || _has_pyproject_tool "ruff"; then
        echo "ruff"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    # Black
    if _has_pyproject_tool "black"; then
        echo "black"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    # YAPF
    if _check_file ".style.yapf" || _has_pyproject_tool "yapf"; then
        echo "yapf"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    # autopep8
    if _has_setup_cfg_section "tool:autopep8"; then
        echo "autopep8"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    # isort
    if _check_file ".isort.cfg" || _has_pyproject_tool "isort"; then
        echo "isort"
        unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
        return 0
    fi

    unset -f _check_file _has_pyproject_tool _has_setup_cfg_section
    return 1
}

# CLI invocation handler - allows running script directly with a function name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set up paths for sourcing dependencies
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${UTILS%"/utils"}"

    cmd="${1:-}"
    shift 2>/dev/null || true

    if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
        script_name="$(basename "${BASH_SOURCE[0]}")"
        echo "Usage: $script_name <function> [args...]"
        echo ""
        echo "Available functions:"
        # List all functions that don't start with _
        declare -F | awk '{print $3}' | grep -v '^_' | sort | sed 's/^/  /'
        exit 0
    fi

    # Check if function exists and call it
    if declare -f "$cmd" > /dev/null 2>&1; then
        "$cmd" "$@"
    else
        echo "Error: Unknown function '$cmd'" >&2
        echo "Run '$(basename "${BASH_SOURCE[0]}") --help' for available functions" >&2
        exit 1
    fi
fi
