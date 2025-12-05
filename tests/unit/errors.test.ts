import { describe, it, expect } from 'vitest'
import { sourceScript, bashExitCode, sourcedBash } from "../helpers"

describe('error handling utilities', () => {
  describe('catch_errors()', () => {
    it('should set errexit option', () => {
      // After catch_errors, errexit should be on
      const result = sourcedBash('./utils/errors.sh', 'catch_errors; shopt -o errexit')
      expect(result).toContain('errexit')
      expect(result).toContain('on')
    })

    it('should set nounset option', () => {
      const result = sourcedBash('./utils/errors.sh', 'catch_errors; shopt -o nounset')
      expect(result).toContain('nounset')
      expect(result).toContain('on')
    })

    it('should set pipefail option', () => {
      const result = sourcedBash('./utils/errors.sh', 'catch_errors; shopt -o pipefail')
      expect(result).toContain('pipefail')
      expect(result).toContain('on')
    })

    it('should not error when called', () => {
      const api = sourceScript('./utils/errors.sh')('catch_errors')()
      expect(api).toBeSuccessful()
    })
  })

  describe('allow_errors()', () => {
    it('should unset errexit option', () => {
      const exitCode = bashExitCode(`
        source ./utils/errors.sh
        catch_errors
        allow_errors
        shopt -o errexit | grep -q "off"
      `)
      expect(exitCode).toBe(0)
    })

    it('should unset nounset option', () => {
      const exitCode = bashExitCode(`
        source ./utils/errors.sh
        catch_errors
        allow_errors
        shopt -o nounset | grep -q "off"
      `)
      expect(exitCode).toBe(0)
    })

    it('should unset pipefail option', () => {
      const exitCode = bashExitCode(`
        source ./utils/errors.sh
        catch_errors
        allow_errors
        shopt -o pipefail | grep -q "off"
      `)
      expect(exitCode).toBe(0)
    })

    it('should not error when called', () => {
      const api = sourceScript('./utils/errors.sh')('allow_errors')()
      expect(api).toBeSuccessful()
    })

    it('should allow commands to fail after being called', () => {
      const exitCode = bashExitCode(`
        source ./utils/errors.sh
        catch_errors
        allow_errors
        false
        true
      `)
      // Should succeed because allow_errors was called
      expect(exitCode).toBe(0)
    })
  })

  describe('error_handler()', () => {
    it('should accept line number and command parameters', () => {
      // error_handler expects to be called with line number and command
      // This test verifies it can be called without crashing
      const api = sourceScript('./utils/errors.sh')('error_handler')('42', 'test command')
      // error_handler doesn't fail, it just reports to stderr
      expect([0, 1]).toContain(api.result.code)
    })

    it('should be callable from error trap', () => {
      // Test that error_handler can be set as a trap
      const exitCode = bashExitCode(`
        source ./utils/errors.sh
        trap 'error_handler \$LINENO "\$BASH_COMMAND"' ERR 2>&1
        echo "trap set successfully"
      `)
      expect(exitCode).toBe(0)
    })
  })

  describe('error handling integration', () => {
    it('should catch errors when catch_errors is active', () => {
      const exitCode = bashExitCode(`
        source ./utils/errors.sh
        catch_errors
        false
      `)
      // Should fail because catch_errors makes the script exit on error
      expect(exitCode).not.toBe(0)
    })

    it('should not catch errors when allow_errors is active', () => {
      const exitCode = bashExitCode(`
        source ./utils/errors.sh
        allow_errors
        false
        true
      `)
      // Should succeed because allow_errors allows false to fail without exiting
      expect(exitCode).toBe(0)
    })

    it('should toggle between catching and allowing errors', () => {
      const exitCode = bashExitCode(`
        source ./utils/errors.sh
        catch_errors
        allow_errors
        false
        catch_errors
        true
      `)
      // Should succeed: allow_errors lets false pass, then catch_errors is re-enabled, then true succeeds
      expect(exitCode).toBe(0)
    })
  })
})
