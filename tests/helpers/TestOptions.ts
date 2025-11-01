import { EmptyString, Fallback } from "inferred-types";
import { IOType } from "node:child_process";

/**
 * options provided to test functions to manipulate the `spawnSync`
 * call.
 */
export type TestOptions = {
    env?: Record<string, string>
    cwd?: string,
    /**
     * how you want the tests to handle STDIN (by default it is `pipe`)
     */
    stdin?: IOType,
    /**
     * how you want the tests to handle STDOUT (by default it is `pipe`)
     */
    stdout?: IOType,
    /**
     * how you want the tests to handle STDERR (by default it is `pipe`)
     */
    stderr?: IOType,
}


export type ToSpawnOptions<T extends TestOptions> = {
    encoding: "utf-8";
    cwd: Fallback<T["cwd"], string>;
    env: Fallback<T["env"], EmptyString>;
    stdio: [
        T["stdin"] | "pipe",
        T["stdout"] | "pipe",
        T["stderr"] | "pipe",
    ]
}
