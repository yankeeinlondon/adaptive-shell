# Custom Vitest Matchers for Bash Testing

## Overview

This document explains how custom Vitest matchers have been implemented to extend the testing framework with beautiful error messages powered by `@yankeeinlondon/kind-error`.

## The Problem

The original testing approach used in `deprecated.ts` required verbose assertions:

```typescript
const result = sourcedBash('./utils.sh', 'lc "HELLO"')
expect(result).toBe('hello')

const exitCode = bashExitCode('source ./utils.sh && test_fn')
expect(exitCode).toBe(0)
```

The new `testFramework.ts` provides a cleaner API with built-in assertions that return beautiful KindError objects, but integrating these with Vitest's expect system was the challenge.

## The Solution: Custom Vitest Matchers

Vitest provides `expect.extend()` to add custom matchers. We've created a comprehensive set of matchers that:

1. **Integrate seamlessly with Vitest** - Work with `expect()`, `.not`, and all standard Vitest features
2. **Leverage KindError formatting** - When assertions fail, they display beautifully formatted error messages with context
3. **Provide expressive syntax** - Tests read naturally and clearly express intent

## Usage

### Setup (Already Configured)

The custom matchers are automatically registered via:

- `vitest.config.ts` - Sets `setupFiles: ['./tests/setup.ts']`
- `tests/setup.ts` - Calls `setupBashMatchers()`

No additional setup needed in test files!

### Available Matchers

#### Success/Failure Assertions

```typescript
const api = sourceScript('./utils/text.sh')('lc')('HELLO');

// Assert command succeeded (exit code 0)
expect(api).toBeSuccessful();

// Assert command failed (any non-zero exit code)
expect(api).toFail();

// Assert command failed with specific exit code
expect(api).toFail(42);
```

#### Output Assertions

```typescript
// Assert exact stdout match
expect(api).toReturn('hello');

// Assert trimmed stdout match
expect(api).toReturnTrimmed('hello');

// Assert stdout contains substring
expect(api).toContainInStdOut('ell');

// StdErr equivalents
expect(api).toReturnStdErr('error message');
expect(api).toReturnStdErrTrimmed('error');
expect(api).toContainInStdErr('err');
```

#### Negation Support

All matchers work with `.not`:

```typescript
expect(api).not.toReturn('HELLO'); // stdout should NOT be 'HELLO'
expect(api).not.toFail(); // should succeed
```

## Complete Example

```typescript
import { describe, it, expect } from 'vitest';
import { sourceScript } from './helpers';

describe('text utilities', () => {
  it('should convert to lowercase', () => {
    const api = sourceScript('./utils/text.sh')('lc')('HELLO WORLD');

    expect(api).toBeSuccessful();
    expect(api).toReturn('hello world');
    expect(api).toContainInStdOut('world');
  });

  it('should fail on invalid input', () => {
    const api = sourceScript('./utils.sh')('requires_arg')();

    expect(api).toFail();
    expect(api).toContainInStdErr('missing argument');
  });
});
```

## How It Works

### Matcher Implementation

Each custom matcher:

1. Calls the corresponding `TestApi` method (e.g., `api.success()`, `api.returns()`)
2. If the method returns an Error (KindError), the matcher fails and displays the error message
3. If the method returns `void`, the matcher passes
4. Returns a result object with `pass`, `message`, `actual`, and `expected` properties

Example:

```typescript
toBeSuccessful(api: TestApi<any, any, any, any>) {
  const error = api.success();

  if (error) {
    return {
      pass: false,
      message: () => error.message, // Beautiful KindError formatting!
      actual: api.result.code,
      expected: 0,
    };
  }

  return {
    pass: true,
    message: () => `Expected command to fail but it succeeded`,
    actual: api.result.code,
    expected: 0,
  };
}
```

### Error Message Beauty

When a matcher fails, you get beautifully formatted, **colored** output:

```txt
expect(api).toReturn()

Function: lc in ./utils/text.sh
Expected stdout: "WRONG VALUE"
Received stdout: "hello"

- Expected
+ Received

- WRONG VALUE
+ hello
```

**Terminal Colors:**
- Expected values: **Green**
- Received values: **Red**
- Function names: **Bold**
- Diffs: Green (-) and Red (+)
- Secondary info: Dimmed

