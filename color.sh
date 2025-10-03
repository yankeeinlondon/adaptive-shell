#!/usr/bin/env bash

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

setup_colors() {
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

    export BOLD=$'\033[1m'
    export NO_BOLD=$'\033[21m'
    export DIM=$'\033[2m'
    export NO_DIM=$'\033[22m'
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

    export RESET=$'\033[0m'

    export SAVE_POSITION=$'\033[s'
    export RESTORE_POSITION=$'\033[u'
    export CLEAR_SCREEN=$'\033[2J'
}

screen_title() {
    local -r title=${1:?no title passed to screen_title()!}

    printf '\033]0;%s\007' "${title}"
}

clear_screen() {
    printf '\033[2J'
}

remove_colors() {
    if [ -n "${RESET:-}" ]; then
        printf "%b" "${RESET}"
    fi

    unset RED BLACK GREEN YELLOW BLUE MAGENTA CYAN WHITE
    unset BRIGHT_BLACK BRIGHT_RED BRIGHT_GREEN BRIGHT_YELLOW BRIGHT_BLUE BRIGHT_MAGENTA BRIGHT_CYAN BRIGHT_WHITE
    unset BOLD NO_BOLD DIM NO_DIM ITALIC NO_ITALIC STRIKE NO_STRIKE REVERSE NO_REVERSE
    unset UNDERLINE NO_UNDERLINE BLINK NO_BLINK
    unset BG_BLACK BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_MAGENTA BG_CYAN BG_WHITE
    unset BG_BRIGHT_BLACK BG_BRIGHT_RED BG_BRIGHT_GREEN BG_BRIGHT_YELLOW BG_BRIGHT_BLUE BG_BRIGHT_MAGENTA BG_BRIGHT_CYAN BG_BRIGHT_WHITE
    unset RESET
    unset SAVE_POSITION RESTORE_POSITION
}

as_rgb_prefix() {
    local -r fg="$(trim "${1-}")"
    local -r bg="$(trim "${2-}")"
    local -r foreground='\033[38;2;]'
    local -r background='\033[48;2;]'


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
    local -r terminal='\033[0m]'

    local -r fg_color="$(strip_after "/" "${color}")"
    local -r bg_color="$(strip_before "/" "${color}")"

    printf '%s%s%s' "$(as_rgb_prefix "${fg_color}" "${bg_color}")" "${text}" "${terminal}"
}

# colorize <content>
#
# Looks for tags which represent formatting instructions -- `{{RED}}`, `{{RESET}}`,
# etc. -- and converts them using a variable of the same name.
colorize() {
    local -r content="${1:-}"
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

        if [[ ${!tag+x} ]]; then
            result+="${!tag}"
        else
            result+="{{${tag}}}"
        fi
    done

    result+="$rest"

    printf '%s' "$result"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # shellcheck source="./utils/logging.sh"
    source "${UTILS}/logging.sh"

    text='There I {{BLUE}}was{{RESET}}, there I {{GREEN}}was{{RESET}}, ... in the {{BOLD}}{{RED}}jungle{{RESET}}!'

    setup_colors
    log ""
    log "${BOLD}colorize()${RESET} function"
    log "---------------------------"
    log ""
    log "Plain text like this:\n\n\t${text}"
    log ""
    log "Can be converted to color with the ${GREEN}${BOLD}colorize${RESET} function"
    log ""
    log "$(colorize "${text}")"
    remove_colors

    colorize ""
fi
