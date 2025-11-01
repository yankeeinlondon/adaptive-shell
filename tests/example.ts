import { StdOutReturn } from "./helpers/errors";


const e = StdOutReturn({assertion: "returns", source: "./utils/text.sh",fn: "do_it", expected: "something",  params: [], result: {code: 1, stderr: "", stdout:"nothing", parameters: []} });

console.log(e);
