/**
 * Example Test File
 *
 * This file demonstrates how to write tests for bash functions using Vitest.
 * It shows the basic patterns and helpers available for testing bash scripts.
 */

import { describe, it, expect } from 'vitest'
import { bash, sourcedBash, bashExitCode } from './bash'

describe('example: testing bash functions', () => {
  describe('basic bash execution', () => {
    it('should execute simple bash commands', () => {
      const result = bash('echo "hello world"')
      expect(result).toBe('hello world')
    })

    it('should execute multi-line scripts', () => {
      const result = bash(`
        name="test"
        echo "hello $name"
      `)
      expect(result).toBe('hello test')
    })
  })

  describe('testing bash functions', () => {
    it('should test function output', () => {
      const result = sourcedBash('./utils/lists.sh', `
        echo "apple" | list_contains_val "apple" && echo "found"
      `)

      expect(result).toBe('found')
    })

    it('should test function exit codes', () => {
      const exitCode = bashExitCode(`
        source ./utils/lists.sh
        echo "apple" | list_contains_val "apple"
      `)

      expect(exitCode).toBe(0)
    })
  })

  describe('testing with environment variables', () => {
    it('should pass custom environment variables', () => {
      const result = bash('echo "$CUSTOM_VAR"', {
        env: { CUSTOM_VAR: 'custom-value' }
      })

      expect(result).toBe('custom-value')
    })

    it('should have ROOT variable set to project root', () => {
      const result = bash('echo "$ROOT"')
      expect(result).toBe(process.cwd())
    })
  })

  describe('testing error conditions', () => {
    it('should detect when commands fail', () => {
      const exitCode = bashExitCode('false')
      expect(exitCode).toBe(1)
    })

    it('should capture custom exit codes', () => {
      const exitCode = bashExitCode('exit 42')
      expect(exitCode).toBe(42)
    })
  })
})
