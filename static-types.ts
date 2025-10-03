type BashFunction = {
    /** the function's name **/
    name: string;
    /** the (optional) arguments defined in the comment block */
    arguments: string;
    /** the (optional) comment block/lines which precede a function definition */
    description: string;
    /** path to the file */
    file: string;
    /** the starting line for the function and comment block */
    startBlock: number;
    /** the starting line for the function */
    start: number;
    /** the ending line for the function */
    end: number
}

type FunctionSummary = {
    functions: BashFunction[];
    /** an array of function names which have MORE than one definition */
    duplicates: string[]
}

