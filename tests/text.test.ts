import { describe, it, expect } from 'vitest'
import { sourcedBash, sourcedBashNoTrimStart, bashExitCode } from './helpers/bash'

describe('text utilities', () => {
  describe('lc()', () => {
    it('should convert uppercase to lowercase', () => {
      const result = sourcedBash('./utils/text.sh', 'lc "HELLO WORLD"')
      expect(result).toBe('hello world')
    })

    it('should convert mixed case to lowercase', () => {
      const result = sourcedBash('./utils/text.sh', 'lc "HeLLo WoRLd"')
      expect(result).toBe('hello world')
    })

    it('should handle already lowercase text', () => {
      const result = sourcedBash('./utils/text.sh', 'lc "hello"')
      expect(result).toBe('hello')
    })

    it('should handle empty string', () => {
      const result = sourcedBash('./utils/text.sh', 'lc ""')
      expect(result).toBe('')
    })

    it('should handle special characters', () => {
      const result = sourcedBash('./utils/text.sh', 'lc "HELLO-WORLD_123"')
      expect(result).toBe('hello-world_123')
    })
  })

  describe('contains()', () => {
    it('should return 0 when substring is found', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && contains "world" "hello world"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 when substring is not found', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && contains "foo" "hello world"')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for empty content', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && contains "hello" ""')
      expect(exitCode).toBe(1)
    })

    it('should be case sensitive', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && contains "hello" "Hello"')
      expect(exitCode).toBe(1)
    })
  })

  describe('starts_with()', () => {
    it('should return 0 when string starts with prefix', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && starts_with "hello" "hello world"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 when string does not start with prefix', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && starts_with "world" "hello world"')
      expect(exitCode).toBe(1)
    })

    it('should error on empty content', () => {
      // Function requires non-empty content (uses ${2:?...} parameter expansion)
      const exitCode = bashExitCode('source ./utils/text.sh && empty="" && starts_with "hello" "$empty"')
      expect(exitCode).toBe(127) // bash error code for parameter expansion failure
    })

    it('should be case sensitive', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && starts_with "hello" "Hello"')
      expect(exitCode).toBe(1)
    })
  })

  describe('strip_before()', () => {
    it('should remove text before first occurrence of pattern', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_before "-" "hello-world-test"')
      expect(result).toBe('world-test')
    })

    it('should return original if pattern not found', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_before "-" "hello"')
      expect(result).toBe('hello')
    })

    it('should handle multiple occurrences (strip first only)', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_before "-" "a-b-c-d"')
      expect(result).toBe('b-c-d')
    })
  })

  describe('strip_before_last()', () => {
    it('should remove text before last occurrence of pattern', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_before_last "-" "hello-world-test"')
      expect(result).toBe('test')
    })

    it('should return original if pattern not found', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_before_last "-" "hello"')
      expect(result).toBe('hello')
    })

    it('should handle single occurrence', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_before_last "-" "hello-world"')
      expect(result).toBe('world')
    })
  })

  describe('strip_after()', () => {
    it('should remove text after first occurrence of pattern', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_after "-" "hello-world-test"')
      expect(result).toBe('hello')
    })

    it('should return original if pattern not found', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_after "-" "hello"')
      expect(result).toBe('hello')
    })

    it('should handle multiple occurrences (strip after first)', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_after "-" "a-b-c-d"')
      expect(result).toBe('a')
    })
  })

  describe('strip_after_last()', () => {
    it('should remove text after last occurrence of pattern', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_after_last "-" "hello-world-test"')
      expect(result).toBe('hello-world')
    })

    it('should return original if pattern not found', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_after_last "-" "hello"')
      expect(result).toBe('hello')
    })

    it('should handle single occurrence', () => {
      const result = sourcedBash('./utils/text.sh', 'strip_after_last "-" "hello-world"')
      expect(result).toBe('hello')
    })
  })

  describe('ensure_starting()', () => {
    it('should add prefix if not present', () => {
      const result = sourcedBash('./utils/text.sh', 'ensure_starting "hello-" "world"')
      expect(result).toBe('hello-world')
    })

    it('should not duplicate prefix if already present', () => {
      const result = sourcedBash('./utils/text.sh', 'ensure_starting "hello-" "hello-world"')
      expect(result).toBe('hello-world')
    })

    it('should error on empty string', () => {
      // Function requires non-empty content (uses ${2:?-} parameter expansion)
      const exitCode = bashExitCode('source ./utils/text.sh && empty="" && ensure_starting "prefix" "$empty"')
      expect(exitCode).toBe(127) // bash error code for parameter expansion failure
    })
  })

  describe('has_characters()', () => {
    it('should return 0 when content contains one of the specified characters', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && has_characters "aeiou" "hello"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 when content does not contain any of the specified characters', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && has_characters "xyz" "hello"')
      expect(exitCode).toBe(1)
    })

    it('should return 0 when checking for special characters', () => {
      const exitCode = bashExitCode('source ./utils/text.sh && has_characters "-_" "hello-world"')
      expect(exitCode).toBe(0)
    })

    it('should error when content is empty', () => {
      // Function requires non-empty content (uses ${2:?...} parameter expansion)
      const exitCode = bashExitCode('source ./utils/text.sh && empty="" && has_characters "abc" "$empty"')
      expect(exitCode).toBe(127) // bash error code for parameter expansion failure
    })
  })

  describe('trim()', () => {
    it('should remove leading and trailing whitespace', () => {
      const result = sourcedBash('./utils/text.sh', 'trim "  hello world  "')
      expect(result).toBe('hello world')
    })

    it('should handle only leading whitespace', () => {
      const result = sourcedBash('./utils/text.sh', 'trim "  hello"')
      expect(result).toBe('hello')
    })

    it('should handle only trailing whitespace', () => {
      const result = sourcedBash('./utils/text.sh', 'trim "hello  "')
      expect(result).toBe('hello')
    })

    it('should handle string with only whitespace', () => {
      const result = sourcedBash('./utils/text.sh', 'trim "   "')
      expect(result).toBe('')
    })

    it('should handle empty string', () => {
      const result = sourcedBash('./utils/text.sh', 'trim ""')
      expect(result).toBe('')
    })

    it('should preserve internal whitespace', () => {
      const result = sourcedBash('./utils/text.sh', 'trim "  hello   world  "')
      expect(result).toBe('hello   world')
    })

    it('should handle tabs', () => {
      // Use $'...' syntax for bash to interpret escape sequences
      const result = sourcedBash('./utils/text.sh', "trim $'\\t\\thello\\t\\t'")
      expect(result).toBe('hello')
    })
  })

  describe('indent()', () => {
    it('should indent single line with specified indentation', () => {
      const result = sourcedBashNoTrimStart('./utils/text.sh', 'indent "  " "hello"')
      expect(result).toBe('  hello')
    })

    it('should indent with custom indentation string', () => {
      const result = sourcedBashNoTrimStart('./utils/text.sh', 'indent "    " "hello"')
      expect(result).toBe('    hello')
    })

    it('should indent multiple lines', () => {
      const result = sourcedBashNoTrimStart('./utils/text.sh', "indent '  ' $'line1\\nline2'")
      expect(result).toContain('  line1')
      expect(result).toContain('  line2')
    })

    it('should handle tab indentation', () => {
      const result = sourcedBashNoTrimStart('./utils/text.sh', "indent $'\\t' 'hello'")
      expect(result).toContain('\thello')
    })
  })
})
