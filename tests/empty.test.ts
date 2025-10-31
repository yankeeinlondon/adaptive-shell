import { describe, it, expect } from 'vitest'
import { bashExitCode } from './helpers/bash'

describe('empty utilities', () => {
  describe('not_empty()', () => {
    it('should return 0 for non-empty string', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty "hello"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for empty string', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty ""')
      expect(exitCode).toBe(1)
    })

    it('should return 0 for whitespace (whitespace is not empty)', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty "  "')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for string with newline', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty $\'\\n\'')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for string with tab', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty $\'\\t\'')
      expect(exitCode).toBe(0)
    })

    it('should return 1 when no parameter passed', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty')
      expect(exitCode).toBe(1)
    })

    it('should return 0 for zero', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty "0"')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for special characters', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty "!@#$"')
      expect(exitCode).toBe(0)
    })
  })

  describe('is_empty_string()', () => {
    it('should return 0 for empty string', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty_string ""')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for non-empty string', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty_string "hello"')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for whitespace (whitespace is not empty)', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty_string "  "')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for string with newline', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty_string $\'\\n\'')
      expect(exitCode).toBe(1)
    })

    it('should return 0 when no parameter passed', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty_string')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for zero', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty_string "0"')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for false string', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty_string "false"')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_empty()', () => {
    it('should return 0 for empty string', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty ""')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for non-empty string', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty "hello"')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for whitespace (whitespace is not empty)', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty "  "')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for string with newline', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty $\'\\n\'')
      expect(exitCode).toBe(1)
    })

    it('should return 0 when no parameter passed', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for zero', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty "0"')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for negative number', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty "-1"')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for special characters', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty "!@#"')
      expect(exitCode).toBe(1)
    })
  })
})
