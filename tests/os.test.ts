import { describe, it, expect } from 'vitest'
import { sourceScript, bashExitCode } from './helpers'

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
