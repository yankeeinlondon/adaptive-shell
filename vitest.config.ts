import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.ts'],
    exclude: [],  // Allow WIP tests during development
    // Every assertion already runs in a fresh shell process. Reusing one Vitest
    // worker avoids paying worker startup/teardown costs for every test file
    // without reducing the shell-level isolation that the suite relies on.
    pool: 'forks',
    poolOptions: {
      forks: {
        singleFork: true
      }
    },
    fileParallelism: false,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'tests/**',
        '.claude/**',
        'node_modules/**',
        '**/*.config.ts'
      ]
    }
  }
})
