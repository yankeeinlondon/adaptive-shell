# Testing Guide

This repository uses a hybrid testing approach combining TypeScript/Vitest for automated testing with bash scripts for visual demonstrations.

## Quick Start

```bash
# Run all tests
pnpm test

# Run tests in watch mode
pnpm test:watch

# Run tests with UI
pnpm test:ui

# Run tests with coverage
pnpm test:coverage

# Run specific test file
pnpm test tests/text.test.ts
```

## Testing Architecture

### Hybrid Approach

We use two complementary testing strategies:

1. **Automated Tests (Vitest)** - TypeScript tests that verify functionality with assertions
2. **Visual Demos (Bash)** - Executable scripts that demonstrate features interactively

### Directory Structure

```
tests/
├── README.md                 # This file
├── helpers/
│   └── bash.ts              # Test utilities for calling bash from TypeScript
├── demos/
│   └── color-demo.sh        # Visual demonstrations
├── text.test.ts             # Automated tests for utils/text.sh
├── typeof.test.ts           # Automated tests for utils/typeof.sh
├── color.test.ts            # Automated tests for utils/color.sh
├── lists.test.ts            # Automated tests for utils/lists.sh
└── file-deps.test.ts        # Automated tests for reports/file-deps.sh
```

## Writing Tests

### Basic Test Structure

```typescript
import { describe, it, expect } from 'vitest'
import { sourcedBash, bashExitCode } from './helpers/bash'

describe('my utility', () => {
  describe('my_function()', () => {
    it('should do something', () => {
      const result = sourcedBash('./utils/my-util.sh', 'my_function "arg"')
      expect(result).toBe('expected output')
    })

    it('should return 0 on success', () => {
      const exitCode = bashExitCode('source ./utils/my-util.sh && my_function "arg"')
      expect(exitCode).toBe(0)
    })
  })
})
```

### Test Helper Functions

The `tests/helpers/bash.ts` module provides several utilities:

#### `bash(script: string, options?: BashOptions): string`
Execute a bash script and return stdout (trimmed).

```typescript
const output = bash('echo "hello world"')
// output === "hello world"
```

#### `sourcedBash(file: string, script: string, options?: BashOptions): string`
Source a file then execute a script.

```typescript
const result = sourcedBash('./utils/text.sh', 'lc "HELLO"')
// result === "hello"
```

#### `bashExitCode(script: string, options?: BashOptions): number`
Get the exit code of a bash script (0 = success, non-zero = failure).

```typescript
const exitCode = bashExitCode('source ./utils/text.sh && contains "world" "hello world"')
// exitCode === 0
```

#### `bashWithStderr(script: string, options?: BashOptions): string`
Execute bash and capture both stdout and stderr.

```typescript
const output = bashWithStderr('my_command 2>&1')
// Includes both stdout and stderr
```

#### `bashNoTrimStart(script: string, options?: BashOptions): string`
Execute bash preserving leading whitespace (useful for indentation tests).

```typescript
const indented = bashNoTrimStart('source ./utils/text.sh && indent "  " "hello"')
// indented === "  hello" (leading spaces preserved)
```

#### `sourcedBashNoTrimStart(file: string, script: string, options?: BashOptions): string`
Source a file and execute, preserving leading whitespace.

```typescript
const result = sourcedBashNoTrimStart('./utils/text.sh', 'indent "  " "test"')
// result === "  test"
```

### Common Patterns

#### Testing String Output

```typescript
it('should convert to lowercase', () => {
  const result = sourcedBash('./utils/text.sh', 'lc "HELLO"')
  expect(result).toBe('hello')
})
```

#### Testing Exit Codes (Boolean Functions)

```typescript
it('should return 0 when condition is true', () => {
  const exitCode = bashExitCode('source ./utils/text.sh && starts_with "hello" "hello world"')
  expect(exitCode).toBe(0)
})

it('should return 1 when condition is false', () => {
  const exitCode = bashExitCode('source ./utils/text.sh && starts_with "goodbye" "hello world"')
  expect(exitCode).toBe(1)
})
```

#### Testing with Variables

```typescript
it('should work with variables', () => {
  const result = sourcedBash('./utils/text.sh', `
    my_var="HELLO WORLD"
    lc "$my_var"
  `)
  expect(result).toBe('hello world')
})
```

#### Testing Arrays

```typescript
it('should detect arrays', () => {
  const exitCode = bashExitCode('source ./utils.sh && my_arr=("one" "two") && is_array my_arr')
  expect(exitCode).toBe(0)
})
```

#### Testing Empty Strings

When bash functions use `${param:?message}` syntax, they reject empty strings:

```typescript
it('should error on empty content', () => {
  // Use a variable to pass empty string properly
  const exitCode = bashExitCode('source ./utils/text.sh && empty="" && starts_with "hello" "$empty"')
  expect(exitCode).toBe(127) // Parameter expansion failure
})
```

