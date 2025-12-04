import { describe, it, expect } from 'vitest'
import { sourceScript } from "../../helpers"
import { execSync } from 'child_process'

/**
 * Helper to run install tests with mocks
 *
 * Sources install.sh first, then our mocks to override has_command and package managers.
 * Returns an object with the mock calls and exit code.
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

describe('Windows installation support', () => {
  describe('install_on_windows()', () => {
    describe('error handling', () => {
      it('should error when no package is provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_windows')()
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })

      it('should error when only flags are provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_windows')('--prefer-choco')
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })
    })

    describe('package manager priority', () => {
      it('should try winget first when available', () => {
        const result = runWithMocks({
          availableCommands: ['winget', 'choco', 'scoop'],
          existingPackages: ['winget:jq', 'choco:jq', 'scoop:jq'],
          script: 'install_on_windows jq'
        })
        expect(result.exitCode).toBe(0)
        // winget should be tried first
        expect(result.calls.some(c => c.startsWith('winget:search'))).toBe(true)
        // If winget has the package, choco/scoop should not be called for install
        expect(result.calls.some(c => c.startsWith('winget:install'))).toBe(true)
      })

      it('should fall back to chocolatey when winget does not have package', () => {
        const result = runWithMocks({
          availableCommands: ['winget', 'choco'],
          existingPackages: ['choco:jq'], // jq only in choco, not winget
          script: 'install_on_windows jq'
        })
        expect(result.exitCode).toBe(0)
        // Should try winget first, then choco
        expect(result.calls.some(c => c.startsWith('winget:search'))).toBe(true)
        expect(result.calls.some(c => c.startsWith('choco:search'))).toBe(true)
        expect(result.calls.some(c => c.startsWith('choco:install'))).toBe(true)
      })

      it('should fall back to scoop when winget and choco do not have package', () => {
        const result = runWithMocks({
          availableCommands: ['winget', 'choco', 'scoop'],
          existingPackages: ['scoop:jq'], // jq only in scoop
          script: 'install_on_windows jq'
        })
        expect(result.exitCode).toBe(0)
        // Should try all three in order
        expect(result.calls.some(c => c.startsWith('winget:search'))).toBe(true)
        expect(result.calls.some(c => c.startsWith('choco:search'))).toBe(true)
        expect(result.calls.some(c => c.startsWith('scoop:search'))).toBe(true)
        expect(result.calls.some(c => c.startsWith('scoop:install'))).toBe(true)
      })

      it('should return failure if no package manager has the package', () => {
        const result = runWithMocks({
          availableCommands: ['winget', 'choco', 'scoop'],
          existingPackages: [], // package not available anywhere
          script: 'install_on_windows nonexistent-pkg'
        })
        expect(result.exitCode).not.toBe(0)
      })

      it('should return failure when no package managers are available', () => {
        const result = runWithMocks({
          availableCommands: [], // no package managers
          existingPackages: [],
          script: 'install_on_windows jq'
        })
        expect(result.exitCode).not.toBe(0)
      })
    })

    describe('--prefer-choco flag', () => {
      it('should try chocolatey first when --prefer-choco is set', () => {
        const result = runWithMocks({
          availableCommands: ['winget', 'choco'],
          existingPackages: ['winget:jq', 'choco:jq'],
          script: 'install_on_windows --prefer-choco jq'
        })
        expect(result.exitCode).toBe(0)
        // choco should be tried before winget
        const chocoIndex = result.calls.findIndex(c => c.startsWith('choco:search'))
        const wingetIndex = result.calls.findIndex(c => c.startsWith('winget:search'))
        // choco should come first, winget should not even be searched since choco succeeds
        expect(chocoIndex).toBeGreaterThan(-1)
        expect(wingetIndex).toBe(-1)
      })

      it('should fall back to other managers if choco fails', () => {
        const result = runWithMocks({
          availableCommands: ['winget', 'choco'],
          existingPackages: ['winget:jq'], // not in choco
          script: 'install_on_windows --prefer-choco jq'
        })
        expect(result.exitCode).toBe(0)
        // choco searched but not found, then winget
        expect(result.calls.some(c => c.startsWith('choco:search'))).toBe(true)
        expect(result.calls.some(c => c.startsWith('winget:install'))).toBe(true)
      })
    })

    describe('--prefer-scoop flag', () => {
      it('should try scoop first when --prefer-scoop is set', () => {
        const result = runWithMocks({
          availableCommands: ['winget', 'scoop'],
          existingPackages: ['winget:jq', 'scoop:jq'],
          script: 'install_on_windows --prefer-scoop jq'
        })
        expect(result.exitCode).toBe(0)
        // scoop should be tried first
        const scoopIndex = result.calls.findIndex(c => c.startsWith('scoop:search'))
        const wingetIndex = result.calls.findIndex(c => c.startsWith('winget:search'))
        expect(scoopIndex).toBeGreaterThan(-1)
        expect(wingetIndex).toBe(-1)
      })

      it('should fall back to other managers if scoop fails', () => {
        const result = runWithMocks({
          availableCommands: ['winget', 'scoop'],
          existingPackages: ['winget:jq'], // not in scoop
          script: 'install_on_windows --prefer-scoop jq'
        })
        expect(result.exitCode).toBe(0)
        expect(result.calls.some(c => c.startsWith('scoop:search'))).toBe(true)
        expect(result.calls.some(c => c.startsWith('winget:install'))).toBe(true)
      })
    })

    describe('multiple package name variants', () => {
      it('should try each package name in order until one succeeds', () => {
        const result = runWithMocks({
          availableCommands: ['winget'],
          existingPackages: ['winget:jqlang.jq'], // winget uses different package ID
          script: 'install_on_windows jq jqlang.jq'
        })
        expect(result.exitCode).toBe(0)
        // Should try jq first, then jqlang.jq
        const calls = result.calls.join('\n')
        expect(calls).toContain('winget:search')
        expect(calls).toContain('winget:install')
      })

      it('should return failure if no package variant is found', () => {
        const result = runWithMocks({
          availableCommands: ['winget'],
          existingPackages: [], // nothing available
          script: 'install_on_windows pkg1 pkg2 pkg3'
        })
        expect(result.exitCode).not.toBe(0)
      })
    })

    describe('flag position flexibility', () => {
      it('should accept flags at the beginning', () => {
        const result = runWithMocks({
          availableCommands: ['choco'],
          existingPackages: ['choco:pkg1'],
          script: 'install_on_windows --prefer-choco pkg1'
        })
        expect(result.exitCode).toBe(0)
        expect(result.calls.some(c => c.startsWith('choco:install'))).toBe(true)
      })

      it('should accept flags in the middle', () => {
        const result = runWithMocks({
          availableCommands: ['choco'],
          existingPackages: ['choco:pkg1'],
          script: 'install_on_windows pkg1 --prefer-choco pkg2'
        })
        // Should accept the flag wherever it appears
        expect(result.calls.some(c => c === 'has_command:choco')).toBe(true)
      })

      it('should accept flags at the end', () => {
        const result = runWithMocks({
          availableCommands: ['choco'],
          existingPackages: ['choco:pkg1'],
          script: 'install_on_windows pkg1 pkg2 --prefer-choco'
        })
        expect(result.calls.some(c => c === 'has_command:choco')).toBe(true)
      })
    })
  })

  describe('install functions with Windows support', () => {
    describe('install_jq()', () => {
      it('should call install_on_windows when is_windows returns true', () => {
        // Mock is_windows to return true
        const result = runWithMocks({
          availableCommands: ['winget'],
          existingPackages: ['winget:jqlang.jq'],
          script: `
            # Override is_windows to return true for testing
            is_windows() { return 0; }
            is_mac() { return 1; }
            is_debian() { return 1; }
            is_ubuntu() { return 1; }
            is_alpine() { return 1; }
            is_fedora() { return 1; }
            is_arch() { return 1; }
            install_jq
          `
        })
        expect(result.exitCode).toBe(0)
        // Should have tried to install via winget
        expect(result.calls.some(c => c.startsWith('winget:'))).toBe(true)
      })
    })

    describe('install_curl()', () => {
      it('should call install_on_windows when is_windows returns true', () => {
        const result = runWithMocks({
          availableCommands: ['winget'],
          existingPackages: ['winget:cURL.cURL'],
          script: `
            is_windows() { return 0; }
            is_mac() { return 1; }
            is_debian() { return 1; }
            is_ubuntu() { return 1; }
            is_alpine() { return 1; }
            is_fedora() { return 1; }
            is_arch() { return 1; }
            install_curl
          `
        })
        expect(result.exitCode).toBe(0)
        expect(result.calls.some(c => c.startsWith('winget:'))).toBe(true)
      })
    })

    describe('install_yq()', () => {
      it('should call install_on_windows when is_windows returns true', () => {
        const result = runWithMocks({
          availableCommands: ['winget'],
          existingPackages: ['winget:MikeFarah.yq'],
          script: `
            is_windows() { return 0; }
            is_mac() { return 1; }
            is_debian() { return 1; }
            is_ubuntu() { return 1; }
            is_alpine() { return 1; }
            is_fedora() { return 1; }
            is_arch() { return 1; }
            install_yq
          `
        })
        expect(result.exitCode).toBe(0)
        expect(result.calls.some(c => c.startsWith('winget:'))).toBe(true)
      })
    })
  })
})
