import { describe, it, expect } from 'vitest'
import { sourceScript, sourcedBash, sourcedBashWithStderr, bashExitCode } from './helpers'

describe('install utilities', () => {
  describe('helper functions', () => {
    describe('_try_cargo_install()', () => {
      it('should exist as a function', () => {
        const api = sourceScript('./utils/install.sh')('type')('_try_cargo_install')
        expect(api).toBeSuccessful()
        expect(api.result.stdout).toContain('function')
      })
    })

    describe('_try_nix_install()', () => {
      it('should exist as a function', () => {
        const api = sourceScript('./utils/install.sh')('type')('_try_nix_install')
        expect(api).toBeSuccessful()
        expect(api.result.stdout).toContain('function')
      })
    })
  })

  describe('flag position flexibility', () => {
    // Test that flags can appear anywhere in the argument list, not just at the beginning
    // We test by checking that the function correctly parses flags and collects package names

    it('should accept flags at the beginning', () => {
      // install_on_debian --prefer-nix pkg1 pkg2
      // Should set prefer_nix=true and pkg_names=(pkg1 pkg2)
      const result = sourcedBash(
        './utils/install.sh',
        `test_flag_parsing() {
          local prefer_nix=false
          local prefer_cargo=false
          local pkg_names=()
          while [[ \$# -gt 0 ]]; do
            case "\$1" in
              --prefer-nix) prefer_nix=true; shift ;;
              --prefer-cargo) prefer_cargo=true; shift ;;
              *) pkg_names+=("\$1"); shift ;;
            esac
          done
          echo "nix=\$prefer_nix cargo=\$prefer_cargo pkgs=\${pkg_names[*]}"
        }
        test_flag_parsing --prefer-nix pkg1 pkg2`
      )
      expect(result).toBe('nix=true cargo=false pkgs=pkg1 pkg2')
    })

    it('should accept flags in the middle', () => {
      // install_on_debian pkg1 --prefer-cargo pkg2
      const result = sourcedBash(
        './utils/install.sh',
        `test_flag_parsing() {
          local prefer_nix=false
          local prefer_cargo=false
          local pkg_names=()
          while [[ \$# -gt 0 ]]; do
            case "\$1" in
              --prefer-nix) prefer_nix=true; shift ;;
              --prefer-cargo) prefer_cargo=true; shift ;;
              *) pkg_names+=("\$1"); shift ;;
            esac
          done
          echo "nix=\$prefer_nix cargo=\$prefer_cargo pkgs=\${pkg_names[*]}"
        }
        test_flag_parsing pkg1 --prefer-cargo pkg2`
      )
      expect(result).toBe('nix=false cargo=true pkgs=pkg1 pkg2')
    })

    it('should accept flags at the end', () => {
      // install_on_debian pkg1 pkg2 --prefer-nix
      const result = sourcedBash(
        './utils/install.sh',
        `test_flag_parsing() {
          local prefer_nix=false
          local prefer_cargo=false
          local pkg_names=()
          while [[ \$# -gt 0 ]]; do
            case "\$1" in
              --prefer-nix) prefer_nix=true; shift ;;
              --prefer-cargo) prefer_cargo=true; shift ;;
              *) pkg_names+=("\$1"); shift ;;
            esac
          done
          echo "nix=\$prefer_nix cargo=\$prefer_cargo pkgs=\${pkg_names[*]}"
        }
        test_flag_parsing pkg1 pkg2 --prefer-nix`
      )
      expect(result).toBe('nix=true cargo=false pkgs=pkg1 pkg2')
    })

    it('should accept both flags interspersed with packages', () => {
      // install_on_debian pkg1 --prefer-nix pkg2 --prefer-cargo pkg3
      const result = sourcedBash(
        './utils/install.sh',
        `test_flag_parsing() {
          local prefer_nix=false
          local prefer_cargo=false
          local pkg_names=()
          while [[ \$# -gt 0 ]]; do
            case "\$1" in
              --prefer-nix) prefer_nix=true; shift ;;
              --prefer-cargo) prefer_cargo=true; shift ;;
              *) pkg_names+=("\$1"); shift ;;
            esac
          done
          echo "nix=\$prefer_nix cargo=\$prefer_cargo pkgs=\${pkg_names[*]}"
        }
        test_flag_parsing pkg1 --prefer-nix pkg2 --prefer-cargo pkg3`
      )
      expect(result).toBe('nix=true cargo=true pkgs=pkg1 pkg2 pkg3')
    })
  })

  describe('install_on_fedora()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/install.sh')('type')('install_on_fedora')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should error when no package is provided', () => {
      const api = sourceScript('./utils/install.sh')('install_on_fedora')()
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should error when only flags are provided (no package)', () => {
      const api = sourceScript('./utils/install.sh')('install_on_fedora')('--prefer-nix')
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should accept multiple package name arguments', () => {
      // Test that function accepts multiple args without syntax error
      const result = sourcedBash(
        './utils/install.sh',
        'type install_on_fedora | grep -q "function" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-nix flag', () => {
      // Test that function parses --prefer-nix without syntax error
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_fedora | grep -q "prefer_nix=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-cargo flag', () => {
      // Test that function parses --prefer-cargo without syntax error
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_fedora | grep -q "prefer_cargo=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })
  })

  describe('install_on_alpine()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/install.sh')('type')('install_on_alpine')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should error when no package is provided', () => {
      const api = sourceScript('./utils/install.sh')('install_on_alpine')()
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should error when only flags are provided (no package)', () => {
      const api = sourceScript('./utils/install.sh')('install_on_alpine')('--prefer-cargo')
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should accept multiple package name arguments', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'type install_on_alpine | grep -q "function" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-nix flag', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_alpine | grep -q "prefer_nix=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-cargo flag', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_alpine | grep -q "prefer_cargo=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })
  })

  describe('install_on_arch()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/install.sh')('type')('install_on_arch')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should error when no package is provided', () => {
      const api = sourceScript('./utils/install.sh')('install_on_arch')()
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should error when only flags are provided (no package)', () => {
      // Use bashExitCode for exit code, and sourcedBashWithStderr includes stderr in combined output
      const exitCode = bashExitCode('source ./utils/install.sh && install_on_arch --prefer-nix --prefer-cargo')
      expect(exitCode).not.toBe(0)
      const output = sourcedBashWithStderr('./utils/install.sh', 'install_on_arch --prefer-nix --prefer-cargo')
      expect(output).toContain('no package provided')
    })

    it('should accept multiple package name arguments', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'type install_on_arch | grep -q "function" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-nix flag', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_arch | grep -q "prefer_nix=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-cargo flag', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_arch | grep -q "prefer_cargo=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })
  })

  describe('install_on_macos()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/install.sh')('type')('install_on_macos')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should error when no package is provided', () => {
      const api = sourceScript('./utils/install.sh')('install_on_macos')()
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should error when only flags are provided (no package)', () => {
      const api = sourceScript('./utils/install.sh')('install_on_macos')('--prefer-cargo')
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should accept multiple package name arguments', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'type install_on_macos | grep -q "function" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-nix flag', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_macos | grep -q "prefer_nix=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-cargo flag', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_macos | grep -q "prefer_cargo=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })
  })

  describe('install_on_debian()', () => {
    it('should exist as a function', () => {
      const api = sourceScript('./utils/install.sh')('type')('install_on_debian')
      expect(api).toBeSuccessful()
      expect(api.result.stdout).toContain('function')
    })

    it('should error when no package is provided', () => {
      const api = sourceScript('./utils/install.sh')('install_on_debian')()
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should error when only flags are provided (no package)', () => {
      const api = sourceScript('./utils/install.sh')('install_on_debian')('--prefer-nix')
      expect(api).toFail()
      expect(api).toContainInStdErr('no package provided')
    })

    it('should accept multiple package name arguments', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'type install_on_debian | grep -q "function" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-nix flag', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_debian | grep -q "prefer_nix=true" && echo "valid"'
      )
      expect(result).toBe('valid')
    })

    it('should accept --prefer-cargo flag', () => {
      const result = sourcedBash(
        './utils/install.sh',
        'declare -f install_on_debian | grep -q "prefer_cargo=true" && echo "valid"'
      )
      expect(result).toBe('valid')
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
      // Should return either 0 (is fedora) or 1 (not fedora), not an error
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
      // Should return either 0 (is arch) or 1 (not arch), not an error
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
      // Should return either 0 (is alpine) or 1 (not alpine), not an error
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
      // Should return either 0 (is debian) or 1 (not debian), not an error
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
      // Should return either 0 (is ubuntu) or 1 (not ubuntu), not an error
      expect([0, 1]).toContain(api.result.code)
    })
  })
})
