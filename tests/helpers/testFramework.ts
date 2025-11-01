import { isString, isStringArray, isUndefined, contains,  Never, createFnWithProps } from 'inferred-types';
import type { EmptyObject, EnsureLeading, OnlyFn, } from "inferred-types/types"
import { IOType, spawnSync, SpawnSyncOptions, SpawnSyncReturns } from 'node:child_process';
import { cwd } from 'node:process';
import { TestResult, TestOptions, asArray, SourcedTestUtil, TestUtil, TestApi, ToSpawnOptions, AsCommand } from './index';
import { DidNotFail, DidNotPass, StdErrReturn, StdOutReturn, StdOutReturnTrimmed } from './errors';
import { fallback } from './fallback';


function toSpawnOption<T extends TestOptions>(opt: T): ToSpawnOptions<T> & SpawnSyncOptions {
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
        exitCode: result.status ?? -1, // unknown failure is set to -1
        stdout: result.stdout as string ?? "",
        stderr: result.stderr as string ?? "",
    }
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
) => [
    "bash",
    [
        "-c",
        "source",
        source,
        "&&",
        "bash",
        "-e",
        fn,
        ...params.map(i =>
            i.startsWith("\"") || i.startsWith("'")
                ? i
                : `"${i}"`
        )
    ],
    toSpawnOption(opts)

] as AsCommand<TSource,TFn,TParams,TOpt>



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
    const result = {
        ...runScript(...args),
        params,
        options
    } as unknown as TestResult<TOpt,TParams>;


    const api: TestApi<TSource,TFn,TParams,TOpt> = {
        source,
        fn,
        params,
        options,
        command: command(source,fn,params,options),


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
            if(result.stdout !== expected) {
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
            if(result.stdout !== expected) {
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
            if(result.stdout !== expected) {
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
            if(result.stdout !== expected) {
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
            if(isString(result.stdout) && contains(result.stdout, expected) ) {
                return StdErrReturn({
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
            if(isString(result.stdout) && contains(result.stdout, expected) ) {
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
    const kv = {
        source,
        options
    } as { source: TSource, options: TOpt };

    const fn = <const TFn extends string>(fn: TFn) => {
        return addParameters(source,fn,options) as TestUtil<TSource,TFn,TOpt>;
    }

    return createFnWithProps(fn,kv) as SourcedTestUtil<TSource, TOpt>;
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
    options = {} as EmptyObject & TestOptions as TOpt
) {
    return addFunctionName(source, options);
}

