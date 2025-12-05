import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { writeFileSync, unlinkSync } from 'fs'
import { join } from 'path'
import { tmpdir } from 'os'
import { execSync } from 'child_process'

// Skip on native Windows - bash script testing requires Unix environment
// WSL provides a full Linux environment and should work fine
const isWindows = process.platform === 'win32'
const skipTest = isWindows

describe.skipIf(skipTest)('file dependency analysis', () => {
  let tempTestFile: string
  let cachedFileDepsResult: any
  let cachedReportConsoleOutput: string
  let cachedReportJsonResult: any

  beforeAll(() => {
    // Skip setup on Windows/WSL - Vitest's skipIf doesn't prevent beforeAll from running
    if (skipTest) return

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

    // Create a minimal mock function registry
    // This avoids the expensive ~2s bash_functions_summary scan of the entire codebase
    const mockRegistry = JSON.stringify({
      "setup_colors": "${ROOT}/utils/color.sh",
      "log": "${ROOT}/utils/logging.sh",
      "trim": "${ROOT}/utils/text.sh",
      "rgb_text": "${ROOT}/utils/color.sh"
    })

    // Run all operations in a SINGLE bash process with mock registry
    // Using __FUNCTION_REGISTRY_CACHE skips the expensive registry build (~2s -> ~100ms)
    const DELIMITER = '___SPLIT_MARKER___'
    const script = `
      # Verify the mock registry cache is available - if not, fail fast
      # This prevents 30-second timeouts on CI if env var passing fails
      if [ -z "\${__FUNCTION_REGISTRY_CACHE:-}" ]; then
        echo "ERROR: __FUNCTION_REGISTRY_CACHE not set - env var passing failed" >&2
        exit 1
      fi

      source ./reports/file-deps.sh

      # First call - uses pre-set mock registry (no expensive build)
      file_dependencies "${tempTestFile}"
      echo "${DELIMITER}"

      # Second call - reuses cached registry
      report_file_dependencies "${tempTestFile}" 2>&1
      echo "${DELIMITER}"

      # Third call - reuses cached registry
      report_file_dependencies "${tempTestFile}" --json
    `

    let result: string
    try {
      result = execSync(script, {
        shell: 'bash',
        encoding: 'utf-8',
        cwd: process.cwd(),
        timeout: 30000, // 30 second timeout to prevent CI hangs
        env: {
          ...process.env,
          ROOT: process.cwd(),
          __FUNCTION_REGISTRY_CACHE: mockRegistry
        }
      })
    } catch (err: any) {
      // Provide clear error message for CI debugging
      const stderr = err.stderr?.toString() || ''
      const stdout = err.stdout?.toString() || ''
      throw new Error(
        `Bash script failed:\n` +
        `Exit code: ${err.status}\n` +
        `Signal: ${err.signal || 'none'}\n` +
        `Stderr: ${stderr.slice(0, 500)}\n` +
        `Stdout: ${stdout.slice(0, 500)}`
      )
    }

    const [fileDepsJson, consoleOutput, reportJson] = result.split(DELIMITER).map(s => s.trim())

    cachedFileDepsResult = JSON.parse(fileDepsJson)
    cachedReportConsoleOutput = consoleOutput
    cachedReportJsonResult = JSON.parse(reportJson)
  })

  afterAll(() => {
    // Skip cleanup on Windows/WSL
    if (skipTest) return

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