#### Testing Special Characters

Use bash `$'...'` syntax for escape sequences:

```typescript
it('should handle newlines', () => {
  const exitCode = bashExitCode('source ./utils.sh && has_newline $\'hello\\nworld\'')
  expect(exitCode).toBe(0)
})

it('should trim tabs', () => {
  const result = sourcedBash('./utils/text.sh', "trim $'\\t\\thello\\t\\t'")
  expect(result).toBe('hello')
})
```

#### Testing with Dependencies

When testing utilities that depend on other modules, source `utils.sh` instead of individual files:

```typescript
// ❌ May have missing dependencies
const result = sourcedBash('./utils/typeof.sh', 'typeof "hello"')

// ✅ Loads all dependencies
const result = sourcedBash('./utils.sh', 'typeof "hello"')
```

## Best Practices

### 1. Test File Naming
- Automated tests: `*.test.ts`
- Demo scripts: `demos/*-demo.sh`

### 2. Test Organization
- Group related tests in `describe()` blocks
- Use descriptive test names that explain the behavior
- One assertion per test when possible

### 3. Bash Compatibility
- Tests use bash 5+ from PATH (not `/bin/bash` which is 3.2 on macOS)
- Test helpers set `ROOT` environment variable automatically
- All bash scripts executed with proper error handling

### 4. Testing Strategy
- **Unit tests**: Test individual functions in isolation
- **Integration tests**: Test functions working together
- **Edge cases**: Empty strings, special characters, errors

### 5. Error Testing
- Test both success and failure cases
- Verify correct exit codes (0 for success, non-zero for errors)
- Test error messages when applicable

## Examples

### Text Utilities

```typescript
describe('lc()', () => {
  it('should convert uppercase to lowercase', () => {
    const result = sourcedBash('./utils/text.sh', 'lc "HELLO WORLD"')
    expect(result).toBe('hello world')
  })
})

describe('strip_before()', () => {
  it('should remove text before pattern', () => {
    const result = sourcedBash('./utils/text.sh', 'strip_before "-" "hello-world"')
    expect(result).toBe('world')
  })
})
```

### Type Utilities

```typescript
describe('is_array()', () => {
  it('should return 0 for arrays', () => {
    const exitCode = bashExitCode('source ./utils.sh && my_arr=() && is_array my_arr')
    expect(exitCode).toBe(0)
  })
})

describe('typeof()', () => {
  it('should return "string" for strings', () => {
    const result = sourcedBash('./utils.sh', 'my_var="hello" && typeof my_var')
    expect(result).toBe('string')
  })
})
```

### Color Utilities

```typescript
describe('rgb_text()', () => {
  it('should produce colored output', () => {
    const result = sourcedBash('./utils/color.sh', 'rgb_text "255 0 0" "red text"')
    expect(result).toContain('red text')
    expect(result.length).toBeGreaterThan('red text'.length) // Has ANSI codes
  })
})
```

## Common Issues

### Issue: "command not found"
**Cause**: Utility function depends on other modules not being loaded
**Solution**: Source `utils.sh` instead of individual utility files

### Issue: Leading whitespace trimmed
**Cause**: Using regular `bash()` or `sourcedBash()` which trim output
**Solution**: Use `bashNoTrimStart()` or `sourcedBashNoTrimStart()`

### Issue: Empty string not passed correctly
**Cause**: Bash may not interpret `""` in command strings
**Solution**: Use a variable: `empty="" && my_function "$empty"`

### Issue: Escape sequences not working
**Cause**: Regular quotes don't interpret `\n`, `\t`, etc.
**Solution**: Use bash `$'...'` syntax: `$'\\n'`, `$'\\t'`

### Issue: Exit code 127 instead of expected
**Cause**: Parameter expansion failure (e.g., `${param:?message}`)
**Solution**: This is expected for functions that require non-empty parameters

## Visual Demos

Demo scripts in `tests/demos/` are meant to be executed directly:

```bash
./tests/demos/color-demo.sh
```

These scripts:
- Display visual output for human inspection
- Demonstrate features interactively
- Show real-world usage examples
- Don't use assertions

## CI Integration

Tests run automatically on:
- Push to main branch
- Pull requests
- Manual workflow dispatch

See `.github/workflows/test.yml` for configuration.

## Coverage

Generate coverage reports:

```bash
pnpm test:coverage
```

Coverage reports show:
- Line coverage
- Function coverage
- Branch coverage

## Contributing

When adding new bash utilities:

1. **Write tests first** (TDD approach)
2. **Cover edge cases** (empty strings, special characters, errors)
3. **Test both value and reference** modes when applicable
4. **Add demo script** if visual output is important
5. **Update this README** with new patterns or gotchas

## Resources

- [Vitest Documentation](https://vitest.dev)
- [Bash Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)
- [Bash Exit Codes](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html)
