import { IOType, spawnSync, SpawnSyncOptions } from 'node:child_process';
import { cwd } from 'node:process';
import { TestResult, TestOptions, asArray, SourcedTestUtil } from './index';
import { DidNotFail } from './errors';
import { EmptyObject } from 'inferred-types';



type AsUserOption<
    T extends SpawnSyncOptions,
    O extends IOType | readonly IOType[] = T["stdio"] extends IOType
        ? T["stdio"]
        : T["stdio"] extends IOType[]
        ? T["stdio"]
        : never
> = undefined extends T
    ? TestResult<{
        stdin: "pipe";
        stdout: "pipe";
        stderr: "pipe";
    }>
    : T extends readonly IOType[]
        ? TestResult<{
            stdin:  T[0] | "pipe";
            stdout:  T[1] | "pipe",
            stderr:  T[2] | "pipe"
        }>
    : T extends IOType
        ? TestResult<{
            stdin:  T | "pipe";
            stdout:  T | "pipe";
            stderr:  T | "pipe";
        }>
    : never;


/**
 * **runCommand**
 */
export function runScript<
    TCmd extends string,
    TArgs extends string[],
    TOpt extends SpawnSyncOptions
>(
    cmd: TCmd,
    args: TArgs = [] as string[] as TArgs,
    opts: SpawnSyncOptions = {} as SpawnSyncOptions as TOpt
): TestResult<AsUserOption<TOpt>> {

    const options: SpawnSyncOptions = {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "pipe"],
        ...opts,
    };

    const result = spawnSync(cmd, args, options);

    return {
        exitCode: result.status ?? -1, // unknown failure is set to -1
        stdout: result.stdout as string ?? "",
        stderr: result.stderr as string ?? "",
    } as unknown as TestResult<AsUserOption<TOpt>>;
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
): SourcedTestUtil<TSource, TOpt> {
    return (fn) => {
        const opts: SpawnSyncOptions = {
            encoding: "utf-8",
            stdio: [
                options?.stdin || "pipe",
                options?.stdout || "pipe",
                options?.stderr || "pipe"
            ],
            cwd: options?.cwd || cwd(),
            env: options?.env || {}
        }
        const command = (params: string[]) => [
            "bash",
            [
                "-c",
                ...params.map(i =>
                    i.startsWith("\"") || i.startsWith("'")
                        ? i
                        : `"${i}"`
                )
            ],
            opts
        ] as [string, string[], SpawnSyncOptions]

        return (...params) => {

            // TESTING API
            return {
                success(params) {
                    const p = asArray(params).join(" ");

                },
                failure<
                    T extends undefined | string | readonly string[],
                    C extends undefined | number
                >(
                    params: T = undefined as T,
                    code?: C
                ) {
                    const p = asArray(params).join(" ");
                    const test = runScript(...command(asArray(params)));

                    if(test.code === 0) {
                        return DidNotFail(source, fn, asArray(params), test)
                    }
                },

            }

        }



    }
}

