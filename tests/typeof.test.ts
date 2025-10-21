import { describe, it, expect } from 'vitest'
import { sourcedBash, bashExitCode } from './helpers/bash'

describe('typeof utilities', () => {
  describe('not_empty()', () => {
    it('should return 0 for non-empty string', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty "hello"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for empty string', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty ""')
      expect(exitCode).toBe(1)
    })

    it('should return 0 for whitespace', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty "  "')
      expect(exitCode).toBe(0)
    })

    it('should return 1 when no parameter passed', () => {
      const exitCode = bashExitCode('source ./utils.sh && not_empty')
      expect(exitCode).toBe(1)
    })
  })

  describe('has_newline()', () => {
    it('should return 0 when string contains newline', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_newline $\'hello\\nworld\'')
      expect(exitCode).toBe(0)
    })

    it('should return 1 when string does not contain newline', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_newline "hello world"')
      expect(exitCode).toBe(1)
    })

    it('should return 0 for string with only newline', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_newline $\'\\n\'')
      expect(exitCode).toBe(0)
    })

    it('should error when no parameter passed', () => {
      const exitCode = bashExitCode('source ./utils.sh && has_newline')
      expect(exitCode).toBe(127)
    })
  })

  describe('is_keyword()', () => {
    it('should return 0 for bash keywords', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword "if"')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for "for" keyword', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword "for"')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for "while" keyword', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword "while"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for non-keywords', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword "hello"')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for function names', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_keyword "printf"')
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

    it('should return 1 for whitespace', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_empty "  "')
      expect(exitCode).toBe(1)
    })

    it('should return 0 for empty variable by reference', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="" && is_empty my_var')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for non-empty variable by reference', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_empty my_var')
      expect(exitCode).toBe(1)
    })

    it('should return 0 for empty array by reference', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_arr=() && is_empty my_arr')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for non-empty array by reference', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_arr=("one" "two") && is_empty my_arr')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_array()', () => {
    it('should return 0 for array variable', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_arr=("one" "two") && is_array my_arr')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for empty array', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_arr=() && is_array my_arr')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for string variable', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_array my_var')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for unbound reference', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_array nonexistent_var')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_assoc_array()', () => {
    it('should return 0 for associative array', () => {
      const exitCode = bashExitCode('source ./utils.sh && declare -A my_assoc=([key]="value") && is_assoc_array my_assoc')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for empty associative array', () => {
      const exitCode = bashExitCode('source ./utils.sh && declare -A my_assoc=() && is_assoc_array my_assoc')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for regular array', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_arr=("one" "two") && is_assoc_array my_arr')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for string variable', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_assoc_array my_var')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for special characters in variable name', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_assoc_array "my!var"')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_bound()', () => {
    it('should return 0 for bound variable', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_bound my_var')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for bound empty variable', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="" && is_bound my_var')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for unbound variable', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_bound nonexistent_var')
      expect(exitCode).toBe(1)
    })

    it('should return 1 for arithmetic expression', () => {
      const exitCode = bashExitCode('source ./utils.sh && is_bound "2+2"')
      expect(exitCode).toBe(1)
    })
  })

  describe('typeof()', () => {
    it('should return "string" for string variable', () => {
      const result = sourcedBash('./utils.sh', 'my_var="hello" && typeof my_var')
      expect(result).toBe('string')
    })

    it('should return "empty" for empty variable', () => {
      const result = sourcedBash('./utils.sh', 'my_var="" && typeof my_var')
      expect(result).toBe('empty')
    })

    it('should return "array" for array variable', () => {
      const result = sourcedBash('./utils.sh', 'my_arr=("one" "two") && typeof my_arr')
      expect(result).toBe('array')
    })

    it('should return "string" for unbound string literal', () => {
      const result = sourcedBash('./utils.sh', 'typeof "hello"')
      expect(result).toBe('string')
    })

    it('should return "empty" for unbound empty string', () => {
      const result = sourcedBash('./utils.sh', 'typeof ""')
      expect(result).toBe('empty')
    })
  })

  describe('is_typeof()', () => {
    it('should return 0 when type matches', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_typeof my_var "string"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 when type does not match', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_typeof my_var "number"')
      expect(exitCode).toBe(1)
    })

    it('should return 0 for array type match', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_arr=("one") && is_typeof my_arr "array"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for array type mismatch', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_typeof my_var "array"')
      expect(exitCode).toBe(1)
    })
  })

  describe('is_not_typeof()', () => {
    it('should return 1 when type matches', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_not_typeof my_var "string"')
      expect(exitCode).toBe(1)
    })

    it('should return 0 when type does not match', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_not_typeof my_var "number"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for array type match', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_arr=("one") && is_not_typeof my_arr "array"')
      expect(exitCode).toBe(1)
    })

    it('should return 0 for array type mismatch', () => {
      const exitCode = bashExitCode('source ./utils.sh && my_var="hello" && is_not_typeof my_var "array"')
      expect(exitCode).toBe(0)
    })
  })
})
