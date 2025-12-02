#!/usr/bin/env bash

# Source guard - must be BEFORE path setup to prevent re-execution
[[ -n "${__COLOR_SH_LOADED:-}" ]] && return
__COLOR_SH_LOADED=1

if [ -z "${ADAPTIVE_SHELL:-}" ] || [[ "${ADAPTIVE_SHELL:-}" == "" ]]; then
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "${UTILS}" == *"/utils" ]];then
        ROOT="${UTILS%"/utils"}"
    else
        ROOT="$UTILS"
    fi
else
    ROOT="${ADAPTIVE_SHELL}"
    UTILS="${ROOT}/utils"
fi

# shellcheck source="./text.sh"
source "${UTILS}/text.sh"

# _query_terminal_osc <osc_code>
#
# Internal helper to send OSC query and read response.
# Returns the response content or empty string on timeout/failure.
#
# Supports tmux passthrough when running inside tmux.
_query_terminal_osc() {
    local osc_code="${1:?OSC code required}"
    local response=""

    # Check if we have a terminal
    [[ -t 0 ]] && [[ -t 1 ]] || return 1

    # Skip in CI environments
    [[ -n "${CI:-}" ]] && return 1

    # Need /dev/tty for terminal communication
    [[ -c /dev/tty ]] || return 1

    # Save terminal state
    local old_stty
    old_stty=$(stty -g 2>/dev/null </dev/tty) || return 1

    # Set raw mode for reading response with timeout
    # min 0 = don't wait for chars, time 1 = 0.1 second timeout
    stty raw -echo min 0 time 1 2>/dev/null </dev/tty || {
        stty "$old_stty" 2>/dev/null </dev/tty
        return 1
    }

    # Build the query sequence
    local query_seq
    query_seq=$(printf '\033]%s;?\a' "$osc_code")

    # If running in tmux, wrap with passthrough sequence
    # tmux requires: ESC Ptmux; ESC <actual sequence> ESC \
    if [[ -n "${TMUX:-}" ]]; then
        # Double the ESC characters and wrap in tmux passthrough
        # ESC P tmux; ESC ESC ] code ; ? BEL ESC \
        query_seq=$(printf '\033Ptmux;\033\033]%s;?\a\033\\' "$osc_code")
    fi

    # Send query to terminal
    printf '%s' "$query_seq" >/dev/tty

    # Read response with timeout
    response=$(dd bs=100 count=1 2>/dev/null </dev/tty)

    # Restore terminal
    stty "$old_stty" 2>/dev/null </dev/tty

    printf '%s' "$response"
}

