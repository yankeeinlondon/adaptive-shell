import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { mkdirSync, rmSync, existsSync } from 'fs'
import { join } from 'path'
import { sourceScript } from './helpers'

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
      const api = sourceScript('./utils.sh')('get_shell')()
      expect(api.result.stdout).toBeTruthy()
      expect(api.result.stdout.length).toBeGreaterThan(0)
    })

    it('should return bash when running in bash', () => {
      const api = sourceScript('./utils.sh')('get_shell')()
      // Since we're executing via bash, it should detect bash
      expect(['bash', 'sh']).toContain(api.result.stdout)
    })

    it('should not return a path, only the shell name', () => {
      const api = sourceScript('./utils.sh')('get_shell')()
      expect(api.result.stdout).not.toContain('/')
    })
  })

  describe('is_bash()', () => {
    it('should return 0 when running in bash', () => {
      // Our tests run in bash via sourceScript helper
      const api = sourceScript('./utils.sh')('is_bash')()
      expect(api).toBeSuccessful()
    })
  })

  describe('is_zsh()', () => {
    it('should return 1 when not running in zsh', () => {
      // Our tests run in bash, not zsh
      const api = sourceScript('./utils.sh')('is_zsh')()
      expect(api).toFail()
    })
  })

  describe('is_fish()', () => {
    it('should return 1 when not running in fish', () => {
      // Our tests run in bash, not fish
      const api = sourceScript('./utils.sh')('is_fish')()
      expect(api).toFail()
    })
  })

  describe('is_nushell()', () => {
    it('should return 1 when not running in nushell', () => {
      const api = sourceScript('./utils.sh')('is_nushell')()
      expect(api).toFail()
    })
  })

  describe('is_xonsh()', () => {
    it('should return 1 when not running in xonsh', () => {
      const api = sourceScript('./utils.sh')('is_xonsh')()
      expect(api).toFail()
    })
  })

  describe('is_docker()', () => {
    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils.sh')('is_docker')()
      // Should return either 0 (is docker) or 1 (not docker), not an error
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_lxc()', () => {
    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils.sh')('is_lxc')()
      // Should return either 0 (is lxc) or 1 (not lxc), not an error
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_vm()', () => {
    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils.sh')('is_vm')()
      // Should return either 0 (is vm) or 1 (not vm), not an error
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('is_pve_host()', () => {
    it('should return an exit code (0 or 1)', () => {
      const api = sourceScript('./utils.sh')('is_pve_host')()
      // Should return either 0 (has pveversion) or 1 (does not have pveversion)
      expect([0, 1]).toContain(api.result.code)
    })
  })

  describe('bash_version()', () => {
    it('should return a version string', () => {
      const api = sourceScript('./utils.sh')('bash_version')()
      expect(api.result.stdout).toBeTruthy()
      expect(api.result.stdout.length).toBeGreaterThan(0)
    })

    it('should return a version that starts with a number', () => {
      const api = sourceScript('./utils.sh')('bash_version')()
      expect(api.result.stdout).toMatch(/^\d/)
    })

    it('should contain version number parts', () => {
      const api = sourceScript('./utils.sh')('bash_version')()
      // Version should be like "5.1.16" or "3.2.57"
      expect(api.result.stdout).toMatch(/\d+\.\d+/)
    })
  })

  describe('using_bash_3()', () => {
    it('should return 0 or 1 based on bash version', () => {
      const api = sourceScript('./utils.sh')('using_bash_3')()
      // Should return either 0 (is bash 3) or 1 (not bash 3)
      expect([0, 1]).toContain(api.result.code)
    })

    it('should be consistent with bash_version()', () => {
      const versionApi = sourceScript('./utils.sh')('bash_version')()
      const usingBash3Api = sourceScript('./utils.sh')('using_bash_3')()

      if (versionApi.result.stdout.startsWith('3')) {
        expect(usingBash3Api).toBeSuccessful()
      } else {
        expect(usingBash3Api).toFail()
      }
    })
  })

  describe('has_command()', () => {
    it('should return 0 for common commands that exist', () => {
      const api = sourceScript('./utils.sh')('has_command')('ls')
      expect(api).toBeSuccessful()
    })

    it('should return 0 for bash command', () => {
      const api = sourceScript('./utils.sh')('has_command')('bash')
      expect(api).toBeSuccessful()
    })

    it('should return 1 for commands that do not exist', () => {
      const api = sourceScript('./utils.sh')('has_command')('nonexistent-command-12345')
      expect(api).toFail()
    })

    it('should error when no command provided', () => {
      const api = sourceScript('./utils.sh')('has_command')()
      expect(api).toFail()
    })

    it('should handle commands with special characters', () => {
      // Test with a command that definitely doesn't exist
      const api = sourceScript('./utils.sh')('has_command')('fake@command')
      expect(api).toFail()
    })
  })

  describe('is_keyword()', () => {
    it('should return 0 for bash keywords', () => {
      const api = sourceScript('./utils.sh')('is_keyword')('if')
      expect(api).toBeSuccessful()
    })

    it('should return 0 for function keyword', () => {
      const api = sourceScript('./utils.sh')('is_keyword')('function')
      expect(api).toBeSuccessful()
    })

    it('should return 1 for non-keywords', () => {
      const api = sourceScript('./utils.sh')('is_keyword')('notakeyword')
      expect(api).toFail()
    })

    it('should error when no parameter provided', () => {
      const api = sourceScript('./utils.sh')('is_keyword')()
      expect(api).toFail()
    })
  })

  describe('in_package_json()', () => {
    it('should return 0 when string exists in package.json', () => {
      // This repo has a package.json with "vitest" in it
      const api = sourceScript('./utils.sh')('in_package_json')('vitest')
      expect(api).toBeSuccessful()
    })

    it('should return 1 when string does not exist in package.json', () => {
      const api = sourceScript('./utils.sh')('in_package_json')('nonexistent-string-12345')
      expect(api).toFail()
    })

    it('should error when no string provided', () => {
      const api = sourceScript('./utils.sh')('in_package_json')()
      expect(api).toFail()
    })
  })

  describe('TODO functions', () => {
    // These functions are marked as TODO in the source and return 1
    // We'll just verify they exist and return the expected error code

    it('is_git_repo() should exist but is not yet implemented', () => {
      const api = sourceScript('./utils.sh')('is_git_repo')('.')
      // TODO functions return 1 (not implemented)
      expect(api).toFail()
    })

    it('repo_is_dirty() should exist but is not yet implemented', () => {
      const api = sourceScript('./utils.sh')('repo_is_dirty')('.')
      expect(api).toFail()
    })

    it('repo_root() should exist but is not yet implemented', () => {
      const api = sourceScript('./utils.sh')('repo_root')('.')
      expect(api).toFail()
    })

    it('is_monorepo() should exist but is not yet implemented', () => {
      const api = sourceScript('./utils.sh')('is_monorepo')('.')
      expect(api).toFail()
    })

    it('has_typescript_files() should exist but is not yet implemented', () => {
      const api = sourceScript('./utils.sh')('has_typescript_files')('.')
      expect(api).toFail()
    })

    it('looks_like_js_project() should exist but is not yet implemented', () => {
      const api = sourceScript('./utils.sh')('looks_like_js_project')()
      expect(api).toFail()
    })

    it('looks_like_rust_project() should exist but is not yet implemented', () => {
      const api = sourceScript('./utils.sh')('looks_like_rust_project')()
      expect(api).toFail()
    })

    it('looks_like_python_project() should exist but is not yet implemented', () => {
      const api = sourceScript('./utils.sh')('looks_like_python_project')()
      expect(api).toFail()
    })
  })
})
