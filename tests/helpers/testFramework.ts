import { isString, contains,  createFnWithProps, ensureLeading, startsWith, stripTrailing } from 'inferred-types';
import type { EmptyObject } from "inferred-types/types"
import { IOType, spawnSync, SpawnSyncOptions, SpawnSyncReturns } from 'node:child_process';
import { cwd } from 'node:process';
import { TestResult, TestOptions, asArray, SourcedTestUtil, TestUtil, TestApi, ToSpawnOptions, AsCommand, Quoted } from './index';
import { DidNotFail, DidNotPass, StdErrReturn, StdOutReturn, StdOutReturnTrimmed } from './errors';
import { fallback } from './fallback';
import { TEST_ENV } from './constants';

/**
 * converts a `TestOptions` hash into a `SpawnSyncOptions` hash.
 */
export function toSpawnOption<T extends TestOptions>(opt: T): ToSpawnOptions<T> & SpawnSyncOptions {
    const t = fallback(opt.stdin, "pipe");
    return {
        encoding: "utf-8",
        cwd: fallback(opt.cwd, cwd()),
        env: fallback(opt.env, {}),
        stdio: [
            fallback(opt.stdin, "pipe"),
            fallback(opt.stdout, "pipe"),
            fallback(opt.stderr, "pipe"),
        ] satisfies [IOType, IOType, IOType]
    } satisfies SpawnSyncOptions
}

/**
 * **runScript**`(source, fn, params, )
 */
export function runScript<
    TCmd extends string,
    TParams extends readonly string[],
    TOpt extends SpawnSyncOptions
>(
    cmd: TCmd,
    params: TParams,
    opts: TOpt = {} as EmptyObject as TOpt
) {
    const result = spawnSync(cmd, params,opts) as SpawnSyncReturns<string>;

    return {
        code: result.status ?? -1, // unknown failure is set to -1
        stdout: stripTrailing(result.stdout as string ?? "", "\n"),
        stderr: stripTrailing(result.stderr as string ?? "", "\n"),
    }
}



function quoteParameters<T extends readonly string[]>(params: T): Quoted<T> {
    return (
        [...params]
            .map(i => {
                // If already quoted, return as-is (using native .startsWith())
                if (i.startsWith("'") || i.startsWith("\"")) {
                    return i;
                }
                // Otherwise, wrap in double quotes and escape any internal quotes
                return `"${i.replace(/"/g, '\\"')}"`;
            })
         ) as unknown as Quoted<T>
}

const command = <
    TSource extends string,
    TFn extends string,
    TParams extends readonly string[],
    TOpt extends TestOptions
>(
    source: TSource,
    fn: TFn,
    params: TParams,
    opts: TOpt
) => {
    const p = quoteParameters(params);

    return [
        "bash",
        [
            "-e",
            "-o",
            "pipefail",
            "-c",
            `source ${source} && ${fn} ${p.join(" ")}`
        ],
        toSpawnOption(opts)
    ] as unknown as AsCommand<TSource,TFn,TParams,TOpt>
};


function createApiSurface<
    TSource extends string,
    TFn extends string,
    TParams extends readonly string[],
    TOpt extends TestOptions
