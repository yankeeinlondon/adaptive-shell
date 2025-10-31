import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { sourcedBash, bashExitCode } from './helpers/bash'
import { mkdirSync, writeFileSync, rmSync, existsSync } from 'fs'
import { join } from 'path'

describe('detection utilities', () => {
  const testDir = join(process.cwd(), 'tests', '.tmp-detection-test')

  beforeEach(() => {
    // Clean up and create fresh test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
    mkdirSync(testDir, { recursive: true })
  })

  afterEach(() => {
    // Clean up test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
  })

  describe('get_shell()', () => {
    it('should return a shell name', () => {
      const result = sourcedBash('./utils.sh', 'get_shell')
      expect(result).toBeTruthy()
      expect(result.length).toBeGreaterThan(0)
    })

    it('should return bash when running in bash', () => {
      const result = sourcedBash('./utils.sh', 'get_shell')
      // Since we're executing via bash, it should detect bash
      expect(['bash', 'sh']).toContain(result)
    })

    it('should not return a path, only the shell name', () => {
      const result = sourcedBash('./utils.sh', 'get_shell')
      expect(result).not.toContain('/')
    })
  })

  describe('is_bash()', () => {
    it('should return 0 when running in bash', () => {
      // Our tests run in bash via sourcedBash helper
      const exitCode = bashExitCode('source ./utils.sh && is_bash')
      expect(exitCode).toBe(0)
    })
  })

  describe('is_zsh()', () => {
    it('should return 1 when not running in zsh', () => {
      // Our tests run in bash, not zsh
      const exitCode = bashExitCode('source ./utils.sh && is_zsh')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_fish()', () => {
    it('should return 1 when not running in fish', () => {
      // Our tests run in bash, not fish
      const exitCode = bashExitCode('source ./utils.sh && is_fish')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_nushell()', () => {
    it('should return 1 when not running in nushell', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_nushell')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_xonsh()', () => {
    it('should return 1 when not running in xonsh', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_xonsh')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_docker()', () => {
    it('should return an exit code (0 or 1)', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_docker')
      // Should return either 0 (is docker) or 1 (not docker), not an error
      expect([0, 1]).toContain(exitCode)
    })
  })

  describe('is_lxc()', () => {
    it('should return an exit code (0 or 1)', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_lxc')
      // Should return either 0 (is lxc) or 1 (not lxc), not an error
      expect([0, 1]).toContain(exitCode)
    })
  })

  describe('is_vm()', () => {
    it('should return an exit code (0 or 1)', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_vm')
      // Should return either 0 (is vm) or 1 (not vm), not an error
      expect([0, 1]).toContain(exitCode)
    })
  })

  describe('is_pve_host()', () => {
    it('should return an exit code (0 or 1)', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_pve_host')
      // Should return either 0 (has pveversion) or 1 (does not have pveversion)
      expect([0, 1]).toContain(exitCode)
    })
  })

  describe('bash_version()', () => {
    it('should return a version string', () => {
      const result = sourcedBash('./utils.sh', 'bash_version')
      expect(result).toBeTruthy()
      expect(result.length).toBeGreaterThan(0)
    })

    it('should return a version that starts with a number', () => {
      const result = sourcedBash('./utils.sh', 'bash_version')
      expect(result).toMatch(/^\d/)
    })

    it('should contain version number parts', () => {
      const result = sourcedBash('./utils.sh', 'bash_version')
      // Version should be like "5.1.16" or "3.2.57"
      expect(result).toMatch(/\d+\.\d+/)
    })
  })

  describe('using_bash_3()', () => {
    it('should return 0 or 1 based on bash version', () => {
      const exitCode = bashExitCode('source ./utils.sh && using_bash_3')
      // Should return either 0 (is bash 3) or 1 (not bash 3)
      expect([0, 1]).toContain(exitCode)
    })

    it('should be consistent with bash_version()', () => {
      const version = sourcedBash('./utils.sh', 'bash_version')
      const exitCode = bashExitCode('source ./utils.sh && using_bash_3')

      if (version.startsWith('3')) {
        expect(exitCode).toBe(0)
      } else {
        expect(exitCode).toBe(1)
      }
    })
  })

  describe('has_command()', () => {
    it('should return 0 for common commands that exist', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_command "ls"')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for bash command', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_command "bash"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for commands that do not exist', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_command "nonexistent-command-12345"')
      expect(exitCode).toBe(1)
    })

    it('should error when no command provided', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_command 2>/dev/null')
      expect(exitCode).not.toBe(0)
    })

    it('should handle commands with special characters', () => {
      // Test with a command that definitely doesn't exist
      const exitCode = bashExitCode('source ./utils.sh && has_command "fake@command"')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_keyword()', () => {
    it('should return 0 for bash keywords', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword "if"')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for function keyword', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword "function"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for non-keywords', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword "notakeyword"')
      expect(exitCode).toBe(1)
    })

    it('should error when no parameter provided', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword 2>/dev/null')
      expect(exitCode).not.toBe(0)
    })
  })

  describe('in_package_json()', () => {
    it('should return 0 when string exists in package.json', () => {
      // This repo has a package.json with "vitest" in it
      const exitCode = bashExitCode('source ./utils.sh && in_package_json "vitest"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 when string does not exist in package.json', () => {
      const exitCode = bashExitCode('source ./utils.sh && in_package_json "nonexistent-string-12345"')
      expect(exitCode).toBe(1)
    })

    it('should error when no string provided', () => {
      const exitCode = bashExitCode('source ./utils.sh && in_package_json 2>/dev/null')
      expect(exitCode).not.toBe(0)
    })
  })

  describe('TODO functions', () => {
    // These functions are marked as TODO in the source and return 1
    // We'll just verify they exist and return the expected error code

    it('is_git_repo() should exist but is not yet implemented', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_git_repo "."')
      // TODO functions return 1 (not implemented)
      expect(exitCode).toBe(1)
    })

    it('repo_is_dirty() should exist but is not yet implemented', () => {
      const exitCode = bashExitCode('source ./utils.sh && repo_is_dirty "."')
      expect(exitCode).toBe(1)
    })

    it('repo_root() should exist but is not yet implemented', () => {
      const exitCode = bashExitCode('source ./utils.sh && repo_root "."')
      expect(exitCode).toBe(1)
    })

    it('is_monorepo() should exist but is not yet implemented', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_monorepo "."')
      expect(exitCode).toBe(1)
    })

    it('has_typescript_files() should exist but is not yet implemented', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_typescript_files "."')
      expect(exitCode).toBe(1)
    })

    it('looks_like_js_project() should exist but is not yet implemented', () => {
      const exitCode = bashExitCode('source ./utils.sh && looks_like_js_project')
      expect(exitCode).toBe(1)
    })

    it('looks_like_rust_project() should exist but is not yet implemented', () => {
      const exitCode = bashExitCode('source ./utils.sh && looks_like_rust_project')
      expect(exitCode).toBe(1)
    })

    it('looks_like_python_project() should exist but is not yet implemented', () => {
      const exitCode = bashExitCode('source ./utils.sh && looks_like_python_project')
      expect(exitCode).toBe(1)
    })
  })
})
