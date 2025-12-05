/**
 * Platform detection utilities for test skipping
 *
 * WSL and Windows environments have limitations with git repo operations
 * and file system behaviors that can cause tests to hang or fail.
 */

/**
 * Detect if running on native Windows
 */
export const isWindows = process.platform === 'win32'

/**
 * Detect if running on WSL (Windows Subsystem for Linux)
 *
 * Checks multiple indicators since not all WSL distributions set all env vars:
 * - WSL_DISTRO_NAME: Set by WSL2
 * - WSL_INTEROP: Set by WSL interop
 * - /mnt/c path: Common WSL mount point for Windows C: drive
 */
export const isWSL = process.platform === 'linux' && (
  !!process.env.WSL_DISTRO_NAME ||
  !!process.env.WSL_INTEROP ||
  process.cwd().startsWith('/mnt/c') ||
  process.cwd().startsWith('/mnt/d')
)

/**
 * Skip tests that have issues on Windows or WSL
 *
 * Use with vitest's skipIf:
 * ```typescript
 * describe.skipIf(isWindowsOrWSL)('tests that need native Unix', () => { ... })
 * it.skipIf(isWindowsOrWSL)('test that needs git repo root', () => { ... })
 * ```
 */
export const isWindowsOrWSL = isWindows || isWSL

/**
 * Detect if running in a CI environment
 */
export const isCI = !!process.env.CI

/**
 * Detect if running on macOS
 */
export const isMacOS = process.platform === 'darwin'

/**
 * Detect if running on native Linux (not WSL)
 */
export const isLinux = process.platform === 'linux' && !isWSL
