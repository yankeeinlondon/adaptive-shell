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

# shellcheck source="../utils/logging.sh"
source "${UTILS}/logging.sh"
# shellcheck source="../utils/color.sh"
source "${UTILS}/color.sh"



echo "Testing functions in color.sh"
echo ""

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

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

    log ""
    log "${BOLD}rgb_text()${RESET} function"
    log "---------------------------"
    log "Beyond just using the ANSI escape color sequences that variables like \${RED}"
    log "provide the ${BOLD}${GREEN}rgb_text${RESET} function can create text in any RGB value."
    log ""
    log "For instance \`${BLUE}rgb_test '242 81 29' 'hello world'${RESET}\` will output $(rgb_text "242 81 29" "hello world")"
    log "and \`${BLUE}rgb_test '242 81 29 / 71 49 55' 'hello world'${RESET}\` will output $(rgb_text "242 81 29 / 71 49 55" "hello world")."
    log ""
    log "There are a number of shortcut functions which describe specific colors ("
    log "including the two above):"
    log ""
    log "  $(orange "orange") $(orange_backed " orange_backed ") $(tangerine "tangerine") $(tangerine_backed " tangerine_backed ") $(yellow "yellow") $(yellow_backed " yellow backed ")"
    log "  $(red "red") $(red_backed " red_backed ") $(dark_red "dark_red") $(dark_red_backed " dark_red_backed ") "
    log "  $(purple "purple") $(purple_backed " purple_backed ") $(light_purple_backed " light_purple_backed ")"
    log "  $(green "green") $(green_backed " green_backed ") $(dark_green "dark_green") $(dark_green_backed " dark_green_backed ")"
    log "  $(blue "blue") $(blue_backed " blue_backed ") $(slate_blue "slate_blue") $(slate_blue_backed " slate_blue_backed ")"
    log ""
    log "  $(black_backed " black_backed ") $(white_backed " white_backed ") $(light_gray_backed " light_gray_backed ") $(gray_backed " gray_backed ") $(dark_gray_backed " dark_gray_backed ")"
    log ""
    log "the shortcut functions above all colorize the first parameter passed but append"
    log "the second parameter passed as plain text. In addition to these there are some"
    log "additional shortcut functions which only define a background (although the "
    log "text included in the parameter can have text coloring escape codes):"
    log ""
    log "  $(bg_light_gray " bg_light_gray ") $(bg_gray " bg_gray ") $(bg_dark_gray " bg_dark_gray ") "
    log "  $(bg_light_blue " bg_light_blue ") $(bg_blue " bg_blue ") $(bg_dark_blue " bg_dark_blue ") "
    log "  $(bg_light_green " bg_light_green ") $(bg_green " bg_green ") $(bg_dark_green " bg_dark_green ") "
    log "  $(bg_light_yellow " ${BLACK}bg_light_yellow ") $(bg_yellow " ${BLACK}bg_yellow ") $(bg_dark_yellow " ${BLACK}bg_dark_yellow ") "

    remove_colors
fi
