import { describe, it, expect } from 'vitest'
import { sourcedBash, bashExitCode } from './helpers/bash'

describe('list utilities', () => {
  const testItems = ['apple', 'apricot', 'banana', 'berry', 'cherry', 'date', 'grape']

  describe('retain_prefixes_ref()', () => {
    it('should keep items starting with specified prefixes', () => {
      const result = sourcedBash('./utils/lists.sh',
        'test_items=("apple" "apricot" "banana" "berry" "cherry" "date" "grape"); retain_prefixes_ref test_items "a" "b"'
      )

      const items = result.split('\n').filter(Boolean)
      expect(items).toContain('apple')
      expect(items).toContain('apricot')
      expect(items).toContain('banana')
      expect(items).toContain('berry')
      expect(items).not.toContain('cherry')
      expect(items).not.toContain('date')
      expect(items).not.toContain('grape')
    })

    it('should return items in order', () => {
      const result = sourcedBash('./utils/lists.sh',
        'test_items=("apple" "apricot" "banana" "berry" "cherry" "date" "grape"); retain_prefixes_ref test_items "a" "b"'
      )

      const items = result.split('\n').filter(Boolean).join(' ')
      expect(items).toBe('apple apricot banana berry')
    })
  })

  describe('retain_prefixes_val()', () => {
    it('should keep items from stdin starting with specified prefixes', () => {
      const result = sourcedBash('./utils/lists.sh', `
        printf '%s\\n' "apple" "apricot" "banana" "berry" "cherry" "date" "grape" | retain_prefixes_val "c" "d"
      `)

      const items = result.split('\n').filter(Boolean)
      expect(items).toContain('cherry')
      expect(items).toContain('date')
      expect(items).not.toContain('apple')
      expect(items).not.toContain('banana')
    })

    it('should return items in order', () => {
      const result = sourcedBash('./utils/lists.sh', `
        printf '%s\\n' "apple" "apricot" "banana" "berry" "cherry" "date" "grape" | retain_prefixes_val "c" "d"
      `)

      const items = result.split('\n').filter(Boolean).join(' ')
      expect(items).toBe('cherry date')
    })
  })

  describe('filter_prefixes_ref()', () => {
    it('should remove items starting with specified prefixes', () => {
      const result = sourcedBash('./utils/lists.sh',
        'test_items=("apple" "apricot" "banana" "berry" "cherry" "date" "grape"); filter_prefixes_ref test_items "a" "b"'
      )

      const items = result.split('\n').filter(Boolean)
      expect(items).not.toContain('apple')
      expect(items).not.toContain('apricot')
      expect(items).not.toContain('banana')
      expect(items).not.toContain('berry')
      expect(items).toContain('cherry')
      expect(items).toContain('date')
      expect(items).toContain('grape')
    })

    it('should return items in order', () => {
      const result = sourcedBash('./utils/lists.sh',
        'test_items=("apple" "apricot" "banana" "berry" "cherry" "date" "grape"); filter_prefixes_ref test_items "a" "b"'
      )

      const items = result.split('\n').filter(Boolean).join(' ')
      expect(items).toBe('cherry date grape')
    })
  })

  describe('filter_prefixes_val()', () => {
    it('should remove items from stdin starting with specified prefixes', () => {
      const result = sourcedBash('./utils/lists.sh', `
        printf '%s\\n' "apple" "apricot" "banana" "berry" "cherry" "date" "grape" | filter_prefixes_val "g"
      `)

      const items = result.split('\n').filter(Boolean)
      expect(items).toContain('apple')
      expect(items).toContain('cherry')
      expect(items).not.toContain('grape')
    })

    it('should return items in order', () => {
      const result = sourcedBash('./utils/lists.sh', `
        printf '%s\\n' "apple" "apricot" "banana" "berry" "cherry" "date" "grape" | filter_prefixes_val "g"
      `)

      const items = result.split('\n').filter(Boolean).join(' ')
      expect(items).toBe('apple apricot banana berry cherry date')
    })
  })

  describe('list_contains_ref()', () => {
    it('should return 0 when item is found in array', () => {
      const exitCode = bashExitCode(`
        source ./utils/lists.sh
        test_items=("apple" "apricot" "banana" "berry" "cherry" "date" "grape")
        list_contains_ref test_items "banana"
      `)

      expect(exitCode).toBe(0)
    })

    it('should return 1 when item is not found in array', () => {
      const exitCode = bashExitCode(`
        source ./utils/lists.sh
        test_items=("apple" "apricot" "banana" "berry" "cherry" "date" "grape")
        list_contains_ref test_items "orange"
      `)

      expect(exitCode).toBe(1)
    })

    it('should handle empty arrays', () => {
      const exitCode = bashExitCode(`
        source ./utils/lists.sh
        test_items=()
        list_contains_ref test_items "apple"
      `)

      expect(exitCode).toBe(1)
    })
  })

  describe('list_contains_val()', () => {
    it('should return 0 when item is found in stdin', () => {
      const exitCode = bashExitCode(`
        source ./utils/lists.sh
        printf '%s\\n' "apple" "banana" "cherry" | list_contains_val "cherry"
      `)

      expect(exitCode).toBe(0)
    })

    it('should return 1 when item is not found in stdin', () => {
      const exitCode = bashExitCode(`
        source ./utils/lists.sh
        printf '%s\\n' "apple" "banana" "cherry" | list_contains_val "mango"
      `)

      expect(exitCode).toBe(1)
    })

    it('should handle empty stdin', () => {
      const exitCode = bashExitCode(`
        source ./utils/lists.sh
        echo -n "" | list_contains_val "apple"
      `)

      expect(exitCode).toBe(1)
    })
  })
})
