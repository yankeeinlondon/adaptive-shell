import { describe, it, expect } from 'vitest'
import { sourceScript } from '../helpers'
import { execSync } from 'child_process'

/**
 * Helper to run install tests with mocks
 */
function runWithMocks(options: {
  availableCommands: string[]
  existingPackages: string[]
  installedPackages?: string[]
  installSucceeds?: string[]
  script: string
}): { calls: string[]; exitCode: number; output: string } {
  const { availableCommands, existingPackages, installedPackages = [], installSucceeds = [], script } = options

  const availableCmd = availableCommands.length > 0
    ? `mock_available_commands ${availableCommands.map(c => `"${c}"`).join(' ')}`
    : ''
  const existingPkgs = existingPackages.length > 0
    ? `mock_package_exists ${existingPackages.map(p => `"${p}"`).join(' ')}`
    : ''
  const installedPkgs = installedPackages.length > 0
    ? `mock_installed_packages ${installedPackages.map(p => `"${p}"`).join(' ')}`
    : ''
  const successPkgs = installSucceeds.length > 0
    ? `mock_install_succeeds ${installSucceeds.map(p => `"${p}"`).join(' ')}`
    : ''

  const fullScript = `
source utils/install.sh
source tests/helpers/install-mocks.sh
${availableCmd}
${existingPkgs}
${installedPkgs}
${successPkgs}
${script}
exit_code=$?
echo "---CALLS---"
for call in "\${MOCK_CALLS[@]}"; do
  echo "$call"
done
echo "---EXIT_CODE---"
echo "$exit_code"
`

  let output = ''
  try {
    output = execSync(fullScript, {
      shell: 'bash',
      encoding: 'utf-8',
      cwd: process.cwd(),
      stdio: ['pipe', 'pipe', 'pipe'],
      env: {
        ...process.env,
        ROOT: process.cwd()
      }
    })
  } catch (error: any) {
    output = error.stdout?.toString() || ''
  }

  const lines = output.trim().split('\n')
  const exitCodeIndex = lines.indexOf('---EXIT_CODE---')
  let exitCode = 0
  if (exitCodeIndex >= 0 && lines[exitCodeIndex + 1]) {
    exitCode = parseInt(lines[exitCodeIndex + 1], 10) || 0
  }

  const callsStartIndex = lines.indexOf('---CALLS---')
  const calls = callsStartIndex >= 0 && exitCodeIndex >= 0
    ? lines.slice(callsStartIndex + 1, exitCodeIndex).filter(l => l.trim())
    : []

  return { calls, exitCode, output }
}

describe('snap package manager support', () => {
  describe('_try_snap_install() helper function', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/install.sh')('type')('_try_snap_install')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should return 1 when snap is not available', () => {
      const result = runWithMocks({
        availableCommands: [],
        existingPackages: [],
        script: '_try_snap_install testpkg'
      })
      expect(result.exitCode).not.toBe(0)
      expect(result.calls).toContain('has_command:snap')
    })

    it('should install package when snap finds it', () => {
      const result = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: ['snap:jq'],
        script: '_try_snap_install jq'
      })
      expect(result.exitCode).toBe(0)
      expect(result.calls.some(c => c.startsWith('has_command:snap'))).toBe(true)
      expect(result.calls.some(c => c.startsWith('snap:install'))).toBe(true)
    })

    it('should try multiple package name variants in order', () => {
      const result = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: ['snap:ripgrep-bin'],
        script: '_try_snap_install ripgrep ripgrep-bin rg'
      })
      expect(result.exitCode).toBe(0)
      expect(result.calls.some(c => c === 'has_command:snap')).toBe(true)
      expect(result.calls.some(c => c.includes('snap:install:ripgrep-bin'))).toBe(true)
    })

    it('should return 1 when snap does not have any package variant', () => {
      const result = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: [],
        script: '_try_snap_install nonexistent-pkg'
      })
      expect(result.exitCode).not.toBe(0)
      expect(result.calls.some(c => c.startsWith('has_command:snap'))).toBe(true)
    })

    it('should handle installation failure gracefully', () => {
      const result = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: ['snap:jq'],
        installSucceeds: ['NONE'], // Sentinel: no packages should succeed
        script: '_try_snap_install jq'
      })
      expect(result.exitCode).not.toBe(0)
      expect(result.calls.some(c => c.startsWith('snap:install'))).toBe(true)
    })
  })
})
