import { createKindError } from "@yankeeinlondon/kind-error";
import { TestResult } from "./TestResult";
import { TestOptions } from "./TestOptions";
import {  TestAssertion } from "./TestUtil";
import { darkPurpleBacked, green_backed, tangerine_highlighted } from "./format";




;

export type ErrorContext<
    TAssert extends TestAssertion = TestAssertion,
    TParams extends readonly string[] = readonly string[]
> = {
    assertion: TestAssertion,
    source: string;
    fn: string;
    params: TParams;
    result: TestResult<TestOptions, TParams>;
    expected?: string;
}

export const DidNotFail = <
    const TCtx extends ErrorContext
>(
    ctx: TCtx
) => createKindError(
    "DidNotFail", {

        ...ctx
    },
)(`A call to the function '${ctx.fn}' in '${ctx.source}' was supposed to FAIL but returned a successful outcome!`);


export const DidNotPass = <
    TCtx extends ErrorContext
>(
    ctx: TCtx
) => createKindError(
    "DidNotPass", { ...ctx },
)(`A call to the function '${ctx.fn}' in '${ctx.source}' was supposed to FAIL but returned a successful outcome!`);

export const StdOutReturn = <
    TCtx extends ErrorContext
>(
    ctx: TCtx
) => createKindError(
    "Returns/StdOut", { ...ctx },
)(`The expected value of StdOut [${darkPurpleBacked(ctx.expected)}] was not what was expected [${tangerine_highlighted(ctx.result.stdout)}]!`);

export const StdErrReturn = <
    TCtx extends ErrorContext
>(
    ctx: TCtx
) => createKindError(
    "Returns/StdErr", { ...ctx },
)(`The expected value of StdErr was not what was expected!`);


export const StdOutReturnTrimmed = <
    TCtx extends ErrorContext
>(
    ctx: TCtx
) => createKindError(
    "ReturnsTrimmed/StdOut", { ...ctx },
)(`The expected value of StdOut was not what was expected!`);

export const StdErrReturnTrimmed = <
    TCtx extends ErrorContext
>(
    ctx: TCtx
) => createKindError(
    "ReturnsTrimmed/StdErr", { ...ctx },
)(`The expected value of StdErr was not what was expected!`);

