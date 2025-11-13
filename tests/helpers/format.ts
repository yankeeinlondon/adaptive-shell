import { RGB, HexColor, stripBefore, trim, narrow, StringKeys, Fallback } from "inferred-types";

const FG_START = narrow("\x1b[38;2;");
const FG_END = "m" as const;
const BG_START = narrow("\x1b[48;2;");
const BG_END = "m" as const;

type ForegroundColor<R extends number, G extends number, B extends number> = {
    kind: "foreground-color";
    rgb: {
        r: R;
        g: G;
        b: B;
    };
}

type BackgroundColor<R extends number, G extends number, B extends number> = {
    kind: "background-color";
    rgb: {
        r: R;
        g: G;
        b: B;
    };
}

/**
 * **createForegroundColor**`(color) -> ForegroundColor`
 *
 * Create a **foreground** color from a RGB object or a Hex color value.
 */
export function createForegroundColor<T extends RGB>(color: T) {
    return {
        kind: "foreground-color",
        rgb: color
    } as ForegroundColor<T["r"], T["g"], T["b"]>
}


export function createBackgroundColor<T extends RGB>(color: T) {
    return {
        kind: "background-color",
        rgb: color
    } as BackgroundColor<T["r"], T["g"], T["b"]>
}

/**
 * as_rgb_prefix <fg> <bg>
 *
 *  Receives a string for both the foreground and background colors desired
 *  and after trimming these strings to eliminated unwanted whitespace it
 *  constructs the overall escape code that will be necessary to produce
 *  this.
 */
function as_rgb_prefix(fg: string, bg: string): string {
    let result = '';

    // Build foreground escape code if provided
    if (fg.trim()) {
        // Parse RGB values (expecting "r g b" format)
        const fgValues = fg.trim().split(/\s+/).map(v => parseInt(v, 10));
        if (fgValues.length === 3 &&
            fgValues.every(v => !isNaN(v) && v >= 0 && v <= 255)) {
            result += `${FG_START}${fgValues[0]};${fgValues[1]};${fgValues[2]}${FG_END}`;
        }
    }

    // Build background escape code if provided
    if (bg.trim()) {
        // Parse RGB values (expecting "r g b" format)
        const bgValues = bg.trim().split(/\s+/).map(v => parseInt(v, 10));
        if (bgValues.length === 3 &&
            bgValues.every(v => !isNaN(v) && v >= 0 && v <= 255)) {
            result += `${BG_START}${bgValues[0]};${bgValues[1]};${bgValues[2]}${BG_END}`;
        }
    }

    return result;
}


/**
 * rgb_text <color> <text>
 *
 * A RGB color value is passed in first:
 *    - use a space delimited rgb value (e.g., 255 100 0)
 *    - if you express just a single RGB value than that will be used
 *    as the foreground/text color
 *    - if you want to specify both foreground and background then you
 *     will include two RGB values delimited by a `/` character (e.g.,
 *      `255 100 0 / 30 30 30` )
 *    - if you ONLY want to set the background then just use the `/` character
 *      followed by an RGB value (e.g., `/ 30 30 30`)
 *
 * The second parameter is the text you want to render with this RGB definition.
 */
function rgb_text(color: string, text: string = ''): string {
    const terminal = '\x1b[0m';

    let fg_color = '';
    let bg_color = '';

    if (color.includes('/')) {
        // Contains both foreground and background or just background
        fg_color = color;
        bg_color = trim(stripBefore(color, '/'));
        // If fg_color equals the original color, there was only background
        if (fg_color === color) {
            fg_color = '';
        }
    } else if (color.startsWith('/')) {
        // Only background
        bg_color = color.substring(1).trim();
    } else {
        // Only foreground
        fg_color = color;
    }

    return `${as_rgb_prefix(fg_color, bg_color)}${text}${terminal}`;
}

/**
 * orange <orange-text> <rest-text>
 *
 * produces orange text using RGB values for the content
 * in the first parameter and then just plain text for whatever (if anything)
 * is in the second parameter.
 */
function orange(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("242 81 29", text);
    return `${coloredText}${rest}`;
}

/**
 * orange_highlighted <colorized-text> <rest-text>
 */
function orange_highlighted(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("242 81 29/71 49 55", text);
    return `${coloredText}${rest}`;
}

/**
 * orange_backed <colorized-text> <rest-text>
 */
function orange_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("16 16 16/242 81 29", text);
    return `${coloredText}${rest}`;
}

