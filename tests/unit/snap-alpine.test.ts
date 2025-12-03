import { describe, it, expect } from 'vitest'
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

describe('snap support in install_on_alpine()', () => {
  describe('package manager priority', () => {
    it('should prefer apk over snap when both have the package', () => {
      const result = runWithMocks({
        availableCommands: ['apk', 'snap'],
        existingPackages: ['apk:jq', 'snap:jq'],
        script: 'install_on_alpine jq'
      })
      expect(result.exitCode).toBe(0)
      expect(result.calls.some(c => c.startsWith('apk:add'))).toBe(true)
      expect(result.calls.some(c => c.startsWith('snap:install'))).toBe(false)
    })

    it('should fall back to snap when apk does not have the package', () => {
      const result = runWithMocks({
        availableCommands: ['apk', 'snap'],
        existingPackages: ['snap:jq'],
        script: 'install_on_alpine jq'
      })
      expect(result.exitCode).toBe(0)
      expect(result.calls.some(c => c.startsWith('snap:install'))).toBe(true)
    })

    it('should prefer snap over nix-env when snap has the package', () => {
      const result = runWithMocks({
        availableCommands: ['snap', 'nix-env'],
        existingPackages: ['snap:jq', 'nix:jq'],
        script: 'install_on_alpine jq'
      })
      expect(result.exitCode).toBe(0)
      const snapIndex = result.calls.findIndex(c => c.startsWith('snap:'))
      const nixIndex = result.calls.findIndex(c => c.startsWith('nix-env:'))
      expect(snapIndex).toBeGreaterThan(-1)
      expect(nixIndex).toBe(-1)
    })

    it('should prefer snap over cargo when snap has the package', () => {
      const result = runWithMocks({
        availableCommands: ['snap', 'cargo'],
        existingPackages: ['snap:ripgrep', 'cargo:ripgrep'],
        script: 'install_on_alpine ripgrep'
      })
      expect(result.exitCode).toBe(0)
      const snapIndex = result.calls.findIndex(c => c.startsWith('snap:'))
      const cargoIndex = result.calls.findIndex(c => c.startsWith('cargo:'))
      expect(snapIndex).toBeGreaterThan(-1)
      expect(cargoIndex).toBe(-1)
    })

    it('should fall back to nix when snap does not have the package', () => {
      const result = runWithMocks({
        availableCommands: ['snap', 'nix-env'],
        existingPackages: ['nix:jq'],
        script: 'install_on_alpine jq'
      })
      expect(result.exitCode).toBe(0)
      expect(result.calls.some(c => c.startsWith('has_command:snap'))).toBe(true)
      expect(result.calls.some(c => c.startsWith('nix-env:'))).toBe(true)
    })

    it('should fall back to cargo when snap does not have the package', () => {
      const result = runWithMocks({
        availableCommands: ['snap', 'cargo'],
        existingPackages: ['cargo:ripgrep'],
        script: 'install_on_alpine ripgrep'
      })
      expect(result.exitCode).toBe(0)
      expect(result.calls.some(c => c.startsWith('has_command:snap'))).toBe(true)
      expect(result.calls.some(c => c.startsWith('cargo:'))).toBe(true)
    })
  })

  describe('--prefer-snap flag', () => {
    it('should try snap before apk when --prefer-snap is set', () => {
      const result = runWithMocks({
        availableCommands: ['apk', 'snap'],
        existingPackages: ['apk:jq', 'snap:jq'],
        script: 'install_on_alpine --prefer-snap jq'
      })
      expect(result.exitCode).toBe(0)
      const snapIndex = result.calls.findIndex(c => c.startsWith('snap:'))
      const apkIndex = result.calls.findIndex(c => c.startsWith('apk:'))
      expect(snapIndex).toBeGreaterThan(-1)
      expect(apkIndex).toBe(-1)
    })

    it('should fall back to apk when snap does not have the package', () => {
      const result = runWithMocks({
        availableCommands: ['apk', 'snap'],
        existingPackages: ['apk:jq'],
        script: 'install_on_alpine --prefer-snap jq'
      })
      expect(result.exitCode).toBe(0)
      expect(result.calls.some(c => c === 'has_command:snap')).toBe(true)
      expect(result.calls.some(c => c.startsWith('apk:add'))).toBe(true)
    })

    it('should not try snap twice when --prefer-snap is set', () => {
      const result = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: ['snap:jq'],
        script: 'install_on_alpine --prefer-snap jq'
      })
      expect(result.exitCode).toBe(0)
      const snapInstallCalls = result.calls.filter(c => c.startsWith('snap:install'))
      expect(snapInstallCalls.length).toBe(1)
    })

    it('should accept --prefer-snap at any position', () => {
      const resultBeginning = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: ['snap:jq'],
        script: 'install_on_alpine --prefer-snap jq'
      })
      expect(resultBeginning.exitCode).toBe(0)

      const resultMiddle = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: ['snap:jq'],
        script: 'install_on_alpine jq --prefer-snap pkg2'
      })
      expect(resultMiddle.calls.some(c => c === 'has_command:snap')).toBe(true)

      const resultEnd = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: ['snap:jq'],
        script: 'install_on_alpine jq pkg2 --prefer-snap'
      })
      expect(resultEnd.calls.some(c => c === 'has_command:snap')).toBe(true)
    })
  })

  describe('error handling with --prefer-snap', () => {
    it('should error when no package is provided with --prefer-snap', () => {
      const result = runWithMocks({
        availableCommands: ['snap'],
        existingPackages: [],
        script: 'install_on_alpine --prefer-snap'
      })
      expect(result.exitCode).not.toBe(0)
    })

    it('should return failure when no package manager has the package', () => {
      const result = runWithMocks({
        availableCommands: ['apk', 'snap', 'nix-env', 'cargo'],
        existingPackages: [],
        script: 'install_on_alpine --prefer-snap nonexistent-pkg'
      })
      expect(result.exitCode).not.toBe(0)
    })
  })
})
