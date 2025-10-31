import { TestOptions } from "./index";


/**
 * a shell script test result
 */
export type TestResult<T extends TestOptions> = {
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