/**
 * blue <colorized-text> <rest-text>
 */
function blue(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("4 51 255", text);
    return `${coloredText}${rest}`;
}

/**
 * blue_backed <colorized-text> <rest-text>
 */
function blue_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("235 235 235/4 51 255", text);
    return `${coloredText}${rest}`;
}

/**
 * light_blue_backed <colorized-text> <rest-text>
 */
function light_blue_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("8 8 8/65 128 255", text);
    return `${coloredText}${rest}`;
}

/**
 * dark_blue_backed <colorized-text> <rest-text>
 */
function dark_blue_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("235 235 235/1 25 147", text);
    return `${coloredText}${rest}`;
}

/**
 * tangerine <colorized-text> <rest-text>
 */
function tangerine(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("255 147 0", text);
    return `${coloredText}${rest}`;
}

/**
 * tangerine_highlighted <colorized-text> <rest-text>
 */
function tangerine_highlighted(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("255 147 0 / 125 77 0", text);
    return `${coloredText}${rest}`;
}

/**
 * tangerine_backed <colorized-text> <rest-text>
 */
function tangerine_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("16 16 16 / 255 147 0", text);
    return `${coloredText}${rest}`;
}

/**
 * slate_blue <colorized-text> <rest-text>
 *
 * produces slate blue text for content found in the first parameter
 * and then just plain text (if anything) for what is
 * in the second parameter.
 */
function slate_blue(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("63 99 139", text);
    return `${coloredText}${rest}`;
}

/**
 * slate_blue_backed <slate_blue_backed-text> <rest-text>
 *
 * produces slate blue text with a light background as backing
 * for content found in the first parameter and then just plain text
 * (if anything) for what is
 * in the second parameter.
 */
function slate_blue_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("63 99 139/203 237 255", text);
    return `${coloredText}${rest}`;
}

/**
 * green <colorized-text> <rest-text>
 */
function green(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("0 143 0", text);
    return `${coloredText}${rest}`;
}

/**
 * green_backed <colorized-text> <rest-text>
 */
function green_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("8 8 8/0 229 0", text);
    return `${coloredText}${rest}`;
}

/**
 * light_green_backed <colorized-text> <rest-text>
 */
function light_green_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("8 8 8/0 143 0", text);
    return `${coloredText}${rest}`;
}

/**
 * dark_green_backed <colorized-text> <rest-text>
 */
function dark_green_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("235 235 235/0 65 0", text);
    return `${coloredText}${rest}`;
}

/**
 * lime <colorized-text> <rest-text>
 *
 * produces lime text for content found in the first parameter
 * and then just plain text (if anything) for what is
 * in the second parameter.
 */
function lime(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("15 250 121", text);
    return `${coloredText}${rest}`;
}

/**
 * lime_backed <colorized-text> <rest-text>
 *
 * produces lime text with a darker background as backing
 * for content found in the first parameter and then just plain text
 * (if anything) for what is
 * in the second parameter.
 */
function lime_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("33 33 33/15 250 121", text);
    return `${coloredText}${rest}`;
}

/**
 * pink <colorized-text> <rest-text>
 *
 * produces pink text for content found in the first parameter
 * and then just plain text (if anything) for what is
 * in the second parameter.
 */
function pink(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("255 138 216", text);
    return `${coloredText}${rest}`;
}

/**
 * pink_backed <colorized-text> <rest-text>
 *
 * produces text with a pink background as backing
 * for content found in the first parameter and then just plain text
 * (if anything) for what is
 * in the second parameter.
 */
function pink_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("33 33 33/255 138 216", text);
    return `${coloredText}${rest}`;
}

/**
 * dark_pink_backed <colorized-text> <rest-text>
 *
 * produces text with a dark pink background as backing
 * for content found in the first parameter and then just plain text
 * (if anything) for what is
 * in the second parameter.
 */
function dark_pink_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("235 235 235/148 23 81", text);
    return `${coloredText}${rest}`;
}

/**
 * yellow <colored-text> <rest-text>
 *
 * produces yellow text for content found in the first parameter
 * and then just plain text (if anything) for what is in the second parameter.
 */
function yellow(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("255 252 121", text);
    return `${coloredText}${rest}`;
}

/**
 * light_yellow_backed <colored-text> <rest-text>
 */
function light_yellow_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("8 8 8/255 252 121", text);
    return `${coloredText}${rest}`;
}

/**
 * yellow_backed <colored-text> <rest-text>
 */
