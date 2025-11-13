import { describe, it, expect } from 'vitest'
import { sourceScript } from './helpers'

describe('empty utilities', () => {
  describe('not_empty()', () => {
    it('should return 0 for non-empty string', () => {
      const api = sourceScript('./utils.sh')('not_empty')('hello')
      expect(api).toBeSuccessful()
    })

    it('should return 1 for empty string', () => {
      const api = sourceScript('./utils.sh')('not_empty')('')
      expect(api).toFail()
    })

    it('should return 0 for whitespace (whitespace is not empty)', () => {
      const api = sourceScript('./utils.sh')('not_empty')('  ')
      expect(api).toBeSuccessful()
    })

    it('should return 0 for string with newline', () => {
      const api = sourceScript('./utils.sh')('not_empty')('\n')
      expect(api).toBeSuccessful()
    })

    it('should return 0 for string with tab', () => {
      const api = sourceScript('./utils.sh')('not_empty')('\t')
      expect(api).toBeSuccessful()
    })

    it('should return 1 when no parameter passed', () => {
      const api = sourceScript('./utils.sh')('not_empty')()
      expect(api).toFail()
    })

    it('should return 0 for zero', () => {
      const api = sourceScript('./utils.sh')('not_empty')('0')
      expect(api).toBeSuccessful()
    })

    it('should return 0 for special characters', () => {
      const api = sourceScript('./utils.sh')('not_empty')('!@#$')
      expect(api).toBeSuccessful()
    })
  })

  describe('is_empty_string()', () => {
    it('should return 0 for empty string', () => {
      const api = sourceScript('./utils.sh')('is_empty_string')('')
      expect(api).toBeSuccessful()
    })

    it('should return 1 for non-empty string', () => {
      const api = sourceScript('./utils.sh')('is_empty_string')('hello')
      expect(api).toFail()
    })

    it('should return 1 for whitespace (whitespace is not empty)', () => {
      const api = sourceScript('./utils.sh')('is_empty_string')('  ')
      expect(api).toFail()
    })

    it('should return 1 for string with newline', () => {
      const api = sourceScript('./utils.sh')('is_empty_string')('\n')
      expect(api).toFail()
    })

    it('should return 0 when no parameter passed', () => {
      const api = sourceScript('./utils.sh')('is_empty_string')()
      expect(api).toBeSuccessful()
    })

    it('should return 1 for zero', () => {
      const api = sourceScript('./utils.sh')('is_empty_string')('0')
      expect(api).toFail()
    })

    it('should return 1 for false string', () => {
      const api = sourceScript('./utils.sh')('is_empty_string')('false')
      expect(api).toFail()
    })
  })

  describe('is_empty()', () => {
    it('should return 0 for empty string', () => {
      const api = sourceScript('./utils.sh')('is_empty')('')
      expect(api).toBeSuccessful()
    })

    it('should return 1 for non-empty string', () => {
      const api = sourceScript('./utils.sh')('is_empty')('hello')
      expect(api).toFail()
    })

    it('should return 1 for whitespace (whitespace is not empty)', () => {
      const api = sourceScript('./utils.sh')('is_empty')('  ')
      expect(api).toFail()
    })

    it('should return 1 for string with newline', () => {
      const api = sourceScript('./utils.sh')('is_empty')('\n')
      expect(api).toFail()
    })

    it('should return 0 when no parameter passed', () => {
      const api = sourceScript('./utils.sh')('is_empty')()
      expect(api).toBeSuccessful()
    })

    it('should return 1 for zero', () => {
      const api = sourceScript('./utils.sh')('is_empty')('0')
      expect(api).toFail()
    })

    it('should return 1 for negative number', () => {
      const api = sourceScript('./utils.sh')('is_empty')('-1')
      expect(api).toFail()
    })

    it('should return 1 for special characters', () => {
      const api = sourceScript('./utils.sh')('is_empty')('!@#')
      expect(api).toFail()
    })
  })
})
