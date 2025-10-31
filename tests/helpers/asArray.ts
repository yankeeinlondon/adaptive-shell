import { isArray } from "inferred-types";
import { Narrowable } from "inferred-types/types";


export function asArray<const T extends Narrowable | readonly Narrowable[]>(val: T): T extends unknown[] ? T & string[] : [T] & string[] {
    return (
        isArray(val)
        ? val
        : [val]
    ) as T extends unknown[] ? T & string[] : [T] & string[]
}
