import { ensureLeading, isString, isUndefined, narrow, stripLeading } from "inferred-types";
import type { EnsureLeading } from "inferred-types/types";
import { resolve } from "pathe";
import { exit } from "node:process";

export const CONSOLE_LINK_PREAMBLE = narrow(`\x1B]8;;`);
export const CONSOLE_LINK_DELIMITER = narrow(`\x1B\\`);
export const CONSOLE_LINK_CLOSURE = narrow(`\x1B]8;;\x1B\\`);

/**
 * **link**`(text, link)`
 *
 * Prints a link to the terminal using a relatively new
 * [standard](https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda) for making pretty links.
 *
 */
function link<
    T extends string,
    L extends string
>(text: T, link: L): `${typeof CONSOLE_LINK_PREAMBLE}${L}${typeof CONSOLE_LINK_DELIMITER}${T}${typeof CONSOLE_LINK_CLOSURE}` {
    return `${CONSOLE_LINK_PREAMBLE}${link}${CONSOLE_LINK_DELIMITER}${text}${CONSOLE_LINK_CLOSURE}`;
}

type FileLinkRtn<
    T,
    P
> = undefined extends P
    ? T
    : `\x1B]8;;file://${string}\x1B\\${T}\x1B]8;;\x1B\\`;

/**
 * **fileLink**`(text, path)`
 *
 * Provides a console-friendly way (_OSC 8 escape codes_) to display text and
 * have that text be linked to a valid file in the filesystem.
 *
 * **Note:**
 *
 * - if _undefined_ is passed for the path then the text will be returned
 * "as is" (also meaning it will NOT be clickable)
 * - if the filepath is provide but NOT valid then a `InvalidFilePath` error
 * will be thrown.
 */
export function fileLink<
    T extends string,
    P extends string | undefined = undefined
>(
    text: T,
    path?: P
): FileLinkRtn<T, P> {
    if (isUndefined(path)) {
        return text as FileLinkRtn<T, P>;
    }

    // Strip file:// protocol if present
    const cleanPath = stripLeading(path, "file://") as string;

    // Extract line number if present (e.g., "file.ts:123" → ["file.ts", "123"])
    const lineNumberMatch = cleanPath.match(/^(.+):(\d+)$/);
    const pathWithoutLine = lineNumberMatch ? lineNumberMatch[1] : cleanPath;
    const lineNumber = lineNumberMatch ? lineNumberMatch[2] : undefined;

    // Try path as-is first (handles truly absolute paths)
    let fullPath = resolve(pathWithoutLine);

    // If doesn't exist and starts with "/", try stripping it (project-relative path)
    if (!existsSync(fullPath) && pathWithoutLine.startsWith("/")) {
        fullPath = resolve(stripLeading(pathWithoutLine, "/"));
    }

    if (existsSync(fullPath)) {
        const linkUrl = lineNumber ? `file://${fullPath}:${lineNumber}` : `file://${fullPath}`;
        return link(text, linkUrl) as FileLinkRtn<T, P>;
    }
    else {
        console.log(`Call to fileLink(text, path) is invalid because the FULL PATH (which is required for a valid OSC8 terminal link) does not point to a valid path!`)
        exit
    }
}

type UrlLinkReturn<
    T extends string,
    U extends string | undefined
> = U extends string
    ? `${typeof CONSOLE_LINK_PREAMBLE}${EnsureLeading<U, "https://">}${typeof CONSOLE_LINK_DELIMITER}${T}${typeof CONSOLE_LINK_CLOSURE}`
    : `${typeof CONSOLE_LINK_PREAMBLE}${EnsureLeading<T, "https://">}${typeof CONSOLE_LINK_DELIMITER}${T}${typeof CONSOLE_LINK_CLOSURE}`;

/**
 * **urlLink**`(text, path)`
 *
 * Provides a console-friendly way (_OSC 8 escape codes_) to display text
 * and have that text be linked to a URL.
 *
 * - if no URL is stated then the text will be assumed to be a URL
 *
 * **Related:** `
 */
export function urlLink<T extends string, U extends string | undefined = undefined>(
    text: T,
    url?: U
): UrlLinkReturn<T, U> {
    const finalizedUrl = (
        isString(url)
            ? ensureLeading(url, "https://") as any
            : ensureLeading(text, "https://") as any
    ) as U extends string
        ? EnsureLeading<U, "https://">
        : EnsureLeading<T, "https://">;

    return link(text, finalizedUrl) as UrlLinkReturn<T, U>;
}
