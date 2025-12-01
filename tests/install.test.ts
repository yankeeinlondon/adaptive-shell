import { describe, it, expect, beforeEach } from 'vitest'
import { sourceScript, bashExitCode } from './helpers'
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
  installSucceeds?: string[]
  script: string
}): { calls: string[]; exitCode: number; output: string } {
  const { availableCommands, existingPackages, installSucceeds = [], script } = options

  const availableCmd = availableCommands.length > 0
    ? `mock_available_commands ${availableCommands.map(c => `"${c}"`).join(' ')}`
    : ''
  const existingPkgs = existingPackages.length > 0
    ? `mock_package_exists ${existingPackages.map(p => `"${p}"`).join(' ')}`
    : ''
  const successPkgs = installSucceeds.length > 0
    ? `mock_install_succeeds ${installSucceeds.map(p => `"${p}"`).join(' ')}`
    : ''

  // We embed the exit code at the end of the output to capture it reliably
  const fullScript = `
source utils/install.sh
source tests/helpers/install-mocks.sh
${availableCmd}
${existingPkgs}
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
    // Even on error, capture stdout
    output = error.stdout?.toString() || ''
  }

  const lines = output.trim().split('\n')

  // Extract exit code from output
  const exitCodeIndex = lines.indexOf('---EXIT_CODE---')
  let exitCode = 0
  if (exitCodeIndex >= 0 && lines[exitCodeIndex + 1]) {
    exitCode = parseInt(lines[exitCodeIndex + 1], 10) || 0
  }

  // Extract calls
  const callsStartIndex = lines.indexOf('---CALLS---')
  const calls = callsStartIndex >= 0 && exitCodeIndex >= 0
    ? lines.slice(callsStartIndex + 1, exitCodeIndex).filter(l => l.trim())
    : []

  return { calls, exitCode, output }
}

describe('install utilities', () => {
  describe('helper functions', () => {
    describe('_try_cargo_install()', () => {
      it('should exist as a function', () => {
        const api = sourceScript('./utils/install.sh')('type')('_try_cargo_install')
        expect(api).toBeSuccessful()
        expect(api.result.stdout).toContain('function')
      })

      it('should return 1 if cargo is not available', () => {
        const result = runWithMocks({
          availableCommands: [], // cargo not available
          existingPackages: [],
          script: '_try_cargo_install testpkg'
        })
        expect(result.exitCode).not.toBe(0)
        // Should have checked for cargo
        expect(result.calls).toContain('has_command:cargo')
      })

      it('should install package when cargo finds it', () => {
        const result = runWithMocks({
          availableCommands: ['cargo'],
          existingPackages: ['cargo:ripgrep'],
          script: '_try_cargo_install ripgrep'
        })
        expect(result.exitCode).toBe(0)
        // Note: cargo search is piped to grep so can't be recorded in subshell
        // But cargo install is recorded
        expect(result.calls.some(c => c.startsWith('cargo:install'))).toBe(true)
      })
    })

    describe('_try_nix_install()', () => {
      it('should exist as a function', () => {
        const api = sourceScript('./utils/install.sh')('type')('_try_nix_install')
        expect(api).toBeSuccessful()
        expect(api.result.stdout).toContain('function')
      })

      it('should return 1 if nix-env is not available', () => {
        const result = runWithMocks({
          availableCommands: [], // nix-env not available
          existingPackages: [],
          script: '_try_nix_install testpkg'
        })
        expect(result.exitCode).not.toBe(0)
        expect(result.calls).toContain('has_command:nix-env')
      })

      it('should query nix for package when nix-env is available', () => {
        const result = runWithMocks({
          availableCommands: ['nix-env'],
          existingPackages: ['nix:jq'],
          script: '_try_nix_install jq'
        })
        // Should have called nix-env
        expect(result.calls.some(c => c.startsWith('nix-env:'))).toBe(true)
      })
    })
  })

  describe('error handling', () => {
    describe('install_on_macos()', () => {
      it('should error when no package is provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_macos')()
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })

      it('should error when only flags are provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_macos')('--prefer-nix')
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })
    })

    describe('install_on_debian()', () => {
      it('should error when no package is provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_debian')()
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })

      it('should error when only flags are provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_debian')('--prefer-cargo')
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })
    })

    describe('install_on_fedora()', () => {
      it('should error when no package is provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_fedora')()
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })

      it('should error when only flags are provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_fedora')('--prefer-nix')
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })
    })

    describe('install_on_alpine()', () => {
      it('should error when no package is provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_alpine')()
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })

      it('should error when only flags are provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_alpine')('--prefer-cargo')
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })
    })

    describe('install_on_arch()', () => {
      it('should error when no package is provided', () => {
        const api = sourceScript('./utils/install.sh')('install_on_arch')()
        expect(api).toFail()
        expect(api).toContainInStdErr('no package provided')
      })

      it('should error when only flags are provided', () => {
        const exitCode = bashExitCode('source ./utils/install.sh && install_on_arch --prefer-nix --prefer-cargo')
        expect(exitCode).not.toBe(0)
      })
    })
  })

  describe('package manager selection', () => {
    describe('install_on_macos()', () => {
      it('should try brew first when available', () => {
        const result = runWithMocks({
          availableCommands: ['brew', 'port', 'nix-env'],
          existingPackages: ['brew:jq', 'port:jq', 'nix:jq'],
          script: 'install_on_macos jq'
        })
        expect(result.exitCode).toBe(0)
        // brew should be tried first
        const brewInfoIndex = result.calls.findIndex(c => c === 'brew:info:jq')
        const portSearchIndex = result.calls.findIndex(c => c.startsWith('port:'))
        expect(brewInfoIndex).toBeGreaterThan(-1)
        // If brew has the package, port should not be called
        expect(portSearchIndex).toBe(-1)
      })

      it('should fall back to port when brew does not have package', () => {
        const result = runWithMocks({
          availableCommands: ['brew', 'port'],
          existingPackages: ['port:jq'], // jq only in port, not brew
          script: 'install_on_macos jq'
        })
        expect(result.exitCode).toBe(0)
        // Should try brew first (info check), then port
        expect(result.calls.some(c => c === 'brew:info:jq')).toBe(true)
        expect(result.calls.some(c => c.includes('port:'))).toBe(true)
      })

      it('should try nix-env and cargo as last resorts', () => {
        const result = runWithMocks({
          availableCommands: ['nix-env', 'cargo'],
          existingPackages: ['nix:jq'],
          script: 'install_on_macos jq'
        })
        expect(result.exitCode).toBe(0)
        // Should eventually try nix-env
        expect(result.calls.some(c => c.startsWith('nix-env:'))).toBe(true)
      })
    })

    describe('install_on_debian()', () => {
      it('should prefer nala over apt when both available', () => {
        const result = runWithMocks({
          availableCommands: ['nala', 'apt'],
          existingPackages: ['apt:jq'], // nala uses apt's package db
          script: 'install_on_debian jq'
        })
        expect(result.exitCode).toBe(0)
        // nala is checked first, and used for install
        expect(result.calls.some(c => c === 'has_command:nala')).toBe(true)
        expect(result.calls.some(c => c.startsWith('nala:install'))).toBe(true)
      })

      it('should use apt when nala is not available', () => {
        const result = runWithMocks({
          availableCommands: ['apt'],
          existingPackages: ['apt:jq'],
          script: 'install_on_debian jq'
        })
        expect(result.exitCode).toBe(0)
        expect(result.calls.some(c => c === 'apt:install:-y jq')).toBe(true)
      })
    })

    describe('install_on_fedora()', () => {
      it('should prefer dnf over yum when both available', () => {
        const result = runWithMocks({
          availableCommands: ['dnf', 'yum'],
          existingPackages: ['dnf:jq', 'yum:jq'],
          script: 'install_on_fedora jq'
        })
        expect(result.exitCode).toBe(0)
        // dnf should be used, yum should not
        expect(result.calls.some(c => c === 'has_command:dnf')).toBe(true)
        expect(result.calls.some(c => c.startsWith('dnf:install'))).toBe(true)
        // yum shouldn't be called since dnf succeeded
        expect(result.calls.some(c => c.startsWith('yum:install'))).toBe(false)
      })

      it('should use yum when dnf is not available', () => {
        const result = runWithMocks({
          availableCommands: ['yum'],
          existingPackages: ['yum:jq'],
          script: 'install_on_fedora jq'
        })
        expect(result.exitCode).toBe(0)
        expect(result.calls.some(c => c.startsWith('yum:install'))).toBe(true)
      })
    })

    describe('install_on_arch()', () => {
      it('should prefer pacman over AUR helpers when package exists', () => {
        const result = runWithMocks({
          availableCommands: ['pacman', 'yay'],
          existingPackages: ['pacman:jq', 'yay:jq'],
          script: 'install_on_arch jq'
        })
        expect(result.exitCode).toBe(0)
        // pacman should be used, yay should not be needed
        expect(result.calls.some(c => c === 'has_command:pacman')).toBe(true)
        expect(result.calls.some(c => c.startsWith('pacman:-S'))).toBe(true)
      })

      it('should fall back to yay when pacman does not have package', () => {
        const result = runWithMocks({
          availableCommands: ['pacman', 'yay'],
          existingPackages: ['yay:aur-only-pkg'], // not in pacman
          script: 'install_on_arch aur-only-pkg'
        })
        expect(result.exitCode).toBe(0)
        expect(result.calls.some(c => c.startsWith('yay:-S'))).toBe(true)
      })
    })

    describe('install_on_alpine()', () => {
      it('should use apk', () => {
        const result = runWithMocks({
          availableCommands: ['apk'],
          existingPackages: ['apk:jq'],
          script: 'install_on_alpine jq'
        })
        expect(result.exitCode).toBe(0)
        expect(result.calls.some(c => c.startsWith('apk:add'))).toBe(true)
      })
    })
  })

  describe('--prefer-nix flag', () => {
    it('should try nix first on macos when --prefer-nix is set', () => {
      const result = runWithMocks({
        availableCommands: ['brew', 'nix-env'],
        existingPackages: ['brew:jq', 'nix:jq'],
        script: 'install_on_macos --prefer-nix jq'
      })
      expect(result.exitCode).toBe(0)
      // nix-env should be called before brew
      const nixIndex = result.calls.findIndex(c => c.startsWith('nix-env:'))
      const brewIndex = result.calls.findIndex(c => c.startsWith('brew:'))
      expect(nixIndex).toBeGreaterThan(-1)
      // If nix succeeds, brew should not be called
      expect(brewIndex).toBe(-1)
    })

    it('should try nix first on debian when --prefer-nix is set', () => {
      const result = runWithMocks({
        availableCommands: ['apt', 'nix-env'],
        existingPackages: ['apt:jq', 'nix:jq'],
        script: 'install_on_debian --prefer-nix jq'
      })
      expect(result.exitCode).toBe(0)
      const nixIndex = result.calls.findIndex(c => c.startsWith('nix-env:'))
      const aptIndex = result.calls.findIndex(c => c.startsWith('apt:'))
      expect(nixIndex).toBeGreaterThan(-1)
      expect(aptIndex).toBe(-1)
    })

    it('should fall back to native package manager if nix fails', () => {
      const result = runWithMocks({
        availableCommands: ['apt', 'nix-env'],
        existingPackages: ['apt:jq'], // not in nix
        script: 'install_on_debian --prefer-nix jq'
      })
      expect(result.exitCode).toBe(0)
      // nix-env should be checked (has_command recorded)
      expect(result.calls.some(c => c === 'has_command:nix-env')).toBe(true)
      // apt install should be called since nix didn't have the package
      expect(result.calls.some(c => c === 'apt:install:-y jq')).toBe(true)
    })
  })

  describe('--prefer-cargo flag', () => {
    it('should try cargo first on macos when --prefer-cargo is set', () => {
      const result = runWithMocks({
        availableCommands: ['brew', 'cargo'],
        existingPackages: ['brew:ripgrep', 'cargo:ripgrep'],
        script: 'install_on_macos --prefer-cargo ripgrep'
      })
      expect(result.exitCode).toBe(0)
      // cargo should be called
      const cargoIndex = result.calls.findIndex(c => c.startsWith('cargo:'))
      expect(cargoIndex).toBeGreaterThan(-1)
    })

    it('should try cargo first on fedora when --prefer-cargo is set', () => {
      const result = runWithMocks({
        availableCommands: ['dnf', 'cargo'],
        existingPackages: ['dnf:ripgrep', 'cargo:ripgrep'],
        script: 'install_on_fedora --prefer-cargo ripgrep'
      })
      expect(result.exitCode).toBe(0)
      const cargoIndex = result.calls.findIndex(c => c.startsWith('cargo:'))
      expect(cargoIndex).toBeGreaterThan(-1)
    })
  })

  describe('flag position flexibility', () => {
    it('should accept flags at the beginning', () => {
      const result = runWithMocks({
        availableCommands: ['brew'],
        existingPackages: ['brew:pkg1'],
        script: 'install_on_macos --prefer-nix pkg1'
      })
      // Should work (may still succeed via brew fallback)
      expect(result.calls.some(c => c === 'has_command:nix-env')).toBe(true)
    })

    it('should accept flags in the middle', () => {
      const result = runWithMocks({
        availableCommands: ['brew'],
        existingPackages: ['brew:pkg1'],
        script: 'install_on_macos pkg1 --prefer-nix pkg2'
      })
      // Should try nix-env first (flag was parsed)
      expect(result.calls.some(c => c === 'has_command:nix-env')).toBe(true)
    })

    it('should accept flags at the end', () => {
      const result = runWithMocks({
        availableCommands: ['brew'],
        existingPackages: ['brew:pkg1'],
        script: 'install_on_macos pkg1 pkg2 --prefer-nix'
      })
      expect(result.calls.some(c => c === 'has_command:nix-env')).toBe(true)
    })

    it('should handle both flags interspersed with packages', () => {
      const result = runWithMocks({
        availableCommands: ['cargo', 'nix-env'],
        existingPackages: ['cargo:pkg1'],
        script: 'install_on_macos pkg1 --prefer-nix pkg2 --prefer-cargo pkg3'
      })
      // Both flags should be recognized - cargo should be tried first when --prefer-cargo
      expect(result.calls.some(c => c === 'has_command:cargo')).toBe(true)
    })
  })

  describe('multiple package name variants', () => {
    it('should try each package name in order until one succeeds', () => {
      const result = runWithMocks({
        availableCommands: ['brew'],
        existingPackages: ['brew:rg'], // ripgrep not available, but rg is
        script: 'install_on_macos ripgrep rg'
      })
      expect(result.exitCode).toBe(0)
      // Should try ripgrep first, then rg
      const calls = result.calls.join('\n')
      expect(calls).toContain('brew:info:ripgrep')
      expect(calls).toContain('brew:info:rg')
      expect(calls).toContain('brew:install:rg')
    })

    it('should return failure if no package variant is found', () => {
      const result = runWithMocks({
        availableCommands: ['brew'],
        existingPackages: [], // nothing available
        script: 'install_on_macos pkg1 pkg2 pkg3'
      })
      expect(result.exitCode).not.toBe(0)
    })
  })
})

describe('OS detection for install functions', () => {
  describe('is_fedora()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/os.sh')('type')('is_fedora')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/os.sh')('is_fedora')()
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_arch()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/os.sh')('type')('is_arch')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/os.sh')('is_arch')()
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_alpine()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/os.sh')('type')('is_alpine')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/os.sh')('is_alpine')()
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_debian()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/os.sh')('type')('is_debian')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/os.sh')('is_debian')()
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_ubuntu()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/os.sh')('type')('is_ubuntu')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils/os.sh')('is_ubuntu')()
      expect([0, 1]).toContain(api.result.code)
    })
  })
})
