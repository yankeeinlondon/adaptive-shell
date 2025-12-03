import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { writeFileSync, unlinkSync } from 'fs'
import { join } from 'path'
import { tmpdir } from 'os'
import { execSync } from 'child_process'

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

    // Run all operations in a SINGLE bash process to cache the function registry
    // The registry is built once on first file_dependencies call, then reused
    // This reduces test time from ~5s to ~1.7s by running bash only 1 time instead of 3
    const DELIMITER = '___SPLIT_MARKER___'
    const script = `
      source ./reports/file-deps.sh

      # First call - builds and caches the registry
      file_dependencies "${tempTestFile}"
      echo "${DELIMITER}"

      # Second call - reuses cached registry
      report_file_dependencies "${tempTestFile}" 2>&1
      echo "${DELIMITER}"

      # Third call - reuses cached registry
      report_file_dependencies "${tempTestFile}" --json
    `

    const result = execSync(script, {
      shell: 'bash',
      encoding: 'utf-8',
      cwd: process.cwd(),
      env: { ...process.env, ROOT: process.cwd() }
    })

    const [fileDepsJson, consoleOutput, reportJson] = result.split(DELIMITER).map(s => s.trim())

    cachedFileDepsResult = JSON.parse(fileDepsJson)
    cachedReportConsoleOutput = consoleOutput
    cachedReportJsonResult = JSON.parse(reportJson)
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
