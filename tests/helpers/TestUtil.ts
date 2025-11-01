import type {  As,  Join, Not, StartsWith, StringKeys } from "inferred-types/types";
import { SpawnSyncOptions } from "node:child_process";
import { TestOptions, ToSpawnOptions } from "./TestOptions"
import { TestResult } from "./TestResult"

export type AddFunctionToTestUtil<
    TSource extends string,
    TOpt extends TestOptions
> = <const TFn extends string>(fn: TFn) => TestUtil<
    TSource,
    TFn,
    TOpt
>;

/**
 * A test utility which has been provided the file to **source**
 * as well as the initial _options_ to use in the call but is
 * yet to provide the **function** and **parameters**.
 */
export type SourcedTestUtil<
    TSource extends string,
    TOpt extends TestOptions
> = {
    source: TSource;
    options: TOpt;
} & AddFunctionToTestUtil<TSource,TOpt>
;


export type AddParametersToTestUtil<
    TSource extends string,
    TFn extends string,
    TOpt extends TestOptions
> = <TParams extends readonly string[]>(...params: TParams) => TestApi<
    TSource,
    TFn,
    TParams,
    TOpt
>;


/**
 * A test utility with configured _source file_, _function name_, and options.
 */
export type TestUtil<
    TSource extends string,
    TFn extends string,
    TOpt extends TestOptions
> = {
    source: TSource;
    fn: TFn;
    options: TOpt;
} & AddParametersToTestUtil<TSource,TFn,TOpt>;


export type Quoted<T extends readonly string[]> = As<{
    [K in keyof T]: StartsWith<T[K], "'" | "\""> extends true
        ? T[K]
        : `"${T[K]}"`
}, readonly string[]>

export type AsCommand<
    TSource extends string,
    TFn extends string,
    TParams extends readonly string[],
    TOpt extends TestOptions
> = [
    "bash",
    [
        "-e",
        "source",
        "-o",
        "pipefail",
        "-c",
        `source ${TSource} && ${TFn} ${Join<TParams, " ">}`
    ],
    ToSpawnOptions<TOpt> & SpawnSyncOptions
];

export type TestApi<
    TSource extends string,
    TFn extends string,
    TParams extends readonly string[],
    TOpt extends TestOptions
> = {
    source: TSource;
    fn: TFn;
    params: TParams;
    options: TOpt;
    result: TestResult<TOpt,TParams>,
    command: AsCommand<TSource,TFn,TParams,TOpt>

    /**
     * tests that the function call returns a _successful_ exit code
     */
    success(): void | Error;
    /**
     * tests that the function call returns a _failure_ exit code
     */
    failure<C extends number | undefined>(
        code?: C & Not<0>
    ): void | Error;

    /**
     * tests that **StdOut** exactly equals the passed in _expected_ value
     */
    returns<
        E extends string
    >(expected: E): void | Error;
    stdErrReturns<E extends string>(expect: E): void | Error;

    returnsTrimmed<E extends string>(expect: E): void | Error;
    stdErrReturnsTrimmed<E extends string>(expect: E): void | Error;

    contains<E extends string>(expect: E): void | Error;
    stdErrContains<E extends string>(expect: E): void | Error;

}

/**
 * the name of the test assertion used for a given test
 */
export type TestAssertion = Exclude<
    StringKeys<TestApi<any,any,any,any>>[number],
    "source" | "fn" | "params" | "options"
>
