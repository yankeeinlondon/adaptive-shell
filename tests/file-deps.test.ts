import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { writeFileSync, unlinkSync } from 'fs'
import { join } from 'path'
import { tmpdir } from 'os'
import { sourcedBash, sourcedBashWithStderr } from './helpers/bash'

describe('file dependency analysis', () => {
  let tempTestFile: string

  beforeEach(() => {
    // Create a temporary test file with known dependencies
    tempTestFile = join(tmpdir(), `test-file-deps-${Date.now()}.sh`)
    writeFileSync(tempTestFile, `#!/usr/bin/env bash

# Test file with dependencies
source "\${ROOT}/utils/color.sh"
source "\${ROOT}/utils/text.sh"

# Some function calls
setup_colors
log "Hello"
trim "  test  "
rgb_text "255 0 0" "red text"
`)
  })

  afterEach(() => {
    // Clean up temp file
    try {
      unlinkSync(tempTestFile)
    } catch (error) {
      // File might already be deleted
    }
  })

  describe('file_dependencies()', () => {
    it('should detect source dependencies', () => {
      const resultJson = sourcedBash('./reports/file-deps.sh', `file_dependencies "${tempTestFile}"`)
      const result = JSON.parse(resultJson)

      // The test file calls: setup_colors, log, trim, rgb_text
      // These are defined in: utils/color.sh, utils/logging.sh, utils/text.sh
      const files = result.files || []

      expect(files.some((f: string) => f.endsWith('/utils/color.sh'))).toBe(true)
      expect(files.some((f: string) => f.endsWith('/utils/logging.sh'))).toBe(true)
      expect(files.some((f: string) => f.endsWith('/utils/text.sh'))).toBe(true)
    })

    it('should detect function calls', () => {
      const resultJson = sourcedBash('./reports/file-deps.sh', `file_dependencies "${tempTestFile}"`)
      const result = JSON.parse(resultJson)

      const functions = result.functions || []

      expect(functions).toContain('setup_colors')
      expect(functions).toContain('log')
      expect(functions).toContain('trim')
    })

    it('should return valid JSON structure', () => {
      const resultJson = sourcedBash('./reports/file-deps.sh', `file_dependencies "${tempTestFile}"`)
      const result = JSON.parse(resultJson)

      expect(result).toHaveProperty('files')
      expect(result).toHaveProperty('functions')
      expect(Array.isArray(result.files)).toBe(true)
      expect(Array.isArray(result.functions)).toBe(true)
    })
  })

  describe('report_file_dependencies()', () => {
    it('should produce console output with expected sections', () => {
      const output = sourcedBashWithStderr('./reports/file-deps.sh', `report_file_dependencies "${tempTestFile}"`)

      expect(output).toContain('Source Dependencies:')
      expect(output).toContain('Function Calls:')
    })

    it('should produce valid JSON output with --json flag', () => {
      const jsonOutput = sourcedBash('./reports/file-deps.sh', `report_file_dependencies "${tempTestFile}" --json`)
      const result = JSON.parse(jsonOutput)

      expect(result).toHaveProperty('results')
      expect(Array.isArray(result.results)).toBe(true)
      expect(result.results.length).toBeGreaterThan(0)

      const firstResult = result.results[0]
      expect(firstResult).toHaveProperty('file')
      expect(firstResult).toHaveProperty('dependencies')
      expect(firstResult.dependencies).toHaveProperty('files')
      expect(firstResult.dependencies).toHaveProperty('functions')
    })

    it('should include correct file path in JSON output', () => {
      const jsonOutput = sourcedBash('./reports/file-deps.sh', `report_file_dependencies "${tempTestFile}" --json`)
      const result = JSON.parse(jsonOutput)

      expect(result.results[0].file).toBe(tempTestFile)
    })
  })
})