function yellow_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("8 8 8/255 251 0", text);
    return `${coloredText}${rest}`;
}

/**
 * dark_yellow_backed <colored-text> <rest-text>
 */
function dark_yellow_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("255 255 255/146 144 0", text);
    return `${coloredText}${rest}`;
}

/**
 * red <colored-text> <rest-text>
 *
 * produces red text for content found in the first parameter
 * and then just plain text (if anything) for what is
 * in the second parameter.
 */
function red(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("255 38 0", text);
    return `${coloredText}${rest}`;
}

/**
 * red_backed <colored-text> <rest-text>
 */
function red_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("235 235 235/255 38 0", text);
    return `${coloredText}${rest}`;
}

/**
 * dark_red_backed <colored-text> <rest-text>
 */
function dark_red_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("235 235 235/148 17 0", text);
    return `${coloredText}${rest}`;
}

/**
 * light_red_backed <colored-text> <rest-text>
 */
function light_red_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("8 8 8/255 126 121", text);
    return `${coloredText}${rest}`;
}

/**
 * purple <colored-text> <rest-text>
 *
 * produces purple text for content found in the first parameter
 * and then just plain text (if anything) for what is
 * in the second parameter.
 */
function purple(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("172 57 255", text);
    return `${coloredText}${rest}`;
}

/**
 * purple_backed <colored-text> <rest-text>
 */
function purple_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("235 235 235/148 55 255", text);
    return `${coloredText}${rest}`;
}

/**
 * light_purple_backed <colored-text> <rest-text>
 */
function light_purple_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("8 8 8/215 131 255", text);
    return `${coloredText}${rest}`;
}

/**
 * **darkPurpleBacked**`(text, afterText)`
 *
 */
export function darkPurpleBacked(text: string = '', afterText: string = ''): string {
    const coloredText = rgb_text("235 235 235/83 27 147", text);
    return `${coloredText}${afterText}`;
}

/**
 * black_backed <colorized-text> <rest-text>
 */
function black_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("192 192 192/0 0 0", text);
    return `${coloredText}${rest}`;
}

/**
 * white_backed <colorized-text> <rest-text>
 */
function white_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("66 66 66/255 255 255", text);
    return `${coloredText}${rest}`;
}

/**
 * gray_backed <colorized-text> <rest-text>
 */
function gray_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("33 33 33/169 169 169", text);
    return `${coloredText}${rest}`;
}

/**
 * light_gray_backed <colorized-text> <rest-text>
 */
function light_gray_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("55 55 55/214 214 214", text);
    return `${coloredText}${rest}`;
}

/**
 * dark_gray_backed <colorized-text> <rest-text>
 */
