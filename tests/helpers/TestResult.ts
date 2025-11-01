import { TestOptions } from "./index";


/**
 * **TestResult**`<T,P>`
 *
 * a shell script test result
 */
export type TestResult<
    T extends TestOptions,
    P extends readonly string[]
> = {
    parameters: P,
    stdout: T["stdout"] extends "ignore"
    ? undefined
    : T["stdout"] extends "pipe"
    ? string
    : undefined | string;
    stderr: T["stderr"] extends "ignore"
    ? undefined
    : T["stderr"] extends "pipe"
    ? string
    : undefined | string;
    code: number;
}
