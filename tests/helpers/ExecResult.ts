

/**
 * **TestResult**
 */
export type TestResult = {
    /** Exit code (0 for success, non-zero for failure, -1 if unknown) */
    exitCode: number;
    /** the STDOUT output */
    stdout: string;
    /** the STDIN output */
    stderr: string;
}
