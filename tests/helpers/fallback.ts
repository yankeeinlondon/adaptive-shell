import { IsUndefined, isUndefined, Narrowable } from "inferred-types";
import { If } from "inferred-types/types";


export function fallback<
    const T extends Narrowable,
    const F extends Narrowable
>(val: T, fallback: F) {
    return (
        isUndefined(val) ? fallback : val
    ) as If<IsUndefined<T>, F, Exclude<T, undefined>>
}