This uses Vitest's native color utilities (`utils.printExpected`, `utils.printReceived`, etc.) for consistent, professional error messages that match Vitest's own output style!

## Migration Guide

### Before (deprecated.ts)

```typescript
import { sourcedBash, bashExitCode } from './helpers/bash';

it('should convert to lowercase', () => {
  const result = sourcedBash('./utils.sh', 'lc "HELLO"');
  expect(result).toBe('hello');
});

it('should return success exit code', () => {
  const exitCode = bashExitCode('source ./utils.sh && test_fn');
  expect(exitCode).toBe(0);
});
```

### After (with custom matchers)

```typescript
import { sourceScript } from './helpers';

it('should convert to lowercase', () => {
  const api = sourceScript('./utils.sh')('lc')('HELLO');
  expect(api).toBeSuccessful();
  expect(api).toReturn('hello');
});
```

**Benefits:**

- More expressive and readable
- Better error messages with full context
- Type-safe with full TypeScript support
- Single test API for all assertions

## Alternative Approaches Considered

### 1. ❌ Extending the Result Object

**Approach:** Add methods directly to `api.result`

```typescript
expect(api.result).successful()
```

**Why not:**

- Would require complex proxying of the result object
- Conflicts with Vitest's internal expect machinery
- Less idiomatic Vitest usage

### 2. ❌ Custom Assertion Wrapper

**Approach:** Create a wrapper function

```typescript
assert(api.success())
```

**Why not:**

- Doesn't integrate with Vitest's ecosystem (`.not`, async, etc.)
- Separate assertion mechanism to learn
- Loses Vitest's diff display and reporting features

### 3. ✅ Custom Matchers (Chosen)

**Why this works best:**

- Native Vitest integration
- Works with all Vitest features (`.not`, `.resolves`, etc.)
- Automatic diff display
- Beautiful KindError output
- Type-safe and autocomplete-friendly
- Familiar API for anyone who knows Vitest/Jest

## TypeScript Support

Full TypeScript support is provided via module augmentation in `matchers.ts`:

```typescript
declare module 'vitest' {
  interface Assertion<T = any> {
    toBeSuccessful(): T;
    toFail(exitCode?: number): T;
    toReturn(expected: string): T;
    // ... etc
  }
}
```

This gives you:

- Autocomplete in your IDE
- Type checking for matcher arguments
- Proper typing for chained matchers

## Additional Opportunities

While custom matchers are the best solution, here are other features you might want to explore:

### 1. Snapshot Testing

```typescript
it('should produce expected output', () => {
  const api = sourceScript('./utils.sh')('complex_fn')();
  expect(api.result).toMatchSnapshot();
});
```

### 2. Custom Test Helpers

```typescript
function testBashFunction(source: string, fn: string, ...params: string[]) {
  return sourceScript(source)(fn)(...params);
}

it('quick test', () => {
  const api = testBashFunction('./utils.sh', 'lc', 'HELLO');
  expect(api).toBeSuccessful();
});
```

### 3. Parametric Tests

```typescript
it.each([
  ['HELLO', 'hello'],
  ['WORLD', 'world'],
  ['MiXeD', 'mixed'],
])('lc(%s) should return %s', (input, expected) => {
  const api = sourceScript('./utils.sh')('lc')(input);
  expect(api).toReturn(expected);
});
```

## Files Created/Modified

- ✅ `tests/helpers/matchers.ts` - Custom matcher definitions
- ✅ `tests/setup.ts` - Vitest setup file
- ✅ `tests/matchers-demo.test.ts` - Example usage and demos
- ✅ `vitest.config.ts` - Added setupFiles configuration
- ✅ `tests/helpers/index.ts` - Export matchers
- ✅ `tests/helpers/testFramework.ts` - Fixed bugs in contains() methods and result mapping

## Conclusion

**Yes, extending Vitest with custom assertions is absolutely possible and is the best approach!**

The implementation provides:

- ✅ Beautiful KindError output integrated with Vitest
- ✅ Expressive, readable test syntax
- ✅ Full TypeScript support
- ✅ Native Vitest integration
- ✅ Maintains all Vitest features (negation, async, etc.)

You now have a production-ready testing framework that combines the power of your custom bash test utilities with Vitest's excellent testing experience.
