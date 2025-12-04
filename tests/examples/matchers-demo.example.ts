/**
 * Demonstration of Custom Bash Testing Matchers
 *
 * This file shows how to use the new custom Vitest matchers
 * with the sourceScript testing framework.
 */

import { describe, it, expect } from 'vitest';
import { sourceScript } from "../helpers";

describe('Custom Bash Matchers Demo', () => {
  describe('Success/Failure Assertions', () => {
    it('should assert command succeeds', () => {
      const api = sourceScript('./utils/text.sh')('lc')('HELLO');

      // New syntax - clean and expressive!
      expect(api).toBeSuccessful();
    });

    it('should assert command fails', () => {
      const api = sourceScript('./utils.sh')('contains')('needle', 'haystack without it');

      expect(api).toFail();
    });

    it('should assert specific exit code', () => {
      // This would test a command that exits with code 42
      // const api = sourceScript('./utils.sh')('some_fn')();
      // expect(api).toFail(42);
    });
  });

  describe('Output Assertions', () => {
    it('should assert exact stdout match', () => {
      const api = sourceScript('./utils/text.sh')('lc')('HELLO WORLD');

      expect(api).toReturn('hello world');
    });

    it('should assert trimmed stdout match', () => {
      const api = sourceScript('./utils/text.sh')('lc')('  HELLO  ');

      expect(api).toReturnTrimmed('hello');
    });

    it('should assert stdout contains substring', () => {
      const api = sourceScript('./utils/text.sh')('lc')('HELLO WORLD');

      expect(api).toContainInStdOut('world');
    });
  });

  describe('Comparison: Old vs New Syntax', () => {
    it('OLD: using result directly', () => {
      const api = sourceScript('./utils/text.sh')('lc')('HELLO');

      // Old way - verbose
      expect(api.result.code).toBe(0);
      expect(api.result.stdout).toBe('hello');
    });

    it('NEW: using custom matchers', () => {
      const api = sourceScript('./utils/text.sh')('lc')('HELLO');

      // New way - expressive and provides beautiful error messages via KindError
      expect(api).toBeSuccessful();
      expect(api).toReturn('hello');
    });
  });

  describe('Error Messages', () => {
    it('demonstrates beautiful error output when assertion fails', () => {
      const api = sourceScript('./utils/text.sh')('lc')('HELLO');

      // Uncomment to see the beautiful KindError output:
      // expect(api).toReturn('WRONG VALUE');

      // When this fails, you'll see:
      // - Colored, formatted error message
      // - Source file and function being tested
      // - Expected vs actual values
      // - Full context from the TestApi
    });
  });

  describe('Negation Support', () => {
    it('should support .not modifier', () => {
      const api = sourceScript('./utils/text.sh')('lc')('HELLO');

      expect(api).not.toReturn('HELLO'); // Should be lowercase
      expect(api).not.toFail();
    });
  });
});
