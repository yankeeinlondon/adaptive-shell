import { execSync } from 'child_process'
import { isUndefined } from 'inferred-types';
import { TestOptions } from './index';



/**
 * Execute bash script and return stdout
 *
 * @param script - The bash script to execute
 * @param options - Optional configuration (env vars, cwd)
 * @returns The stdout output, trimmed
 */
export function bash(script: string, options?: TestOptions): string {
    const stdin = isUndefined(options?.stdin)
        ? "pipe"
        : options.stdin
    const stdout = isUndefined(options?.stdout)
        ? "pipe"
        : options.stdin
    const stderr = isUndefined(options?.stderr)
        ? "pipe"
        : options.stdin
    try {
        return execSync(script, {
            shell: 'bash',  // Use bash from PATH (not /bin/bash which is 3.2 on macOS)
            encoding: 'utf-8',
            cwd: options?.cwd || process.cwd(),
            stdio: [stdin, stdout, stderr],
            env: {
                ...process.env,
                ROOT: process.cwd(),
                ...options?.env
            }
        }).trim()
    } catch (error: any) {
        // If there's stdout output, return it even if exit code was non-zero
        // This handles bash functions that produce output but return non-zero exit codes
        if (error.stdout) {
            return error.stdout.toString().trim()
        }
        // Only throw if there was no stdout output
        throw error
    }
}


/** execute a bash script test */
export function runTest(script: string, options?: TestOptions) {
    try {
        bash(script, options)
        return 0
    } catch (error: any) {
        return error.status || 1
    }

}

/**
 * Source a bash file and execute script
 *
 * @param source - The bash file to source (relative or absolute path)
 * @param fn - The script to execute after sourcing
 * @param options - Optional configuration (env vars, cwd)
 * @returns The stdout output, trimmed
 */
export function sourcedBash(source: string, fn: string, options?: TestOptions): string {
    return bash(`source ${source} && ${fn}`, options)
}

/**
 * Execute bash and return exit code
 *
 * @param script - The bash script to execute
 * @param options - Optional configuration (env vars, cwd)
 * @returns The exit code (0 for success, non-zero for failure)
 */
export function bashExitCode(script: string, options?: TestOptions): number {
    try {
        bash(script, options)
        return 0
    } catch (error: any) {
        return error.status || 1
    }
}

/**
 * Execute bash and return both stdout and stderr combined
 *
 * @param script - The bash script to execute
 * @param options - Optional configuration (env vars, cwd)
 * @returns Combined stdout and stderr output, trimmed
 */
export function bashWithStderr(script: string, options?: TestOptions): string {
    try {
        // Redirect stderr to stdout in the bash command itself
        const result = execSync(`${script} 2>&1`, {
            shell: 'bash',
            encoding: 'utf-8',
            cwd: options?.cwd || process.cwd(),
            env: {
                ...process.env,
                ROOT: process.cwd(),
                ...options?.env
            }
        })
        return result.trim()
    } catch (error: any) {
        // Return combined output even on error
        if (error.stdout) {
            return error.stdout.toString().trim()
        }
        throw error
    }
}

/**
 * Source a bash file and execute script, capturing both stdout and stderr
 *
 * @param file - The bash file to source (relative or absolute path)
 * @param script - The script to execute after sourcing
 * @param options - Optional configuration (env vars, cwd)
 * @returns Combined stdout and stderr output, trimmed
 */
export function sourcedBashWithStderr(file: string, script: string, options?: TestOptions): string {
    return bashWithStderr(`source ${file} && ${script}`, options)
}

/**
 * Execute bash script and return stdout with only trailing whitespace trimmed
 * (preserves leading whitespace, useful for testing indentation)
 *
 * @param script - The bash script to execute
 * @param options - Optional configuration (env vars, cwd)
 * @returns The stdout output with only trailing whitespace removed
 */
export function bashNoTrimStart(script: string, options?: TestOptions): string {
    try {
        const result = execSync(script, {
            shell: 'bash',
            encoding: 'utf-8',
            cwd: options?.cwd || process.cwd(),
            env: {
                ...process.env,
                ROOT: process.cwd(),
                ...options?.env
            }
        })
        // Only trim trailing whitespace (trimEnd), preserve leading whitespace
        return result.trimEnd()
    } catch (error: any) {
        if (error.stdout) {
            return error.stdout.toString().trimEnd()
        }
        throw error
    }
}

/**
 * Source a bash file and execute script, preserving leading whitespace
 *
 * @param file - The bash file to source (relative or absolute path)
 * @param script - The script to execute after sourcing
 * @param options - Optional configuration (env vars, cwd)
 * @returns The stdout output with only trailing whitespace removed
 */
export function sourcedBashNoTrimStart(file: string, script: string, options?: TestOptions): string {
    return bashNoTrimStart(`source ${file} && ${script}`, options)
}