>(
    source: TSource,
    fn: TFn,
    params: TParams,
    options: TOpt
) {
    /** the result of executing the command */
    const args = command(source,fn,params,options);
    const scriptResult = runScript(...args);
    const result = {
        code: scriptResult.code,
        stdout: scriptResult.stdout,
        stderr: scriptResult.stderr,
        parameters: params,
    } as unknown as TestResult<TOpt,TParams>;


    const api: TestApi<TSource,TFn,TParams,TOpt> = {
        source,
        fn,
        params,
        options,
        result,
        command: command(source,fn,params,options) as readonly unknown[] as AsCommand<TSource,TFn,TParams,TOpt>,


        success() {
            const p = asArray(params).join(" ");

            if(result.code !== 0) {
                return DidNotPass({
                    assertion: "success",
                    source,
                    fn,
                    params: asArray(params),
                    result
                })
            }
        },
        failure(code = undefined) {
            const p = asArray(params)

            if(result.code === 0 && (code === undefined || code === result.code)) {
                return DidNotFail({
                    assertion: "failure",
                    source,
                    fn,
                    params: asArray(params),
                    result
                })
            }
        },
        returns(expected) {
            if(result.stdout !== (expected as string)) {
                return StdOutReturn({
                    assertion: "returns",
                    source,
                    fn,
                    params: asArray(params),
                    result,
                    expected
                });
            }
        },

        returnsTrimmed(expected) {
            const trimmedStdout = result.stdout.trim();
            const trimmedExpected = (expected as string).trim();
            if(trimmedStdout !== trimmedExpected) {
                return StdOutReturnTrimmed({
                    assertion: "returnsTrimmed",
                    source,
                    fn,
                    params: asArray(params),
                    result,
                    expected
                });
            }
        },

        stdErrReturns(expected) {
            if(result.stderr !== (expected as string)) {
                return StdErrReturn({
                    assertion: "stdErrReturns",
                    source,
                    fn,
                    params: asArray(params),
                    result,
                    expected
                });
            }
        },

        stdErrReturnsTrimmed(expected) {
            const trimmedStderr = result.stderr.trim();
            const trimmedExpected = (expected as string).trim();
            if(trimmedStderr !== trimmedExpected) {
                return StdErrReturn({
                    assertion: "stdErrReturnsTrimmed",
                    source,
                    fn,
                    params: asArray(params),
                    result,
                    expected
                });
            }
        },

        contains(expected) {
            if(isString(result.stdout) && !contains(result.stdout, expected) ) {
                return StdOutReturn({
                    assertion: "contains",
                    source,
                    fn,
                    params: asArray(params),
                    result,
                    expected
                });
            }
        },

        stdErrContains(expected) {
            if(isString(result.stderr) && !contains(result.stderr, expected) ) {
                return StdErrReturn({
                    assertion: "stdErrContains",
                    source,
                    fn,
                    params: asArray(params),
                    result,
                    expected
                });
            }
        }


    }


    return api;
}

function addParameters<
    const TSource extends string,
    const TFn extends string,
    const TOpt extends TestOptions
>(
    source: TSource,
    fn: TFn,
    options: TOpt
) {
    const kv = {
        source,
        fn,
        options
    } as { source: TSource, fn: TFn, options: TOpt }

    const func = <TParams extends readonly string[]>(...params: TParams) => {
        return createApiSurface(source,fn,params,options);
    }

    return createFnWithProps(func, kv) as TestUtil<
        TSource,
        TFn,
        TOpt
    > as TestUtil<TSource,TFn,TOpt>;
}

function addFunctionName<TSource extends string, TOpt extends TestOptions>(
    source: TSource,
    options: TOpt
): SourcedTestUtil<TSource, TOpt> {

    const fn = <const TFn extends string>(fn: TFn) => {
        return addParameters(source,fn,options) as unknown as TestUtil<TSource,TFn,TOpt>;
    }

    fn["source"] = source;
    fn["options"] = options;

    return fn as unknown as SourcedTestUtil<TSource, TOpt>;
}

/**
 * **sourceScript**`(sourceFile, [options]) -> (fn) -> API Surface`
 *
 * A higher order function which:
 *
 * - on first call which _targets_ a bash shell script to "source"
 *     - on first call it does some very basic validation
 *         - execute file (piping STDIN and STDOUT to /dev/null) and
 *           validating that the sourced file exists and that it doesn't return
 *           an error code when executed
 *       aka, it can execute the file and not get an error)
 * - the second call takes a _function_ which will be the primary focus of the
 *   unit testing.
 * - we now get a strongly typed testing API to use for testing.
 */
export function sourceScript<
    const TSource extends string,
    const TOpt extends TestOptions
>(
    source: TSource,
    options = { env: process.env } as EmptyObject & TestOptions as TOpt
) {
    return addFunctionName(
        ensureLeading(source, "./"),
        options
    );
}

