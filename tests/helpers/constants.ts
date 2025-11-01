import { narrow } from "inferred-types";

export const STDIO_OPTIONS = narrow({
    /** Default behavior: pipe all streams so they can be captured. */
    PIPE: "pipe",
    /** Share the parent's stdio (interactive). */
    INHERIT: "inherit",
    /** Ignore/discard all streams. */
    IGNORE: "ignore",
    /** Create an IPC channel (used only with fork/spawn). */
    IPC: "ipc",
    /** Windows-only: open handle for asynchronous (overlapped) I/O. */
    OVERLAPPED: "overlapped",
});

export const TEST_ENV = {
    HOME: process.env.HOME,
    USER: process.env.USER,
    COLORTERM: process.env.COLORTERM,
    LANG: process.env.LANG,
    PATH: process.env.PATH
}
