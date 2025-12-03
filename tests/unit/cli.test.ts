import { describe, it, expect } from 'vitest'
import { sourceScript } from "../helpers"

describe('CLI utilities', () => {

    describe('cli_json()', () => {
        it('should return 0 when --json is present', () => {
            const api = sourceScript('./utils/cli.sh')('cli_json')('--json');
            expect(api).toBeSuccessful();
        });

        it('should return 0 when --json is mixed with other flags', () => {
            const api = sourceScript('./utils/cli.sh')('cli_json')('--verbose', '--json', '--force');
            expect(api).toBeSuccessful();
        });

        it('should return 0 when --json is among non-switch params', () => {
            const api = sourceScript('./utils/cli.sh')('cli_json')('file.txt', '--json', 'output.txt');
            expect(api).toBeSuccessful();
        });

        it('should return 1 when --json is not present', () => {
            const api = sourceScript('./utils/cli.sh')('cli_json')('--verbose', '--force');
            expect(api).toFail();
        });

        it('should return 1 for empty arguments', () => {
            const api = sourceScript('./utils/cli.sh')('cli_json')();
            expect(api).toFail();
        });

        it('should NOT match partial matches like --json-output', () => {
            const api = sourceScript('./utils/cli.sh')('cli_json')('--json-output');
            expect(api).toFail();
        });

        it('should NOT match --jsonfile', () => {
            const api = sourceScript('./utils/cli.sh')('cli_json')('--jsonfile', '--output');
            expect(api).toFail();
        });

        it('should be case sensitive (--JSON should not match)', () => {
            const api = sourceScript('./utils/cli.sh')('cli_json')('--JSON');
            expect(api).toFail();
        });
    });

    describe('cli_verbose()', () => {
        it('should return 0 when --verbose is present', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('--verbose');
            expect(api).toBeSuccessful();
        });

        it('should return 0 when -v is present', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('-v');
            expect(api).toBeSuccessful();
        });

        it('should return 0 when --verbose is mixed with other flags', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('--json', '--verbose', '--force');
            expect(api).toBeSuccessful();
        });

        it('should return 0 when -v is mixed with other flags', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('--json', '-v', '--force');
            expect(api).toBeSuccessful();
        });

        it('should return 0 when both --verbose and -v are present', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('--verbose', '-v');
            expect(api).toBeSuccessful();
        });

        it('should return 1 when neither flag is present', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('--json', '--force');
            expect(api).toFail();
        });

        it('should return 1 for empty arguments', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')();
            expect(api).toFail();
        });

        it('should NOT match combined flags like -vvv', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('-vvv');
            expect(api).toFail();
        });

        it('should NOT match combined flags like -vf', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('-vf');
            expect(api).toFail();
        });

        it('should NOT match combined flags like -av', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('-av');
            expect(api).toFail();
        });

        it('should NOT match --verbosity', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('--verbosity');
            expect(api).toFail();
        });

        it('should be case sensitive for long flag', () => {
            const api = sourceScript('./utils/cli.sh')('cli_verbose')('--VERBOSE');
            expect(api).toFail();
        });
    });

    describe('cli_force()', () => {
        it('should return 0 when --force is present', () => {
            const api = sourceScript('./utils/cli.sh')('cli_force')('--force');
            expect(api).toBeSuccessful();
        });

        it('should return 0 when --force is mixed with other flags', () => {
            const api = sourceScript('./utils/cli.sh')('cli_force')('--verbose', '--force', '--json');
            expect(api).toBeSuccessful();
        });

        it('should return 0 when --force is among non-switch params', () => {
            const api = sourceScript('./utils/cli.sh')('cli_force')('file.txt', '--force', 'output.txt');
            expect(api).toBeSuccessful();
        });

        it('should return 1 when --force is not present', () => {
            const api = sourceScript('./utils/cli.sh')('cli_force')('--verbose', '--json');
            expect(api).toFail();
        });

        it('should return 1 for empty arguments', () => {
            const api = sourceScript('./utils/cli.sh')('cli_force')();
            expect(api).toFail();
        });

        it('should NOT match partial matches like --force-update', () => {
            const api = sourceScript('./utils/cli.sh')('cli_force')('--force-update');
            expect(api).toFail();
        });

        it('should NOT match --forced', () => {
            const api = sourceScript('./utils/cli.sh')('cli_force')('--forced');
            expect(api).toFail();
        });

        it('should be case sensitive (--FORCE should not match)', () => {
            const api = sourceScript('./utils/cli.sh')('cli_force')('--FORCE');
            expect(api).toFail();
        });
    });

    describe('non_switch_params()', () => {
        it('should return only non-switch params from mixed input', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('file.txt', '--verbose', 'output.txt', '--force');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('file.txt');
            expect(api).toContainInStdOut('output.txt');
            expect(api).not.toContainInStdOut('--verbose');
            expect(api).not.toContainInStdOut('--force');
        });

        it('should return all params when no switches present', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('file.txt', 'output.txt', 'data.json');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('file.txt');
            expect(api).toContainInStdOut('output.txt');
            expect(api).toContainInStdOut('data.json');
        });

        it('should return empty when only switches present', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('--verbose', '--force', '-v');
            expect(api).toBeSuccessful();
            expect(api).toReturn('');
        });

        it('should handle empty input', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')();
            expect(api).toBeSuccessful();
            expect(api).toReturn('');
        });

        it('should filter out long switches starting with --', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('file.txt', '--config', '--output', 'result.txt');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('file.txt');
            expect(api).toContainInStdOut('result.txt');
            expect(api).not.toContainInStdOut('--config');
            expect(api).not.toContainInStdOut('--output');
        });

        it('should filter out short switches starting with -', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('file.txt', '-v', '-f', 'output.txt');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('file.txt');
            expect(api).toContainInStdOut('output.txt');
            expect(api).not.toContainInStdOut('-v');
            expect(api).not.toContainInStdOut('-f');
        });

        it('should preserve arguments with spaces', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('file with spaces.txt', '--verbose');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('file with spaces.txt');
        });

        it('should handle single non-switch param', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('file.txt');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('file.txt');
        });

        it('should handle arguments that look like negative numbers', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('-42', '--verbose', '-3.14');
            expect(api).toBeSuccessful();
            // Negative numbers start with - so they're treated as switches
            // This is expected behavior - if this needs to change, use -- separator
            expect(api).toReturn('');
        });

        it('should output newline-separated values', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('file1.txt', '--verbose', 'file2.txt', 'file3.txt');
            expect(api).toBeSuccessful();
            const output = api.result.stdout;
            const lines = output.split('\n').filter(l => l.length > 0);
            expect(lines).toContain('file1.txt');
            expect(lines).toContain('file2.txt');
            expect(lines).toContain('file3.txt');
        });
    });

    describe('switch_params()', () => {
        it('should return only switch params from mixed input', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('file.txt', '--verbose', 'output.txt', '--force');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('--verbose');
            expect(api).toContainInStdOut('--force');
            expect(api).not.toContainInStdOut('file.txt');
            expect(api).not.toContainInStdOut('output.txt');
        });

        it('should return all params when only switches present', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('--verbose', '--force', '-v');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('--verbose');
            expect(api).toContainInStdOut('--force');
            expect(api).toContainInStdOut('-v');
        });

        it('should return empty when no switches present', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('file.txt', 'output.txt', 'data.json');
            expect(api).toBeSuccessful();
            expect(api).toReturn('');
        });

        it('should handle empty input', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')();
            expect(api).toBeSuccessful();
            expect(api).toReturn('');
        });

        it('should keep long switches starting with --', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('file.txt', '--config', '--output', 'result.txt');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('--config');
            expect(api).toContainInStdOut('--output');
            expect(api).not.toContainInStdOut('file.txt');
            expect(api).not.toContainInStdOut('result.txt');
        });

        it('should keep short switches starting with -', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('file.txt', '-v', '-f', 'output.txt');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('-v');
            expect(api).toContainInStdOut('-f');
            expect(api).not.toContainInStdOut('file.txt');
            expect(api).not.toContainInStdOut('output.txt');
        });

        it('should handle single switch param', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('--verbose');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('--verbose');
        });

        it('should handle combined short flags', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('-vvv', '-abc', 'file.txt');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('-vvv');
            expect(api).toContainInStdOut('-abc');
            expect(api).not.toContainInStdOut('file.txt');
        });

        it('should treat negative numbers as switches (default behavior)', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('-42', 'file.txt', '-3.14');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('-42');
            expect(api).toContainInStdOut('-3.14');
            expect(api).not.toContainInStdOut('file.txt');
        });

        it('should output newline-separated values', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('--verbose', 'file.txt', '--force', '-v');
            expect(api).toBeSuccessful();
            const output = api.result.stdout;
            const lines = output.split('\n').filter(l => l.length > 0);
            expect(lines).toContain('--verbose');
            expect(lines).toContain('--force');
            expect(lines).toContain('-v');
        });

        it('should handle switch with = syntax', () => {
            const api = sourceScript('./utils/cli.sh')('switch_params')('--config=file.conf', 'data.txt');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('--config=file.conf');
            expect(api).not.toContainInStdOut('data.txt');
        });
    });

    describe('Edge cases and integration', () => {
        it('non_switch_params and switch_params should be complementary', () => {
            const input = ['file.txt', '--verbose', 'output.txt', '--force', '-v'];

            const nonSwitches = sourceScript('./utils/cli.sh')('non_switch_params')(...input);
            const switches = sourceScript('./utils/cli.sh')('switch_params')(...input);

            expect(nonSwitches).toBeSuccessful();
            expect(switches).toBeSuccessful();

            // Non-switches should contain files
            expect(nonSwitches).toContainInStdOut('file.txt');
            expect(nonSwitches).toContainInStdOut('output.txt');

            // Switches should contain flags
            expect(switches).toContainInStdOut('--verbose');
            expect(switches).toContainInStdOut('--force');
            expect(switches).toContainInStdOut('-v');

            // They should not overlap
            expect(nonSwitches).not.toContainInStdOut('--verbose');
            expect(switches).not.toContainInStdOut('file.txt');
        });

        it('should handle all functions with same argument set consistently', () => {
            const args = ['file.txt', '--json', '--verbose', 'output.txt', '--force'];

            const hasJson = sourceScript('./utils/cli.sh')('cli_json')(...args);
            const hasVerbose = sourceScript('./utils/cli.sh')('cli_verbose')(...args);
            const hasForce = sourceScript('./utils/cli.sh')('cli_force')(...args);
            const nonSwitches = sourceScript('./utils/cli.sh')('non_switch_params')(...args);
            const switches = sourceScript('./utils/cli.sh')('switch_params')(...args);

            // All detection functions should succeed
            expect(hasJson).toBeSuccessful();
            expect(hasVerbose).toBeSuccessful();
            expect(hasForce).toBeSuccessful();

            // Filter functions should succeed and return correct values
            expect(nonSwitches).toBeSuccessful();
            expect(nonSwitches).toContainInStdOut('file.txt');
            expect(nonSwitches).toContainInStdOut('output.txt');

            expect(switches).toBeSuccessful();
            expect(switches).toContainInStdOut('--json');
            expect(switches).toContainInStdOut('--verbose');
            expect(switches).toContainInStdOut('--force');
        });

        it('should handle special characters in arguments', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('file*.txt', 'dir/file.txt', '--verbose');
            expect(api).toBeSuccessful();
            expect(api).toContainInStdOut('file*.txt');
            expect(api).toContainInStdOut('dir/file.txt');
        });

        it('should handle empty strings as arguments', () => {
            const api = sourceScript('./utils/cli.sh')('non_switch_params')('', '--verbose', '');
            expect(api).toBeSuccessful();
            // Empty strings are still parameters
            const lines = api.result.stdout.split('\n');
            expect(lines.filter(l => l === '').length).toBeGreaterThan(0);
        });
    });
});
