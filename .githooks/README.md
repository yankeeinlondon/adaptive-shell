# Git Hooks

This directory contains example git hooks for the repository.

## Available Hooks

### pre-commit

Runs tests before allowing a commit to proceed.

**To enable:**

Option 1: Copy to .git/hooks directory
```bash
cp .githooks/pre-commit.example .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Option 2: Configure git to use .githooks directory globally
```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit.example
mv .githooks/pre-commit.example .githooks/pre-commit
```

**To bypass** (when necessary):
```bash
git commit --no-verify
```

## Creating Custom Hooks

1. Create a new file in `.githooks/` (e.g., `pre-push`)
2. Make it executable: `chmod +x .githooks/pre-push`
3. Follow the same pattern as existing hooks

## Hook Types

Git supports several hook types:
- `pre-commit` - Run before commit is created
- `pre-push` - Run before push is executed
- `commit-msg` - Validate commit message format
- `post-merge` - Run after merge completes

See [Git Hooks Documentation](https://git-scm.com/docs/githooks) for more details.
