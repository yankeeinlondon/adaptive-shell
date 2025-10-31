import { createKindError } from "@yankeeinlondon/kind-error";


export const DidNotFail = <
    TSource extends string,
    TFn extends string,
    TParams extends readonly string[]
>(
    source: TSource,
    fn: TFn,
    params: TParams,
    result:
) => createKindError(
    "DidNotFail", { library: "adaptive-scripts", source, fn, params, result },
)(`A call to the function '${fn}' in '${source}' was supposed to FAIL but returned a successful outcome!`);


export const DidNotPass = <
    TSource extends string,
    TFn extends string,
    TParams extends readonly string[]
>(
    source: TSource,
    fn: TFn,
    params: TParams,
    result:
) => createKindError(
    "DidNotPass", { library: "adaptive-scripts", source, fn, params, result },
)(`A call to the function '${fn}' in '${source}' was supposed to FAIL but returned a successful outcome!`);

