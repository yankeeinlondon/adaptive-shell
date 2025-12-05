import { execSync, spawnSync } from 'child_process'

export type ShellType = 'bash' | 'zsh'

export interface ShellRunnerOptions {
  /** Working directory */
  cwd?: string
  /** Environment variables to set */
  env?: Record<string, string>
  /** Timeout in milliseconds */
  timeout?: number
}

export interface ShellRunnerResult {
  /** Standard output */
  stdout: string
  /** Standard error */
  stderr: string
  /** Exit code */
  code: number
  /** The shell that was used */
  shell: ShellType
}

/**
 * Run a script in a specific shell (bash or zsh)
 *
 * This utility allows testing shell scripts in both bash and zsh
 * to verify cross-shell compatibility.
 *
 * @example
 * ```typescript
 * // Test in bash
 * const bashResult = runInShell('bash', 'source ./utils/detection.sh && has_command ls')
 * expect(bashResult.code).toBe(0)
 *
 * // Test same thing in zsh
 * const zshResult = runInShell('zsh', 'source ./utils/detection.sh && has_command ls')
 * expect(zshResult.code).toBe(0)
 * ```
 */
export function runInShell(
  shell: ShellType,
  script: string,
  options?: ShellRunnerOptions
): ShellRunnerResult {
  const cwd = options?.cwd || process.cwd()
  const timeout = options?.timeout || 30000

  const env = {
    ...process.env,
    // Set CI=true to prevent _query_terminal_osc from trying to read from /dev/tty
    // which can hang indefinitely on WSL when running tests
    CI: 'true',
    ROOT: process.cwd(),
    ADAPTIVE_SHELL: process.cwd(),
    // Ensure ~/.local/bin is in PATH for user-installed tools (e.g., yq on WSL)
    PATH: `${process.env.HOME}/.local/bin:${process.env.PATH}`,
    ...options?.env
  }

  try {
    const result = spawnSync(shell, ['-c', script], {
      cwd,
      env,
      timeout,
      encoding: 'utf-8',
      // Don't inherit stdio - capture it
      stdio: ['pipe', 'pipe', 'pipe']
    })

    return {
      stdout: (result.stdout || '').trim(),
      stderr: (result.stderr || '').trim(),
      code: result.status ?? 1,
      shell
    }
  } catch (error: any) {
    return {
      stdout: '',
      stderr: error.message || 'Unknown error',
      code: error.status || 1,
      shell
    }
  }
}

/**
 * Run a script in both bash and zsh, returning both results
 *
 * @example
 * ```typescript
 * const { bash, zsh } = runInBothShells('source ./utils/detection.sh && has_command ls')
 * expect(bash.code).toBe(zsh.code) // Should behave the same
 * ```
 */
export function runInBothShells(
  script: string,
  options?: ShellRunnerOptions
): { bash: ShellRunnerResult; zsh: ShellRunnerResult } {
  return {
    bash: runInShell('bash', script, options),
    zsh: runInShell('zsh', script, options)
  }
}

/**
 * Get the exit code from running a script in a specific shell
 */
export function shellExitCode(
  shell: ShellType,
  script: string,
  options?: ShellRunnerOptions
): number {
  return runInShell(shell, script, options).code
}

/**
 * Check if a shell is available on the system
 */
export function isShellAvailable(shell: ShellType): boolean {
  try {
    const result = spawnSync('which', [shell], { encoding: 'utf-8' })
    return result.status === 0
  } catch {
    return false
  }
}

/**
 * Helper to run tests in both shells and compare results
 * Throws if the behavior differs between shells
 */
export function assertSameBehavior(
  script: string,
  options?: ShellRunnerOptions
): void {
  const { bash, zsh } = runInBothShells(script, options)

  if (bash.code !== zsh.code) {
    throw new Error(
      `Shell behavior differs!\n` +
      `Script: ${script}\n` +
      `Bash: code=${bash.code}, stdout="${bash.stdout}", stderr="${bash.stderr}"\n` +
      `Zsh:  code=${zsh.code}, stdout="${zsh.stdout}", stderr="${zsh.stderr}"`
    )
  }
}