# _parse_osc_rgb_response <response>
#
# Internal helper to parse OSC RGB response format.
# Input: Response string containing "rgb:RRRR/GGGG/BBBB"
# Output: "R G B" in 0-255 range, or empty on failure
#
# Works in both Bash and Zsh by avoiding shell-specific regex arrays.
_parse_osc_rgb_response() {
    local response="${1:-}"

    # Extract the rgb:XXXX/YYYY/ZZZZ portion using parameter expansion
    # This approach avoids BASH_REMATCH vs match array incompatibility
    local rgb_part=""

    # Find "rgb:" in the response
    if [[ "$response" == *"rgb:"* ]]; then
        # Extract everything after "rgb:"
        rgb_part="${response#*rgb:}"
        # Remove anything after the RGB values (BEL, ST, etc.)
        # RGB format is HEX/HEX/HEX where HEX is 2-4 hex chars
        rgb_part="${rgb_part%%[^0-9a-fA-F/]*}"
    else
        return 1
    fi

    # Split by "/" - need to handle both shells
    local r_hex g_hex b_hex
    local IFS_save="$IFS"
    IFS='/'
    # Use read to split - works in both bash and zsh
    read -r r_hex g_hex b_hex <<< "$rgb_part"
    IFS="$IFS_save"

    # Validate we got all three components
    [[ -n "$r_hex" ]] && [[ -n "$g_hex" ]] && [[ -n "$b_hex" ]] || return 1

    # Validate hex format
    [[ "$r_hex" =~ ^[0-9a-fA-F]+$ ]] || return 1
    [[ "$g_hex" =~ ^[0-9a-fA-F]+$ ]] || return 1
    [[ "$b_hex" =~ ^[0-9a-fA-F]+$ ]] || return 1

    # Convert to 8-bit (take first 2 hex digits if 4 digits)
    local r g b
    r=$((16#${r_hex:0:2}))
    g=$((16#${g_hex:0:2}))
    b=$((16#${b_hex:0:2}))

    printf '%d %d %d' "$r" "$g" "$b"
}

# terminal_background_color
#
# Query the terminal for its default background color using OSC 11.
# Returns RGB values as "R G B" (0-255 range) or empty string if unavailable.
#
# Environment variable overrides:
# - TERMINAL_BG_COLOR: If set, returns this value directly (format: "R G B")
#
# Shell compatibility: Works in both Bash and Zsh.
# tmux support: Automatically uses passthrough sequences when running in tmux.
terminal_background_color() {
    # Check for explicit override (highest priority)
    if [[ -n "${TERMINAL_BG_COLOR:-}" ]]; then
        printf '%s' "$TERMINAL_BG_COLOR"
        return 0
    fi

    # Query terminal
    local response result
    response=$(_query_terminal_osc 11) || return 1

    # Parse the response
    result=$(_parse_osc_rgb_response "$response") || return 1

    printf '%s' "$result"
}

# terminal_foreground_color
#
# Query the terminal for its default foreground (text) color using OSC 10.
# Returns RGB values as "R G B" (0-255 range) or empty string if unavailable.
#
# Environment variable overrides:
# - TERMINAL_FG_COLOR: If set, returns this value directly (format: "R G B")
#
# Shell compatibility: Works in both Bash and Zsh.
# tmux support: Automatically uses passthrough sequences when running in tmux.
terminal_foreground_color() {
    # Check for explicit override (highest priority)
    if [[ -n "${TERMINAL_FG_COLOR:-}" ]]; then
        printf '%s' "$TERMINAL_FG_COLOR"
        return 0
    fi

    # Query terminal
    local response result
    response=$(_query_terminal_osc 10) || return 1

    # Parse the response
    result=$(_parse_osc_rgb_response "$response") || return 1

    printf '%s' "$result"
}

# calculate_luminance <R> <G> <B>
#
# Calculate the relative luminance of an RGB color using ITU-R BT.709 formula.
# Input: R G B values in 0-255 range (as separate arguments or space-separated)
# Output: Luminance value 0-255
#
# Shell compatibility: Works in both Bash and Zsh (uses integer math only).
calculate_luminance() {
    local r g b

    if [[ $# -eq 3 ]]; then
        r="$1"
        g="$2"
        b="$3"
    elif [[ $# -eq 1 ]]; then
        read -r r g b <<< "$1"
    else
        return 1
    fi

    # Validate inputs
    [[ "$r" =~ ^[0-9]+$ ]] && [[ "$g" =~ ^[0-9]+$ ]] && [[ "$b" =~ ^[0-9]+$ ]] || return 1

    # Calculate luminance using ITU-R BT.709 formula:
    # L = 0.2126*R + 0.7152*G + 0.0722*B
    # Using integer math with scaling: L = (2126*R + 7152*G + 722*B) / 10000
    local luminance=$(( (2126 * r + 7152 * g + 722 * b) / 10000 ))

    printf '%d' "$luminance"
}

# calculate_contrast_ratio <fg_rgb> <bg_rgb>
#
# Calculate the contrast ratio between foreground and background colors.
# Input: Two RGB strings, each as "R G B" in 0-255 range
# Output: Contrast ratio as integer (multiplied by 100 for precision)
#
# WCAG contrast ratios:
# - 4.5:1 (450) minimum for normal text
# - 3:1 (300) minimum for large text
# - 7:1 (700) enhanced for normal text
#
# Shell compatibility: Works in both Bash and Zsh (uses integer math only).
calculate_contrast_ratio() {
    local fg_rgb="${1:?Foreground RGB required}"
    local bg_rgb="${2:?Background RGB required}"

    local fg_lum bg_lum
    fg_lum=$(calculate_luminance "$fg_rgb") || return 1
    bg_lum=$(calculate_luminance "$bg_rgb") || return 1

    # Convert to relative luminance (0-1 scaled to 0-255, then add 5 for the +0.05 offset)
    # Formula: (L1 + 0.05) / (L2 + 0.05) where L1 is lighter
    # Since we're using 0-255 scale, add 12 (≈0.05 * 255) instead of 0.05
    local lighter darker
    if [[ $fg_lum -gt $bg_lum ]]; then
        lighter=$fg_lum
        darker=$bg_lum
    else
        lighter=$bg_lum
        darker=$fg_lum
    fi

    # Calculate ratio * 100 for integer precision
    # (lighter + 12) / (darker + 12) * 100
    local ratio=$(( ((lighter + 12) * 100) / (darker + 12) ))

    printf '%d' "$ratio"
}

# is_dark_mode -> boolean
#
# Uses OSC 11 to query the terminal's background color and determines
# if the terminal is in dark mode based on luminance calculation.
#
# Environment variable overrides:
# - TERMINAL_THEME: If set to "dark" or "light", returns accordingly
# - TERMINAL_BG_COLOR: If set, uses this RGB value for calculation
#
# Returns:
# - 0 (true) if terminal background is dark (luminance < 128)
# - 1 (false) if terminal background is light (luminance >= 128)
# - Defaults to dark mode (0) if detection fails
is_dark_mode() {
    # Check for explicit override
    if [[ "${TERMINAL_THEME:-}" == "dark" ]]; then
        return 0
    elif [[ "${TERMINAL_THEME:-}" == "light" ]]; then
        return 1
    fi

    local bg_color
    bg_color=$(terminal_background_color) || {
        # Default to dark mode if detection fails
        return 0
    }

    # Handle empty response
    [[ -n "$bg_color" ]] || return 0

    local r g b
    read -r r g b <<< "$bg_color"

    # Calculate luminance using ITU-R BT.709 formula:
    # L = 0.2126*R + 0.7152*G + 0.0722*B
    # Using integer math with scaling: L = (2126*R + 7152*G + 722*B) / 10000
    local luminance=$(( (2126 * r + 7152 * g + 722 * b) / 10000 ))

    # Dark mode if luminance < 128
    [[ $luminance -lt 128 ]]
}

# is_light_mode -> boolean
#
# Uses OSC 11 to query the terminal's background color and determines
# if the terminal is in light mode based on luminance calculation.
#
# Environment variable overrides:
# - TERMINAL_THEME: If set to "dark" or "light", returns accordingly
# - TERMINAL_BG_COLOR: If set, uses this RGB value for calculation
#
# Returns:
# - 0 (true) if terminal background is light (luminance >= 128)
# - 1 (false) if terminal background is dark (luminance < 128)
# - Defaults to dark mode, so returns 1 (false) if detection fails
is_light_mode() {
    # Check for explicit override
    if [[ "${TERMINAL_THEME:-}" == "light" ]]; then
        return 0
    elif [[ "${TERMINAL_THEME:-}" == "dark" ]]; then
        return 1
    fi

    local bg_color
    bg_color=$(terminal_background_color) || {
        # Default to dark mode if detection fails, so light mode is false
        return 1
    }

    # Handle empty response
    [[ -n "$bg_color" ]] || return 1

    local r g b
    read -r r g b <<< "$bg_color"

    # Calculate luminance using ITU-R BT.709 formula
    local luminance=$(( (2126 * r + 7152 * g + 722 * b) / 10000 ))

    # Light mode if luminance >= 128
    [[ $luminance -ge 128 ]]
}


function colors_not_setup() {
    if [[ -z "${BRIGHT_BLACK}" ]]; then
        debug "colors_not_setup" "Colors are NOT setup"
        echo "0";
        return 0; # colors are NOT setup
    else
        debug "colors_not_setup" "Colors ARE setup"
        echo "1"
        return 1; # colors ARE setup
    fi
}

function colors_are_setup() {
    if [[ -z "${BRIGHT_BLACK}" ]]; then
        debug "colors_not_setup" "Colors ARE setup"
        echo "0"
        return 0; # colors ARE setup
    else
        debug "colors_not_setup" "Colors are NOT setup"
        echo "1";
        return 1; # colors are NOT setup
    fi
}

function setup_colors() {
    export AD_COLORS_SETUP="true"
    export BLACK=$'\033[30m'
    export RED=$'\033[31m'
    export GREEN=$'\033[32m'
    export YELLOW=$'\033[33m'
    export BLUE=$'\033[34m'
    export MAGENTA=$'\033[35m'
    export CYAN=$'\033[36m'
    export WHITE=$'\033[37m'

    export BRIGHT_BLACK=$'\033[90m'
    export BRIGHT_RED=$'\033[91m'
    export BRIGHT_GREEN=$'\033[92m'
    export BRIGHT_YELLOW=$'\033[93m'
    export BRIGHT_BLUE=$'\033[94m'
    export BRIGHT_MAGENTA=$'\033[95m'
    export BRIGHT_CYAN=$'\033[96m'
    export BRIGHT_WHITE=$'\033[97m'

    # font weights
    export BOLD=$'\033[1m'
    export NORMAL=$'\033[22m'
    export DIM=$'\033[2m'

    export ITALIC=$'\033[3m'
    export NO_ITALIC=$'\033[23m'
    export STRIKE=$'\033[9m'
    export NO_STRIKE=$'\033[29m'
    export REVERSE=$'\033[7m'
    export NO_REVERSE=$'\033[27m'
    export UNDERLINE=$'\033[4m'
    export NO_UNDERLINE=$'\033[24m'
    export BLINK=$'\033[5m'
    export NO_BLINK=$'\033[25m'

    export BG_BLACK=$'\033[40m'
    export BG_RED=$'\033[41m'
    export BG_GREEN=$'\033[42m'
    export BG_YELLOW=$'\033[43m'
    export BG_BLUE=$'\033[44m'
    export BG_MAGENTA=$'\033[45m'
    export BG_CYAN=$'\033[46m'
    export BG_WHITE=$'\033[47m'

    export BG_BRIGHT_BLACK=$'\033[100m'
    export BG_BRIGHT_RED=$'\033[101m'
    export BG_BRIGHT_GREEN=$'\033[102m'
    export BG_BRIGHT_YELLOW=$'\033[103m'
    export BG_BRIGHT_BLUE=$'\033[104m'
    export BG_BRIGHT_MAGENTA=$'\033[105m'
    export BG_BRIGHT_CYAN=$'\033[106m'
    export BG_BRIGHT_WHITE=$'\033[107m'

    export RESET=$'\033[0m' # RESET ALL ATTRIBUTES
    export DEF_FG=$'\033[39m' # RESET the Foreground Color
    export DEF_BG=$'\033[49m' # RESET the Background Color
    export DEF_COLOR="${DEFAULT_FG}${DEFAULT_BG}" # RESET Foreground and Background

    export SAVE_POSITION=$'\033[s'
    export RESTORE_POSITION=$'\033[u'
    export CLEAR_SCREEN=$'\033[2J'

}

function screen_title() {
    local -r title=${1:?no title passed to screen_title()!}

    printf '\033]0;%s\007' "${title}"
}

function clear_screen() {
    printf '\033[2J'
}

function remove_colors() {
    unset RED BLACK GREEN YELLOW BLUE MAGENTA CYAN WHITE
    unset BRIGHT_BLACK BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW BRIGHT_BLUE BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE
    unset BOLD NO_BOLD NORMAL DIM NO_DIM ITALIC NO_ITALIC STRIKE NO_STRIKE REVERSE NO_REVERSE
    unset UNDERLINE NO_UNDERLINE BLINK NO_BLINK
    unset BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE
    unset BG_BRIGHT_BLACK BG_BRIGHT_RED BG_BRIGHT_GREEN BG_BRIGHT_YELLOW BG_BRIGHT_BLUE BG_BRIGHT_MAGENTA BG_BRIGHT_CYAN BG_BRIGHT_WHITE
    unset RESET DEF_FG DEF_BG DEF_COLOR
    unset SAVE_POSITION RESTORE_POSITION CLEAR_SCREEN
}

# as_rgb_prefix <fg> <bg>
#
# Receives a string for both the foreground and background colors desired
# and after trimming these strings to eliminated unwanted whitespace it
# constructs the overall escape code that will be necessary to produce
# this.
function as_rgb_prefix() {
    local -r fg="$(trim "${1:-}")"
    local -r bg="$(trim "${2:-}")"
    local result=""


    # Build foreground escape code if provided
    if [[ -n "$fg" ]]; then
        local r g b
        # Use read to split into scalars, avoiding Bash(0-based)/Zsh(1-based) array index confusion
        if read -r r g b <<< "$fg"; then
            if [[ "$r" =~ ^[0-9]+$ ]] && [[ "$g" =~ ^[0-9]+$ ]] && [[ "$b" =~ ^[0-9]+$ ]]; then
                result+=$'\033[38;2;'${r}';'${g}';'${b}'m'
            fi
        fi
    fi

    # Build background escape code if provided
    if [[ -n "$bg" ]]; then
        local r g b
        if read -r r g b <<< "$bg"; then
            if [[ "$r" =~ ^[0-9]+$ ]] && [[ "$g" =~ ^[0-9]+$ ]] && [[ "$b" =~ ^[0-9]+$ ]]; then
                result+=$'\033[48;2;'${r}';'${g}';'${b}'m'
            fi
        fi
    fi

    printf '%s' "$result"
}



# rgb_text <color> <text>
#
# A RGB color value is passed in first:
#    - use a space delimited rgb value (e.g., 255 100 0)
#    - if you express just a single RGB value than that will be used
#    as the foreground/text color
#    - if you want to specify both foreground and background then you
#     will include two RGB values delimited by a `/` character (e.g.,
#      `255 100 0 / 30 30 30` )
#    - if you ONLY want to set the background then just use the `/` character
#      followed by an RGB value (e.g., `/ 30 30 30`)
#
# The second parameter is the text you want to render with this RGB definition.
rgb_text() {
    local -r color=${1:?RGB color value must be passed as first parameter to rgb_text()!}
    local -r text="${2:-}"
    local -r terminal=$'\033[0m'

    local fg_color=""
    local bg_color=""

    if [[ "$color" == *"/"* ]]; then
        # Contains both foreground and background or just background
        fg_color="$(trim "$(strip_after "/" "${color}")")"
        bg_color="$(trim "$(strip_before "/" "${color}")")"
        # If fg_color equals the original color, there was only background
        if [[ "$fg_color" == "$color" ]]; then
            fg_color=""
        fi
    elif [[ "$color" == "/"* ]]; then
        # Only background
        bg_color="${color#/ }"
    else
        # Only foreground
        fg_color="$color"
    fi

    printf '%s%s%s' "$(as_rgb_prefix "${fg_color}" "${bg_color}")" "${text}" "${terminal}"
}

# orange <orange-text> <rest-text>
#
# produces orange text using RGB values for the content
# in "${1}" and then just plain text for whatever (if anything)
# is in "${2}".
function orange() {
    local -r text="$(rgb_text "242 81 29" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# orange_highlighted <colorized-text> <rest-text>
function orange_highlighted() {
    local -r text="$(rgb_text "242 81 29/71 49 55" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# orange_backed <colorized-text> <rest-text>
function orange_backed() {
    local -r text="$(rgb_text "16 16 16/242 81 29" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# blue <colorized-text> <rest-text>
function blue() {
    local -r text="$(rgb_text "4 51 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# blue_backed <colorized-text> <rest-text>
function blue_backed() {
    local -r text="$(rgb_text "235 235 235/4 51 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}
# light_blue_backed <colorized-text> <rest-text>
function light_blue_backed() {
    local -r text="$(rgb_text "8 8 8/65 128 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# dark_blue_backed <colorized-text> <rest-text>
function dark_blue_backed() {
    local -r text="$(rgb_text "235 235 235/1 25 147" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# tangerine <colorized-text> <rest-text>
function tangerine() {
    local -r text="$(rgb_text "255 147 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# tangerine_highlighted <colorized-text> <rest-text>
function tangerine_highlighted {
    local -r text="$(rgb_text "255 147 0 / 125 77 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# tangerine_backed <colorized-text> <rest-text>
function tangerine_backed {
    local -r text="$(rgb_text "16 16 16 / 255 147 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# slate_blue <colorized-text> <rest-text>
#
# produces slate blue text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function slate_blue() {
    local -r text="$(rgb_text "63 99 139" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# slate_blue_backed <slate_blue_backed-text> <rest-text>
#
# produces slate blue text with a light background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is
# in "${2}".
function slate_blue_backed() {
    local -r text="$(rgb_text "63 99 139/203 237 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# green <colorized-text> <rest-text>
function green() {
    local -r text="$(rgb_text "0 143 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# green_backed <colorized-text> <rest-text>
function green_backed() {
    local -r text="$(rgb_text "8 8 8/0 229 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# light_green_backed <colorized-text> <rest-text>
function light_green_backed() {
    local -r text="$(rgb_text "8 8 8/0 143 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# dark_green_backed <colorized-text> <rest-text>
function dark_green_backed() {
    local -r text="$(rgb_text "235 235 235/0 65 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# lime <colorized-text> <rest-text>
#
# produces blue text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function lime() {
    local -r text="$(rgb_text "15 250 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# blue_backed <colorized-text> <rest-text>
#
# produces blue text with a lighter background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is
# in "${2}".
function lime_backed() {
    local -r text="$(rgb_text "33 33 33/15 250 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# pink <colorized-text> <rest-text>
#
# produces blue text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function pink() {
    local -r text="$(rgb_text "255 138 216" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# pink_backed <colorized-text> <rest-text>
#
# produces text with a pink background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is
# in "${2}".
function pink_backed() {
    local -r text="$(rgb_text "33 33 33/255 138 216" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# dark_pink_backed <colorized-text> <rest-text>
#
# produces text with a pink background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is
# in "${2}".
function dark_pink_backed() {
    local -r text="$(rgb_text "235 235 235/148 23 81" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}




# yellow <colored-text> <rest-text>
#
# produces dark red text with a lighter background as backing
# for content found in "${1}" and then just plain text
# (if anything) for what is in "${2}".
function yellow() {
    local -r text="$(rgb_text "255 252 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# light_yellow_backed <colored-text> <rest-text>
function light_yellow_backed() {
    local -r text="$(rgb_text "8 8 8/255 252 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# yellow_backed <colored-text> <rest-text>
function yellow_backed() {
    local -r text="$(rgb_text "8 8 8/255 251 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# dark_yellow_backed <colored-text> <rest-text>
function dark_yellow_backed() {
    local -r text="$(rgb_text "255 255 255/146 144 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# red <colored-text> <rest-text>
#
# produces blue text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function red() {
    local -r text="$(rgb_text "255 38 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# red_backed <colored-text> <rest-text>
function red_backed() {
    local -r text="$(rgb_text "235 235 235/255 38 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}



# dark_red_backed <colored-text> <rest-text>
function dark_red_backed() {
    local -r text="$(rgb_text "235 235 235/148 17 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# light_red_backed <colored-text> <rest-text>
function light_red_backed() {
    local -r text="$(rgb_text "8 8 8/255 126 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# purple <colored-text> <rest-text>
#
# produces purple text for content found in "${1}"
# and then just plain text (if anything) for what is
# in "${2}".
function purple() {
    local -r text="$(rgb_text "172 57 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# purple_backed <colored-text> <rest-text>
function purple_backed() {
    local -r text="$(rgb_text "235 235 235/148 55 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# light_purple_backed <colored-text> <rest-text>
function light_purple_backed() {
    local -r text="$(rgb_text "8 8 8/215 131 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

# dark_purple_backed <colored-text> <rest-text>
function dark_purple_backed() {
    local -r text="$(rgb_text "235 235 235/83 27 147" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function black_backed() {
    local -r text="$(rgb_text "192 192 192/0 0 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function white_backed() {
    local -r text="$(rgb_text "66 66 66/255 255 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function gray_backed() {
    local -r text="$(rgb_text "33 33 33/169 169 169" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function light_gray_backed() {
    local -r text="$(rgb_text "55 55 55/214 214 214" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function dark_gray_backed() {
    local -r text="$(rgb_text "235 235 235/66 66 66" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


function bg_gray() {
    local -r text="$(rgb_text "/94 94 94" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_gray() {
    local -r text="$(rgb_text "/146 146 146" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_gray() {
    local -r text="$(rgb_text "/66 66 66" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}



function bg_blue() {
    local -r text="$(rgb_text "/0 84 147" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_blue() {
    local -r text="$(rgb_text "/0 150 255" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_blue() {
    local -r text="$(rgb_text "/1 25 147" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_green() {
    local -r text="$(rgb_text "/0 143 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_green() {
    local -r text="$(rgb_text "/0 172 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_green() {
    local -r text="$(rgb_text "/0 114 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_yellow() {
    local -r text="$(rgb_text "/255 251 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_yellow() {
    local -r text="$(rgb_text "/255 252 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_yellow() {
    local -r text="$(rgb_text "/146 144 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_red() {
    local -r text="$(rgb_text "/255 38 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_light_red() {
    local -r text="$(rgb_text "/255 126 121" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}

function bg_dark_red() {
    local -r text="$(rgb_text "/148 17 0" "${1:-}")"
    local -r rest="${2:-}"

    printf '%s%s\n' "${text}" "${rest}"
}


# colorize <content>
#
# Looks for tags which represent formatting instructions -- `{{RED}}`, `{{RESET}}`,
# etc. -- and converts them using a variable of the same name.
colorize() {
    local -r content="${*:-}"
    local rest="$content"
    local result=""
    local tag

    while [[ "$rest" == *"{{"* ]]; do
        result+="${rest%%\{\{*}"
        rest="${rest#*\{\{}"

        if [[ "$rest" != *"}}"* ]]; then
            result+="{{${rest}"
            rest=""
            break
        fi

        tag="${rest%%\}\}*}"
        rest="${rest#*\}\}}"

        # Ensure tag is a valid variable name to prevent injection/errors
        if [[ ! "$tag" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            result+="{{${tag}}}"
            continue
        fi

        if [ -n "${ZSH_VERSION:-}" ]; then
            if (( ${+parameters[$tag]} )); then
                result+="${(P)tag}"
            else
                result+="{{${tag}}}"
            fi
        else
            # Bash: Use eval to safely handle indirection and avoid Zsh parsing errors
            if eval "[[ \${!tag+x} ]]"; then
                local val
                eval 'val="${!tag}"'
                result+="$val"
            else
                result+="{{${tag}}}"
            fi
        fi
    done

    result+="$rest"

    printf '%s' "$result"
}

# CLI invocation handler - allows running script directly with a function name
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Set up paths for sourcing dependencies
    UTILS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="${UTILS%"/utils"}"

    cmd="${1:-}"
    shift 2>/dev/null || true

    if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
        script_name="$(basename "${BASH_SOURCE[0]}")"
        echo "Usage: $script_name <function> [args...]"
        echo ""
        echo "Available functions:"
        # List all functions that don't start with _
        declare -F | awk '{print $3}' | grep -v '^_' | sort | sed 's/^/  /'
        exit 0
    fi

    # Check if function exists and call it
    if declare -f "$cmd" > /dev/null 2>&1; then
        "$cmd" "$@"
    else
        echo "Error: Unknown function '$cmd'" >&2
        echo "Run '$(basename "${BASH_SOURCE[0]}") --help' for available functions" >&2
        exit 1
    fi
fi
