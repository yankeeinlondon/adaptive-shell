/**
 * Custom Vitest matchers for bash testing framework
 *
 * Extends Vitest's expect API with assertions that integrate
 * with the TestApi and produce beautiful KindError output.
 */

import { expect } from 'vitest';
import type { TestApi } from './TestUtil';

declare module 'vitest' {
  interface Assertion<T = any> {
    /** Assert that the bash command succeeded (exit code 0) */
    toBeSuccessful(): T;

    /** Assert that the bash command failed (exit code !== 0) */
    toFail(exitCode?: number): T;

    /** Assert that stdout exactly matches the expected value */
    toReturn(expected: string): T;

    /** Assert that stdout matches expected value (trimmed) */
    toReturnTrimmed(expected: string): T;

    /** Assert that stderr exactly matches the expected value */
    toReturnStdErr(expected: string): T;

    /** Assert that stderr matches expected value (trimmed) */
    toReturnStdErrTrimmed(expected: string): T;

    /** Assert that stdout contains the expected substring */
    toContainInStdOut(expected: string): T;

    /** Assert that stderr contains the expected substring */
    toContainInStdErr(expected: string): T;
  }

  interface AsymmetricMatchersContaining {
    toBeSuccessful(): any;
    toFail(exitCode?: number): any;
    toReturn(expected: string): any;
    toReturnTrimmed(expected: string): any;
    toReturnStdErr(expected: string): any;
    toReturnStdErrTrimmed(expected: string): any;
    toContainInStdOut(expected: string): any;
    toContainInStdErr(expected: string): any;
  }
}

/**
 * Extends Vitest with custom matchers for TestApi objects
 */