function dark_gray_backed(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("235 235 235/66 66 66", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_gray <colorized-text> <rest-text>
 */
function bg_gray(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/94 94 94", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_light_gray <colorized-text> <rest-text>
 */
function bg_light_gray(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/146 146 146", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_dark_gray <colorized-text> <rest-text>
 */
function bg_dark_gray(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/66 66 66", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_blue <colorized-text> <rest-text>
 */
function bg_blue(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/0 84 147", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_light_blue <colorized-text> <rest-text>
 */
function bg_light_blue(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/0 150 255", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_dark_blue <colorized-text> <rest-text>
 */
function bg_dark_blue(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/1 25 147", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_green <colorized-text> <rest-text>
 */
function bg_green(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/0 143 0", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_light_green <colorized-text> <rest-text>
 */
function bg_light_green(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/0 172 0", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_dark_green <colorized-text> <rest-text>
 */
function bg_dark_green(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/0 114 0", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_yellow <colorized-text> <rest-text>
 */
function bg_yellow(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/255 251 0", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_light_yellow <colorized-text> <rest-text>
 */
function bg_light_yellow(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/255 252 121", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_dark_yellow <colorized-text> <rest-text>
 */
function bg_dark_yellow(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/146 144 0", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_red <colorized-text> <rest-text>
 */
function bg_red(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/255 38 0", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_light_red <colorized-text> <rest-text>
 */
function bg_light_red(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/255 126 121", text);
    return `${coloredText}${rest}`;
}

/**
 * bg_dark_red <colorized-text> <rest-text>
 */
function bg_dark_red(text: string = '', rest: string = ''): string {
    const coloredText = rgb_text("/148 17 0", text);
    return `${coloredText}${rest}`;
}

// Export all functions
export {
    as_rgb_prefix,
    rgb_text,
    orange,
    orange_highlighted,
    orange_backed,
    blue,
    blue_backed,
    light_blue_backed,
    dark_blue_backed,
    tangerine,
    tangerine_highlighted,
    tangerine_backed,
    slate_blue,
    slate_blue_backed,
    green,
    green_backed,
    light_green_backed,
    dark_green_backed,
    lime,
    lime_backed,
    pink,
    pink_backed,
    dark_pink_backed,
    yellow,
    light_yellow_backed,
    yellow_backed,
    dark_yellow_backed,
    red,
    red_backed,
    dark_red_backed,
    light_red_backed,
    purple,
    purple_backed,
    light_purple_backed,
    black_backed,
    white_backed,
    gray_backed,
    light_gray_backed,
    dark_gray_backed,
    bg_gray,
    bg_light_gray,
    bg_dark_gray,
    bg_blue,
    bg_light_blue,
    bg_dark_blue,
    bg_green,
    bg_light_green,
    bg_dark_green,
    bg_yellow,
    bg_light_yellow,
    bg_dark_yellow,
    bg_red,
    bg_light_red,
    bg_dark_red
};


const BOLD = "\x1b[1m" as const;
const NORMAL =  "\x1b[22m" as const;
const DIM =  "\x1b[2m" as const;
const UNDERLINE = `\x1b[4m` as const;
const NO_UNDERLINE = `\x1b[24m` as const;
const STRIKETHROUGH = `\x1b[9m` as const;
const NO_STRIKETHROUGH = `\x1b[29m` as const;
const BLINK = `` as const;
const NO_BLINK = `` as const;
const RESET = narrow(`\x1b[33m`);

const LOOKUP = narrow({
    dim: DIM,
    normal: NORMAL,
    bold: BOLD,
    reset: RESET,
    strikethrough: STRIKETHROUGH,
    no_strikethrough: NO_STRIKETHROUGH
});

type EscapeCode<T extends StringKeys<typeof LOOKUP>[number]> = typeof LOOKUP[T];

export const format = {
    // mode: ,

    /**
     * Boldfaces the text passed in and returns font weight to **normal**
     * afterward.
     */
    bold<T extends string>(content: T): `${typeof BOLD}${T}${typeof NORMAL}` {
        return `${BOLD}${content}${NORMAL}`
    },
    /**
     * Dims the text passed in and returns font weight to **normal**
     * afterward.
     */
    dim<T extends string>(content: T): `${typeof DIM}${T}${typeof NORMAL}` {
        return `${DIM}${content}${NORMAL}`
    },
    /**
     * **normal**`(content,[returnTo],[after])`
     *
     * Sets the text passed in to the default/normal weight.
     *
     * - by default it will simply set this before adding the `content`
     *   and just leave this font weight in place
     * - however, if you want to _return to_ some other font weight (e.g., bold/dim)
     *   then you can specify that in `returnTo`.
     * - in this situation where you are using the _return to_ functionality then
     */
    normal<T extends string, R extends "dim" | "normal" | "bold", A extends string>(
        content: T,
        returnTo: R = "normal" as R,
        after?: A
    ): R extends "normal" ? `${typeof NORMAL}${T}${Fallback<A,"">}` : `${typeof NORMAL}${T}${EscapeCode<R>}${Fallback<A,"">}}` {
        return (
            returnTo === "normal"
                ? `${NORMAL}${content}${after || ""}`
                : `${NORMAL}${content}${LOOKUP[returnTo]}${after || ""}${NORMAL}`
        ) as R extends "normal" ? `${typeof NORMAL}${T}${Fallback<A,"">}` : `${typeof NORMAL}${T}${EscapeCode<R>}${Fallback<A,"">}}`
    },

    /**
     * adds an _underline_ to the text in `content` and the adds a **no underline** escape
     * code at the end.
     */
    underline<T extends string>(content: T): `${typeof UNDERLINE}${T}${typeof NO_UNDERLINE}` {
        return `${UNDERLINE}${content}${NO_UNDERLINE}`
    },

    /**
     * adds a _strikethrough_ adornment to the text in `content` and the adds a
     * **no strikethrough** escape code at the end.
     */
    strikethrough<T extends string>(content: T): `${EscapeCode<"strikethrough">}${T}${EscapeCode<"no_strikethrough">}` {
        return `${STRIKETHROUGH}${content}${NO_STRIKETHROUGH}`
    },

    /**
     * returns the RESET escape sequence for terminals
     */
    reset(): EscapeCode<"reset"> {
        return RESET
    },


}
