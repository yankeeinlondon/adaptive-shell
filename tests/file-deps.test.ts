import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { writeFileSync, unlinkSync } from 'fs'
import { join } from 'path'
import { tmpdir } from 'os'
import { sourcedBash, sourcedBashWithStderr } from './helpers/bash'

describe('file dependency analysis', () => {
  let tempTestFile: string
  let cachedFileDepsResult: any
  let cachedReportConsoleOutput: string
  let cachedReportJsonResult: any

  beforeAll(() => {
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

    // Run the expensive operations once and cache results
    // This reduces test time from ~7.8s to ~2.5s by running bash only 3 times instead of 6
    const resultJson = sourcedBash('./reports/file-deps.sh', `file_dependencies "${tempTestFile}"`)
    cachedFileDepsResult = JSON.parse(resultJson)

    cachedReportConsoleOutput = sourcedBashWithStderr('./reports/file-deps.sh', `report_file_dependencies "${tempTestFile}"`)

    const jsonOutput = sourcedBash('./reports/file-deps.sh', `report_file_dependencies "${tempTestFile}" --json`)
    cachedReportJsonResult = JSON.parse(jsonOutput)
  })

  afterAll(() => {
    // Clean up temp file
    try {
      unlinkSync(tempTestFile)
    } catch (error) {
      // File might already be deleted
    }
  })

  describe('file_dependencies()', () => {
    it('should detect source dependencies', () => {
      // The test file calls: setup_colors, log, trim, rgb_text
      // These are defined in: utils/color.sh, utils/logging.sh, utils/text.sh
      const files = cachedFileDepsResult.files || []

      expect(files.some((f: string) => f.endsWith('/utils/color.sh'))).toBe(true)
      expect(files.some((f: string) => f.endsWith('/utils/logging.sh'))).toBe(true)
      expect(files.some((f: string) => f.endsWith('/utils/text.sh'))).toBe(true)
    })

    it('should detect function calls', () => {
      const functions = cachedFileDepsResult.functions || []

      expect(functions).toContain('setup_colors')
      expect(functions).toContain('log')
      expect(functions).toContain('trim')
    })

    it('should return valid JSON structure', () => {
      expect(cachedFileDepsResult).toHaveProperty('files')
      expect(cachedFileDepsResult).toHaveProperty('functions')
      expect(Array.isArray(cachedFileDepsResult.files)).toBe(true)
      expect(Array.isArray(cachedFileDepsResult.functions)).toBe(true)
    })
  })

  describe('report_file_dependencies()', () => {
    it('should produce console output with expected sections', () => {
      expect(cachedReportConsoleOutput).toContain('Source Dependencies:')
      expect(cachedReportConsoleOutput).toContain('Function Calls:')
    })

    it('should produce valid JSON output with --json flag', () => {
      expect(cachedReportJsonResult).toHaveProperty('results')
      expect(Array.isArray(cachedReportJsonResult.results)).toBe(true)
      expect(cachedReportJsonResult.results.length).toBeGreaterThan(0)

      const firstResult = cachedReportJsonResult.results[0]
      expect(firstResult).toHaveProperty('file')
      expect(firstResult).toHaveProperty('dependencies')
      expect(firstResult.dependencies).toHaveProperty('files')
      expect(firstResult.dependencies).toHaveProperty('functions')
    })

    it('should include correct file path in JSON output', () => {
      expect(cachedReportJsonResult.results[0].file).toBe(tempTestFile)
    })
  })
})
