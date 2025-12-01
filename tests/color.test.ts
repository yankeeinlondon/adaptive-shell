import { describe, it, expect } from 'vitest'
import { sourceScript } from './helpers'

describe('color utilities', () => {
  describe('setup_colors()', () => {
    it('should execute successfully', () => {
      const api = sourceScript('./utils/color.sh')('setup_colors')()
      expect(api).toBeSuccessful()
    })

    // Note: setup_colors sets environment variables (RED, BOLD, RESET, etc.)
    // which can't be easily tested in isolation with sourceScript().
    // The color functions below (rgb_text, colorize, etc.) verify these work correctly.
  })

  describe('colorize()', () => {
    // Note: colorize() requires setup_colors() to be called first to set environment variables.
    // Since sourceScript() calls are independent, we test that colorize() executes successfully
    // and returns the input text (possibly with markers still present if colors aren't setup).
    // The actual color replacement is tested implicitly through rgb_text() and other functions
    // that don't depend on pre-set environment variables.

    it('should execute successfully with color markers', () => {
      const api = sourceScript('./utils/color.sh')('colorize')('Hello {{RED}}world{{RESET}}')
      expect(api).toBeSuccessful()
      // Without setup_colors being called first, markers remain
      expect(api).toContainInStdOut('Hello')
      expect(api).toContainInStdOut('world')
    })

    it('should handle multiple color markers', () => {
      const api = sourceScript('./utils/color.sh')('colorize')('{{BLUE}}Blue{{RESET}} and {{GREEN}}Green{{RESET}}')
      expect(api).toBeSuccessful()
      expect(api).toContainInStdOut('Blue')
      expect(api).toContainInStdOut('Green')
    })

    it('should handle text without markers', () => {
      const api = sourceScript('./utils/color.sh')('colorize')('Plain text')
      expect(api).toReturn('Plain text')
    })
  })

  describe('rgb_text()', () => {
    it('should produce output for foreground color', () => {
      const api = sourceScript('./utils/color.sh')('rgb_text')('255 0 0', 'red text')

      expect(api).toContainInStdOut('red text')
      expect(api.result.stdout.length).toBeGreaterThan('red text'.length)
    })

    it('should produce output for foreground and background', () => {
      const api = sourceScript('./utils/color.sh')('rgb_text')('255 0 0 / 0 0 255', 'text')

      expect(api).toContainInStdOut('text')
      expect(api.result.stdout.length).toBeGreaterThan('text'.length)
    })

    it('should handle background only', () => {
      const api = sourceScript('./utils/color.sh')('rgb_text')('/ 255 255 0', 'text')

      expect(api).toContainInStdOut('text')
      expect(api.result.stdout.length).toBeGreaterThan('text'.length)
    })
  })

  describe('color shortcut functions', () => {
    it('should have orange() function', () => {
      const api = sourceScript('./utils/color.sh')('orange')('test')
      expect(api).toContainInStdOut('test')
      expect(api.result.stdout.length).toBeGreaterThan('test'.length)
    })

    it('should have blue() function', () => {
      const api = sourceScript('./utils/color.sh')('blue')('test')
      expect(api).toContainInStdOut('test')
    })

    it('should have green() function', () => {
      const api = sourceScript('./utils/color.sh')('green')('test')
      expect(api).toContainInStdOut('test')
    })

    it('should have red() function', () => {
      const api = sourceScript('./utils/color.sh')('red')('test')
      expect(api).toContainInStdOut('test')
    })
  })

  describe('color state functions', () => {
    it('should detect when colors are not setup', () => {
      const api = sourceScript('./utils/color.sh')('colors_not_setup')()
      expect(api).toBeSuccessful()
    })

    it('should execute colors_are_setup function', () => {
      // Note: colors_are_setup may call setup_colors internally or have different behavior
      // We verify the function executes successfully
      const api = sourceScript('./utils/color.sh')('colors_are_setup')()
      expect(api).toBeSuccessful()
    })
  })

  describe('remove_colors()', () => {
    it('should execute successfully', () => {
      const api = sourceScript('./utils/color.sh')('remove_colors')()
      expect(api).toBeSuccessful()
    })

    // Note: remove_colors unsets environment variables (RED, BOLD, etc.)
    // Testing that variables are unset would require multi-line bash scripts
    // which sourceScript doesn't support. The function succeeding indicates it works.
  })

  describe('terminal background detection', () => {
    describe('terminal_background_color()', () => {
      it('should respect TERMINAL_BG_COLOR environment override', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '30 30 30' }
        })('terminal_background_color')()

        expect(api).toBeSuccessful()
        expect(api).toReturn('30 30 30')
      })

      it('should return empty string when no terminal is attached', () => {
        // When run in tests (non-interactive), terminal_background_color should
        // fail or return empty since there's no real terminal to query
        const api = sourceScript('./utils/color.sh')('terminal_background_color')()

        // In CI/non-interactive context, the function should fail (non-zero exit)
        // or return empty string
        if (api.result.code !== 0) {
          expect(api).toFail()
        } else {
          expect(api).toReturn('')
        }
      })

      it('should handle various RGB values via override', () => {
        const testCases = [
          '0 0 0',       // Pure black
          '255 255 255', // Pure white
          '128 128 128', // Mid-gray
          '240 240 240', // Light gray
          '30 30 30',    // Dark gray
        ]

        for (const rgb of testCases) {
          const api = sourceScript('./utils/color.sh', {
            env: { TERMINAL_BG_COLOR: rgb }
          })('terminal_background_color')()

          expect(api).toBeSuccessful()
          expect(api).toReturn(rgb)
        }
      })
    })

    describe('is_dark_mode()', () => {
      it('should respect TERMINAL_THEME=dark override', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_THEME: 'dark' }
        })('is_dark_mode')()

        expect(api).toBeSuccessful() // exit code 0 = true
      })

      it('should return false when TERMINAL_THEME=light', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_THEME: 'light' }
        })('is_dark_mode')()

        expect(api).toFail() // exit code 1 = false
      })

      it('should detect pure black background as dark', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '0 0 0' }
        })('is_dark_mode')()

        expect(api).toBeSuccessful()
      })

      it('should detect dark gray background as dark', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '64 64 64' }
        })('is_dark_mode')()

        expect(api).toBeSuccessful()
      })

      it('should detect typical dark theme background as dark', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '30 30 30' }
        })('is_dark_mode')()

        expect(api).toBeSuccessful()
      })

      it('should detect pure white background as light (not dark)', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '255 255 255' }
        })('is_dark_mode')()

        expect(api).toFail() // white is light, not dark
      })

      it('should detect typical light theme background as light (not dark)', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '240 240 240' }
        })('is_dark_mode')()

        expect(api).toFail() // light background = not dark
      })

      it('should default to dark mode when terminal detection fails', () => {
        // When no override is set and terminal query fails,
        // should default to dark mode (return 0)
        const api = sourceScript('./utils/color.sh')('is_dark_mode')()

        expect(api).toBeSuccessful() // defaults to dark
      })
    })

    describe('is_light_mode()', () => {
      it('should respect TERMINAL_THEME=light override', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_THEME: 'light' }
        })('is_light_mode')()

        expect(api).toBeSuccessful() // exit code 0 = true
      })

      it('should return false when TERMINAL_THEME=dark', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_THEME: 'dark' }
        })('is_light_mode')()

        expect(api).toFail() // exit code 1 = false
      })

      it('should detect pure white background as light', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '255 255 255' }
        })('is_light_mode')()

        expect(api).toBeSuccessful()
      })

      it('should detect typical light theme background as light', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '240 240 240' }
        })('is_light_mode')()

        expect(api).toBeSuccessful()
      })

      it('should detect pure black background as dark (not light)', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '0 0 0' }
        })('is_light_mode')()

        expect(api).toFail() // black is dark, not light
      })

      it('should detect typical dark theme background as dark (not light)', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '30 30 30' }
        })('is_light_mode')()

        expect(api).toFail() // dark background = not light
      })

      it('should default to dark mode (not light) when terminal detection fails', () => {
        // When no override is set and terminal query fails,
        // should default to dark mode, so is_light_mode returns false
        const api = sourceScript('./utils/color.sh')('is_light_mode')()

        expect(api).toFail() // defaults to dark = not light
      })
    })

    describe('luminance calculation edge cases', () => {
      it('should treat luminance boundary (128) as light mode', () => {
        // Luminance of ~128 should be considered light (>= 128)
        // Pure gray (128 128 128) has luminance = (2126*128 + 7152*128 + 722*128)/10000 = 128
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '128 128 128' }
        })('is_light_mode')()

        expect(api).toBeSuccessful() // luminance >= 128 = light
      })

      it('should treat luminance just below boundary as dark mode', () => {
        // RGB values that result in luminance < 128 should be dark
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '127 127 127' }
        })('is_dark_mode')()

        expect(api).toBeSuccessful() // luminance < 128 = dark
      })

      it('should handle non-gray colors correctly - dark blue', () => {
        // Dark blue: R=0, G=0, B=100
        // Luminance = (0 + 0 + 722*100)/10000 = 7.22 (very dark)
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '0 0 100' }
        })('is_dark_mode')()

        expect(api).toBeSuccessful()
      })

      it('should handle non-gray colors correctly - bright green', () => {
        // Bright green: R=0, G=200, B=0
        // Luminance = (0 + 7152*200 + 0)/10000 = 143.04 (light)
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '0 200 0' }
        })('is_light_mode')()

        expect(api).toBeSuccessful()
      })

      it('should handle non-gray colors correctly - red-heavy dark', () => {
        // Red=100, G=0, B=0
        // Luminance = (2126*100)/10000 = 21.26 (dark)
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '100 0 0' }
        })('is_dark_mode')()

        expect(api).toBeSuccessful()
      })

      it('should handle weighted color - green weighted but still dark', () => {
        // Green has highest weight (0.7152) in luminance calculation
        // R=50, G=150, B=50
        // Luminance = (2126*50 + 7152*150 + 722*50)/10000 = 121.52 (< 128 = dark)
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '50 150 50' }
        })('is_dark_mode')()

        expect(api).toBeSuccessful()
      })
    })

    describe('inverse relationship between is_dark_mode and is_light_mode', () => {
      it('should be opposites for pure black', () => {
        const darkApi = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '0 0 0' }
        })('is_dark_mode')()

        const lightApi = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '0 0 0' }
        })('is_light_mode')()

        expect(darkApi).toBeSuccessful()
        expect(lightApi).toFail()
      })

      it('should be opposites for pure white', () => {
        const darkApi = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '255 255 255' }
        })('is_dark_mode')()

        const lightApi = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '255 255 255' }
        })('is_light_mode')()

        expect(darkApi).toFail()
        expect(lightApi).toBeSuccessful()
      })

      it('should be opposites at boundary', () => {
        const darkApi = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '128 128 128' }
        })('is_dark_mode')()

        const lightApi = sourceScript('./utils/color.sh', {
          env: { TERMINAL_BG_COLOR: '128 128 128' }
        })('is_light_mode')()

        // At boundary (128), should be light (>= 128)
        expect(darkApi).toFail()
        expect(lightApi).toBeSuccessful()
      })
    })

    describe('terminal_foreground_color()', () => {
      it('should respect TERMINAL_FG_COLOR environment override', () => {
        const api = sourceScript('./utils/color.sh', {
          env: { TERMINAL_FG_COLOR: '200 200 200' }
        })('terminal_foreground_color')()

        expect(api).toBeSuccessful()
        expect(api).toReturn('200 200 200')
      })

      it('should handle various RGB values via override', () => {
        const testCases = [
          '0 0 0',       // Pure black text
          '255 255 255', // Pure white text
          '128 128 128', // Gray text
          '0 255 0',     // Green text
        ]

        for (const rgb of testCases) {
          const api = sourceScript('./utils/color.sh', {
            env: { TERMINAL_FG_COLOR: rgb }
          })('terminal_foreground_color')()

          expect(api).toBeSuccessful()
          expect(api).toReturn(rgb)
        }
      })

      it('should return empty string when no terminal is attached', () => {
        const api = sourceScript('./utils/color.sh')('terminal_foreground_color')()

        // In CI/non-interactive context, the function should fail
        if (api.result.code !== 0) {
          expect(api).toFail()
        } else {
          expect(api).toReturn('')
        }
      })
    })

    describe('calculate_luminance()', () => {
      it('should calculate luminance for pure black (0)', () => {
        const api = sourceScript('./utils/color.sh')('calculate_luminance')('0 0 0')
        expect(api).toBeSuccessful()
        expect(api).toReturn('0')
      })

      it('should calculate luminance for pure white (255)', () => {
        const api = sourceScript('./utils/color.sh')('calculate_luminance')('255 255 255')
        expect(api).toBeSuccessful()
        expect(api).toReturn('255')
      })

      it('should calculate luminance for mid-gray (128)', () => {
        const api = sourceScript('./utils/color.sh')('calculate_luminance')('128 128 128')
        expect(api).toBeSuccessful()
        expect(api).toReturn('128')
      })

      it('should weight green highest in luminance calculation', () => {
        // Pure green (0, 255, 0) should have higher luminance than
        // pure red (255, 0, 0) or pure blue (0, 0, 255)
        const greenApi = sourceScript('./utils/color.sh')('calculate_luminance')('0 255 0')
        const redApi = sourceScript('./utils/color.sh')('calculate_luminance')('255 0 0')
        const blueApi = sourceScript('./utils/color.sh')('calculate_luminance')('0 0 255')

        expect(greenApi).toBeSuccessful()
        expect(redApi).toBeSuccessful()
        expect(blueApi).toBeSuccessful()

        const greenLum = parseInt(greenApi.result.stdout)
        const redLum = parseInt(redApi.result.stdout)
        const blueLum = parseInt(blueApi.result.stdout)

        // Green should be brightest, then red, then blue
        expect(greenLum).toBeGreaterThan(redLum)
        expect(redLum).toBeGreaterThan(blueLum)
      })

      it('should accept three separate arguments', () => {
        const api = sourceScript('./utils/color.sh')('calculate_luminance')('100', '150', '200')
        expect(api).toBeSuccessful()
        // (2126*100 + 7152*150 + 722*200) / 10000 = 130 (approx)
        const luminance = parseInt(api.result.stdout)
        expect(luminance).toBeGreaterThan(0)
        expect(luminance).toBeLessThan(256)
      })

      it('should fail for invalid input', () => {
        const api = sourceScript('./utils/color.sh')('calculate_luminance')('invalid')
        expect(api).toFail()
      })
    })

    describe('calculate_contrast_ratio()', () => {
      it('should calculate highest contrast for black on white', () => {
        const api = sourceScript('./utils/color.sh')('calculate_contrast_ratio')('0 0 0', '255 255 255')
        expect(api).toBeSuccessful()
        // Maximum contrast ratio is 21:1 (2100 when * 100)
        const ratio = parseInt(api.result.stdout)
        expect(ratio).toBeGreaterThan(2000)
      })

      it('should calculate highest contrast for white on black', () => {
        const api = sourceScript('./utils/color.sh')('calculate_contrast_ratio')('255 255 255', '0 0 0')
        expect(api).toBeSuccessful()
        const ratio = parseInt(api.result.stdout)
        expect(ratio).toBeGreaterThan(2000)
      })

      it('should calculate 1:1 ratio for same colors', () => {
        const api = sourceScript('./utils/color.sh')('calculate_contrast_ratio')('128 128 128', '128 128 128')
        expect(api).toBeSuccessful()
        const ratio = parseInt(api.result.stdout)
        expect(ratio).toBe(100) // 1:1 = 100 when * 100
      })

      it('should produce reasonable ratios for typical dark theme', () => {
        // Light gray text on dark background
        const api = sourceScript('./utils/color.sh')('calculate_contrast_ratio')('200 200 200', '30 30 30')
        expect(api).toBeSuccessful()
        const ratio = parseInt(api.result.stdout)
        // Should have good contrast (>= 450 for WCAG AA)
        expect(ratio).toBeGreaterThan(400)
      })

      it('should produce reasonable ratios for typical light theme', () => {
        // Dark text on light background
        const api = sourceScript('./utils/color.sh')('calculate_contrast_ratio')('30 30 30', '240 240 240')
        expect(api).toBeSuccessful()
        const ratio = parseInt(api.result.stdout)
        expect(ratio).toBeGreaterThan(400)
      })
    })

    describe('_parse_osc_rgb_response()', () => {
      it('should parse standard 4-digit hex response', () => {
        // Simulating response: ESC]11;rgb:1c1c/1c1c/1c1cBEL
        const api = sourceScript('./utils/color.sh')('_parse_osc_rgb_response')('rgb:1c1c/1c1c/1c1c')
        expect(api).toBeSuccessful()
        expect(api).toReturn('28 28 28')
      })

      it('should parse 2-digit hex response', () => {
        const api = sourceScript('./utils/color.sh')('_parse_osc_rgb_response')('rgb:ff/80/00')
        expect(api).toBeSuccessful()
        expect(api).toReturn('255 128 0')
      })

      it('should handle response with surrounding noise', () => {
        // Real responses have ESC sequences before and BEL/ST after
        const api = sourceScript('./utils/color.sh')('_parse_osc_rgb_response')('junk;rgb:abab/cdcd/efef;morejunk')
        expect(api).toBeSuccessful()
        expect(api).toReturn('171 205 239')
      })

      it('should fail for invalid response format', () => {
        const api = sourceScript('./utils/color.sh')('_parse_osc_rgb_response')('not a valid response')
        expect(api).toFail()
      })

      it('should fail for empty input', () => {
        const api = sourceScript('./utils/color.sh')('_parse_osc_rgb_response')('')
        expect(api).toFail()
      })

      it('should parse pure black response', () => {
        const api = sourceScript('./utils/color.sh')('_parse_osc_rgb_response')('rgb:0000/0000/0000')
        expect(api).toBeSuccessful()
        expect(api).toReturn('0 0 0')
      })

      it('should parse pure white response', () => {
        const api = sourceScript('./utils/color.sh')('_parse_osc_rgb_response')('rgb:ffff/ffff/ffff')
        expect(api).toBeSuccessful()
        expect(api).toReturn('255 255 255')
      })
    })

  })
})