export function setupBashMatchers() {
  expect.extend({
    toBeSuccessful(api: TestApi<any, any, any, any>) {
      const { isNot, utils } = this;
      const error = api.success();

      if (error) {
        const hint = utils.matcherHint('toBeSuccessful', 'api', '', { isNot });
        const received = utils.printReceived(`Exit code: ${api.result.code}`);
        const expected = utils.printExpected('Exit code: 0');

        return {
          pass: false,
          message: () =>
            `${hint}\n\n` +
            `Function: ${utils.BOLD_WEIGHT(api.fn)} in ${api.source}\n` +
            `Expected: ${expected}\n` +
            `Received: ${received}\n` +
            (api.result.stderr ? `\nStderr: ${utils.DIM_COLOR(api.result.stderr)}` : ''),
          actual: api.result.code,
          expected: 0,
        };
      }

      return {
        pass: true,
        message: () => `Expected command to fail but it succeeded with exit code 0`,
        actual: api.result.code,
        expected: isNot ? 'non-zero exit code' : 0,
      };
    },

    toFail(api: TestApi<any, any, any, any>, exitCode?: number) {
      const { isNot, utils } = this;
      const error = api.failure(exitCode as any);

      if (error) {
        const hint = utils.matcherHint('toFail', 'api', exitCode ? String(exitCode) : '', { isNot });
        const received = utils.printReceived(`Exit code: ${api.result.code}`);
        const exp = exitCode ?? 'non-zero exit code';
        const expected = utils.printExpected(`Exit code: ${exp}`);

        return {
          pass: false,
          message: () =>
            `${hint}\n\n` +
            `Function: ${utils.BOLD_WEIGHT(api.fn)} in ${api.source}\n` +
            `Expected: ${expected}\n` +
            `Received: ${received}`,
          actual: api.result.code,
          expected: exp,
        };
      }

      return {
        pass: true,
        message: () =>
          exitCode !== undefined
            ? `Expected command to succeed or fail with different exit code, but it failed with exit code ${exitCode}`
            : `Expected command to succeed but it failed`,
        actual: api.result.code,
        expected: 0,
      };
    },

    toReturn(api: TestApi<any, any, any, any>, expected: string) {
      const { isNot, utils } = this;
      const error = api.returns(expected);

      if (error) {
        const hint = utils.matcherHint('toReturn', 'api', '', { isNot });

        return {
          pass: false,
          message: () =>
            `${hint}\n\n` +
            `Function: ${utils.BOLD_WEIGHT(api.fn)} in ${api.source}\n` +
            `Expected stdout: ${utils.printExpected(expected)}\n` +
            `Received stdout: ${utils.printReceived(api.result.stdout)}`,
          actual: api.result.stdout,
          expected,
        };
      }

      return {
        pass: true,
        message: () => `Expected stdout not to be "${expected}"`,
        actual: api.result.stdout,
        expected,
      };
    },

    toReturnTrimmed(api: TestApi<any, any, any, any>, expected: string) {
      const { isNot, utils } = this;
      const error = api.returnsTrimmed(expected);

      if (error) {
        const hint = utils.matcherHint('toReturnTrimmed', 'api', '', { isNot });
        const trimmed = api.result.stdout ? api.result.stdout.trim() : '';

        return {
          pass: false,
          message: () =>
            `${hint}\n\n` +
            `Function: ${utils.BOLD_WEIGHT(api.fn)} in ${api.source}\n` +
            `Expected (trimmed): ${utils.printExpected(expected)}\n` +
            `Received (trimmed): ${utils.printReceived(trimmed)}`,
          actual: trimmed,
          expected,
        };
      }

      return {
        pass: true,
        message: () => `Expected trimmed stdout not to be "${expected}"`,
        actual: api.result.stdout,
        expected,
      };
    },

    toReturnStdErr(api: TestApi<any, any, any, any>, expected: string) {
      const { isNot, utils } = this;
      const error = api.stdErrReturns(expected);

      if (error) {
        const hint = utils.matcherHint('toReturnStdErr', 'api', '', { isNot });

        return {
          pass: false,
          message: () =>
            `${hint}\n\n` +
            `Function: ${utils.BOLD_WEIGHT(api.fn)} in ${api.source}\n` +
            `Expected stderr: ${utils.printExpected(expected)}\n` +
            `Received stderr: ${utils.printReceived(api.result.stderr)}`,
          actual: api.result.stderr,
          expected,
        };
      }

      return {
        pass: true,
        message: () => `Expected stderr not to be "${expected}"`,
        actual: api.result.stderr,
        expected,
      };
    },

    toReturnStdErrTrimmed(api: TestApi<any, any, any, any>, expected: string) {
      const { isNot, utils } = this;
      const error = api.stdErrReturnsTrimmed(expected);

      if (error) {
        const hint = utils.matcherHint('toReturnStdErrTrimmed', 'api', '', { isNot });
        const trimmed = api.result.stderr ? api.result.stderr.trim() : '';

        return {
          pass: false,
          message: () =>
            `${hint}\n\n` +
            `Function: ${utils.BOLD_WEIGHT(api.fn)} in ${api.source}\n` +
            `Expected stderr (trimmed): ${utils.printExpected(expected)}\n` +
            `Received stderr (trimmed): ${utils.printReceived(trimmed)}`,
          actual: trimmed,
          expected,
        };
      }

      return {
        pass: true,
        message: () => `Expected trimmed stderr not to be "${expected}"`,
        actual: api.result.stderr,
        expected,
      };
    },

    toContainInStdOut(api: TestApi<any, any, any, any>, expected: string) {
      const { isNot, utils } = this;
      const error = api.contains(expected);

      if (error) {
        const hint = utils.matcherHint('toContainInStdOut', 'api', '', { isNot });

        return {
          pass: false,
          message: () =>
            `${hint}\n\n` +
            `Function: ${utils.BOLD_WEIGHT(api.fn)} in ${api.source}\n` +
            `Expected stdout to contain: ${utils.printExpected(expected)}\n` +
            `Received stdout: ${utils.printReceived(api.result.stdout)}`,
          actual: api.result.stdout,
          expected: `string containing "${expected}"`,
        };
      }

      return {
        pass: true,
        message: () => `Expected stdout not to contain "${expected}"`,
        actual: api.result.stdout,
        expected: `string not containing "${expected}"`,
      };
    },

    toContainInStdErr(api: TestApi<any, any, any, any>, expected: string) {
      const { isNot, utils } = this;
      const error = api.stdErrContains(expected);

      if (error) {
        const hint = utils.matcherHint('toContainInStdErr', 'api', '', { isNot });

        return {
          pass: false,
          message: () =>
            `${hint}\n\n` +
            `Function: ${utils.BOLD_WEIGHT(api.fn)} in ${api.source}\n` +
            `Expected stderr to contain: ${utils.printExpected(expected)}\n` +
            `Received stderr: ${utils.printReceived(api.result.stderr)}`,
          actual: api.result.stderr,
          expected: `string containing "${expected}"`,
        };
      }

      return {
        pass: true,
        message: () => `Expected stderr not to contain "${expected}"`,
        actual: api.result.stderr,
        expected: `string not containing "${expected}"`,
      };
    },
  });
}
