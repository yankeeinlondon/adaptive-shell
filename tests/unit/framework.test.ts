import { describe, it, expect } from 'vitest'
import { AssertEqual, Expect } from 'inferred-types';
import {  sourceScript, SourcedTestUtil } from "../helpers"
import type { TestApi, TestOptions, TestUtil } from "../helpers";

const mod = sourceScript("test.sh");


describe("Test Utility Usage", () => {


    it("step-by-step", () => {

        const sourced = sourceScript("text.sh"); // sourced file
        const withFnName = sourced("do_something"); // add fn
        const api = withFnName("foo", "bar"); // add parameters

        expect(api.params).toEqual(["foo","bar"]);

        /** API Surface */
        expect(typeof api.success).toBe("function")
        expect(typeof api.failure).toBe("function")
        expect(typeof api.returns).toBe("function")
        expect(typeof api.stdErrReturns).toBe("function")
        expect(typeof api.returnsTrimmed).toBe("function")
        expect(typeof api.stdErrReturnsTrimmed).toBe("function")
        expect(typeof api.contains).toBe("function")
        expect(typeof api.stdErrContains).toBe("function")

        type Sourced = typeof sourced;
        type WithFnName = typeof withFnName;
        type Api = typeof api;

        type cases = [
            Expect<AssertEqual<Sourced, SourcedTestUtil<"./text.sh", TestOptions>>>,
            Expect<AssertEqual<WithFnName, TestUtil<"./text.sh", "do_something", TestOptions>>>,
            Expect<AssertEqual<Api, TestApi<"./text.sh", "do_something", ["foo","bar"], TestOptions>>>
        ];
    });


    it("example test", () => {
        const result = sourceScript("utils/text.sh")("lc")("HELLO WORLD");

        expect(result).toReturn("hello world");
    });




})
