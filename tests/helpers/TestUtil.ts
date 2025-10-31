import {  IsUndefined, Not } from "inferred-types";
import { TestOptions } from "./TestOptions"
import { TestResult } from "./TestResult"
import { ExpandDictionary } from "inferred-types/types";

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
} & (
    <TFn extends string, O extends TestOptions = TestOptions>(fn: TFn, opt?: O) => TestApi<
        TSource,
        TFn,
        IsUndefined<O> extends true
        ? TOpt
        : ExpandDictionary<TOpt & O>
    >
);


export type TestApi<
    TSource extends string,
    TFn extends string,
    TOpt extends TestOptions
> = {
    source: TSource;
    fn: TFn;
    options: TOpt;

    /**
     * tests that the function call returns a _successful_ exit code
     */
    success<T extends readonly string[]>(params?: readonly string[]): TestResult<TOpt>;
    /**
     * tests that the function call returns a _failure_ exit code
     */
    failure<T extends readonly string[], C extends number | undefined>(
        params?: T,
        code?: C & Not<0>
    ): TestResult<TOpt>;

    returns<T extends readonly string[]>(params?: readonly string[]): TestResult<TOpt>;
    stdErrReturns<T extends readonly string[]>(params?: readonly string[]): TestResult<TOpt>;

    returnsTrimmed<T extends readonly string[]>(params?: readonly string[]): TestResult<TOpt>;
    stdErrReturnsTrimmed<T extends readonly string[]>(params?: readonly string[]): TestResult<TOpt>;

    contains<T extends readonly string[]>(params?: readonly string[]): TestResult<TOpt>;
    stdErrContains<T extends readonly string[]>(params?: readonly string[]): TestResult<TOpt>;

}
