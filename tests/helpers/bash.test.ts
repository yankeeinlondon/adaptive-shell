import { describe, it, expect } from 'vitest'
import { bash, sourcedBash, bashExitCode } from './index'

describe('bash helper utilities', () => {
  describe('bash()', () => {
    it('should execute simple bash command and return output', () => {
      const result = bash('echo "hello world"')
      expect(result).toBe('hello world')
    })

    it('should execute multi-line bash script', () => {
      const result = bash(`
        name="test"
        echo "hello $name"
      `)
      expect(result).toBe('hello test')
    })

    it('should handle commands that return empty output', () => {
      const result = bash('true')
      expect(result).toBe('')
    })

    it('should set ROOT environment variable to current directory', () => {
      const result = bash('echo "$ROOT"')
      expect(result).toBe(process.cwd())
    })

    it('should allow custom environment variables', () => {
      const result = bash('echo "$CUSTOM_VAR"', {
        env: { CUSTOM_VAR: 'custom-value' }
      })
      expect(result).toBe('custom-value')
    })

    it('should trim trailing newlines from output', () => {
      const result = bash('echo "hello"')
      // echo adds a newline, bash helper should trim it
      expect(result).toBe('hello')
    })
  })

  describe('sourcedBash()', () => {
    it('should source a file and execute commands', () => {
      // This will test with utils/color.sh since it exists
      const result = sourcedBash('./utils/color.sh', 'echo "test"')
      expect(result).toBe('test')
    })

    it('should have access to functions from sourced file', () => {
      // Test that we can call a function from utils/lists.sh
      // list_contains_val should be available after sourcing
      const result = sourcedBash('./utils/lists.sh', `
        echo "apple" | list_contains_val "apple" && echo "found"
      `)
      expect(result).toBe('found')
    })

    it('should allow environment variable overrides', () => {
      const result = sourcedBash('./utils/color.sh', 'echo "$TEST_VAR"', {
        env: { TEST_VAR: 'override' }
      })
      expect(result).toBe('override')
    })
  })

  describe('bashExitCode()', () => {
    it('should return 0 for successful command', () => {
      const exitCode = bashExitCode('true')
      expect(exitCode).toBe(0)
    })

    it('should return 0 for echo command', () => {
      const exitCode = bashExitCode('echo "hello"')
      expect(exitCode).toBe(0)
    })

    it('should return 1 for false command', () => {
      const exitCode = bashExitCode('false')
      expect(exitCode).toBe(1)
    })

    it('should return custom exit code', () => {
      const exitCode = bashExitCode('exit 42')
      expect(exitCode).toBe(42)
    })

    it('should handle successful multi-line scripts', () => {
      const exitCode = bashExitCode(`
        result="success"
        if [ "$result" = "success" ]; then
          exit 0
        else
          exit 1
        fi
      `)
      expect(exitCode).toBe(0)
    })

    it('should handle failed multi-line scripts', () => {
      const exitCode = bashExitCode(`
        result="failure"
        if [ "$result" = "success" ]; then
          exit 0
        else
          exit 1
        fi
      `)
      expect(exitCode).toBe(1)
    })
  })
})
