import { describe, it, expect } from 'vitest'
import { sourcedBash, bashExitCode } from './helpers/bash'

describe('color utilities', () => {
  describe('setup_colors()', () => {
    it('should set color variables', () => {
      const result = sourcedBash('./utils/color.sh', `
        setup_colors
        echo "$RED"
      `)

      // RED should be set to a non-empty value (ANSI escape code)
      expect(result).not.toBe('')
      expect(result.length).toBeGreaterThan(0)
    })

    it('should set BOLD variable', () => {
      const result = sourcedBash('./utils/color.sh', `
        setup_colors
        echo "$BOLD"
      `)

      expect(result).not.toBe('')
    })

    it('should set RESET variable', () => {
      const result = sourcedBash('./utils/color.sh', `
        setup_colors
        echo "$RESET"
      `)

      expect(result).not.toBe('')
    })
  })

  describe('colorize()', () => {
    it('should replace {{RED}} markers with color codes', () => {
      const result = sourcedBash('./utils/color.sh', `
        setup_colors
        colorize "Hello {{RED}}world{{RESET}}"
      `)

      // Should not contain the literal {{RED}} anymore
      expect(result).not.toContain('{{RED}}')
      expect(result).not.toContain('{{RESET}}')
      // Should contain ANSI codes
      expect(result.length).toBeGreaterThan('Hello world'.length)
    })

    it('should handle multiple color markers', () => {
      const result = sourcedBash('./utils/color.sh', `
        setup_colors
        colorize "{{BLUE}}Blue{{RESET}} and {{GREEN}}Green{{RESET}}"
      `)

      expect(result).not.toContain('{{BLUE}}')
      expect(result).not.toContain('{{GREEN}}')
      expect(result).not.toContain('{{RESET}}')
    })

    it('should handle text without markers', () => {
      const result = sourcedBash('./utils/color.sh', `
        setup_colors
        colorize "Plain text"
      `)

      expect(result).toBe('Plain text')
    })
  })

  describe('rgb_text()', () => {
    it('should produce output for foreground color', () => {
      const result = sourcedBash('./utils/color.sh', 'rgb_text "255 0 0" "red text"')

      expect(result).toContain('red text')
      expect(result.length).toBeGreaterThan('red text'.length)
    })

    it('should produce output for foreground and background', () => {
      const result = sourcedBash('./utils/color.sh', 'rgb_text "255 0 0 / 0 0 255" "text"')

      expect(result).toContain('text')
      expect(result.length).toBeGreaterThan('text'.length)
    })

    it('should handle background only', () => {
      const result = sourcedBash('./utils/color.sh', 'rgb_text "/ 255 255 0" "text"')

      expect(result).toContain('text')
      expect(result.length).toBeGreaterThan('text'.length)
    })
  })

  describe('color shortcut functions', () => {
    it('should have orange() function', () => {
      const result = sourcedBash('./utils/color.sh', 'orange "test"')
      expect(result).toContain('test')
      expect(result.length).toBeGreaterThan('test'.length)
    })

    it('should have blue() function', () => {
      const result = sourcedBash('./utils/color.sh', 'blue "test"')
      expect(result).toContain('test')
    })

    it('should have green() function', () => {
      const result = sourcedBash('./utils/color.sh', 'green "test"')
      expect(result).toContain('test')
    })

    it('should have red() function', () => {
      const result = sourcedBash('./utils/color.sh', 'red "test"')
      expect(result).toContain('test')
    })
  })

  describe('color state functions', () => {
    it('should detect when colors are not setup', () => {
      const exitCode = bashExitCode('source ./utils/color.sh && colors_not_setup')
      expect(exitCode).toBe(0)
    })

    it('should detect when colors are setup', () => {
      const exitCode = bashExitCode('source ./utils/color.sh && setup_colors && colors_are_setup')
      expect(exitCode).toBe(0)
    })
  })

  describe('remove_colors()', () => {
    it('should unset color variables', () => {
      const result = sourcedBash('./utils/color.sh', `
        setup_colors
        remove_colors
        echo "$RED"
      `)

      // After remove_colors, RED should be empty
      expect(result).toBe('')
    })
  })
})
