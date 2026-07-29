# Commit Lessons Learned

Permanent memory of non-obvious things discovered while making commits in this
monorepo. Add an entry only when a lesson is both (1) important/worthy and
(2) not already represented here or in `AGENTS.md`.

## Parallel / orchestrated commits

When multiple sub-agents commit concurrently against a single worktree (the
standard orchestrated-commit flow), the worktree is shared and HEAD is a moving
target.

- **Verify your own commit by hash, never by `HEAD`/`git log -1`.** Between the
  moment one agent's `git commit` returns and that agent runs its verification,
  another agent can land a commit on top. `git log -1` then shows the *other*
  agent's commit, not yours. Capture the hash straight from `git commit`'s
  output and confirm with `git show <hash>` / `git log -- <pathspec>`.

- **A deleted file can be committed directly via `git commit --only -- <path>`.**
  Including the path of a removed file as a pathspec records the deletion in the
  same step — no separate `git rm` / staging pass needed. This matters here
  because the workflow forbids unstaging/restaging (it can corrupt state when
  developers are editing concurrently) and mandates the explicit-pathspec style.
