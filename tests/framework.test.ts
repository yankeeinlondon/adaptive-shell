import { describe, it, expect } from 'vitest'
import {  sourceScript, SourcedTestUtil } from './helpers'
import type { TestOptions } from './helpers';
import { AssertEqual, AssertExtends, Expect } from 'inferred-types';

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

        type cases = [
            Expect<AssertEqual<Sourced, SourcedTestUtil<"text.sh", TestOptions>>>,
            Expect<AssertEqual<WithFnName, TestUtil<"text.sh", "do_something", TestOptions>>>,

        ];
    });



})
