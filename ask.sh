#!/usr/bin/env bash

# shellcheck source="./shared.sh"
source "./shared.sh"

function default_validator () {
    return 0;
}

# exit_ask <msg> <is_error>
function exit_ask() {
    local -r msg="${1:-Goodbye}"

    clear
    log ""
    echo "${msg}"
    
    exit 0
}

function text_confirm() {
    local -r question="${1:?text_confirm() did not get the question passed to it}"
    local -r default="${2:-y}"
    local response

    if [[ $(lc "${default}") == "y" ]]; then
        read -rp "${question} (Y/n)" response >/dev/null
    else
        read -rp "${question} (y/N)" response >/dev/null
    fi

    if [[ $(lc "$default") == "y" ]];then
        # local outcome=
        local -i resp
        if [[ $(lc "$response") == "n" ]] || [[ $(lc "$response") == "no" ]]; then
            resp=1
        else
            resp=0
        fi        

        debug "text_confirm" "question '${question}'='${response}', with ${ITALIC}default${RESET} of 'yes' -> '$(yes_no "$resp")'"

        return $resp

    else
        local -i resp
        if [[ $(lc "$response" == "y") ]] || [[ $(lc "$response") == "yes" ]]; then
            resp=0
        else
            resp=1
        fi

        debug "text_confirm" "question '${question}'='${response}', with ${ITALIC}default${RESET} of 'no' -> '$(yes_no "$resp")'"

        return $resp
    fi
}

# ask
#
# determines which TUI to use
function ask() {
    if has_command "whiptail"; then
        debug "ask" "using whiptail for TUI"
        whiptail "${@}"
    elif has_command "dialog"; then
        debug "ask" "using Display for TUI"
        display "${@}"
    fi
}

function tui() {
    local var

    if has_command "whiptail"; then
        var="whiptail"
    elif has_command "dialog"; then
        var="dialog"
    else 
        var="none"
    fi

    echo "${var}"
}

# ask_password <obj[ title, backmsg, height, width, list   ]  >
#
# 
function ask_radiolist() {
    # shellcheck disable=SC2178
    local -n data=$1

    if ! is_bound data; then
        panic "Called for a radiolist dialog and didn't bind a configuration object to the request!"
    fi

    local -r title="${data["title"]}"
    local -r backmsg="${data["backmsg"]:-Moxy}"
    local -r height="${data["height"]:-23}"
    local -r width="${data["width"]:-60}" 
    local -r radio_height="${data["radio_height"]:-12}"
    local -ra choices="${data["choices"]}"
    local -r exit_msg="${data["exit_msg"]:-Goodbye}"
    local -ra params=(
        "--backtitle \"${backmsg}\""
        "--radiolist \"${title}\" ${height} ${width} ${radio_height}"
        "${choices[*]} 3>&2 2>&1 1>&3"
    )

    local -r tool="$(tui)"

    if [[ "$tool" == "dialog" ]]; then 
        cmd="dialog ${params[*]}"
    elif [[ "$tool" == "whiptail" ]]; then
        cmd="whiptail ${params[*]}" 
    else
        error "can't ask for password as no TUI is available [${tool}]"
        exit 1
    fi
    debug "ask_radiolist" "asking for radiolist with: ${cmd}"
    local -r choice=$(eval "$cmd") || exit_ask "$exit_msg"

    echo "${choice}"
}

# ask_yes_no() <[ title, backmsg, height, width, yes, no ]>
#
# creates a dialog box with a yes/no dialog
function ask_yes_no() {
    # shellcheck disable=SC2178
    local -n data=$1
    local -r title="${data["title"]}"
    local -r backmsg="${data["backmsg"]}"
    local -r height="${data["height"]}"
    local -r width="${data["width"]}" 
    local -r yes="${data["yes"]}"
    local -r no="${data["no"]}"
    local -r exit_msg="${data["exit_msg"]:-Goodbye}"
    local -ra params=(
        "--backtitle \"${backmsg}\""
        "--yesno \"${title}\" ${height} ${width}"
        "3>&2 2>&1 1>&3"
    )

    local -r tool="$(tui)"

    if [[ "$tool" == "dialog" ]]; then 
        cmd="dialog ${params[*]}"
    elif [[ "$tool" == "whiptail" ]]; then
        cmd="whiptail ${params[*]}" 
    else
        error "can't ask for password as no TUI is available [${tool}]"
        exit 1
    fi
    debug "ask_yes_no" "asking confirmation on: ${title}"
    eval "$cmd"

    return $?
}

# ask_password <title> <height> <width> <ok> <cancel> <exit>
function ask_password() {
    local -r title="${1:?No title provided to ask_yes_no()}"
    local -r height="${2:?No height provided to ask_yes_no()}"
    local -r width="${3:?No width provided to ask_yes_no()}"
    local -r ok_btn="${4:-Ok}"
    local -r cancel_btn="${5:-Cancel}"
    local -r exit_msg="${6:-Goodbye}"
    local -r tool="$(tui)"
    local choice

    if [[ "$tool" == "dialog" ]]; then 
        choice=$(
            dialog --ok-label "${ok_btn}" --cancel-label "${cancel_btn}" --passwordbox "${title}" "${height}" "${width}"  3>&2 2>&1 1>&3
        ) || exit_ask "${exit_msg}" "false"
    elif [[ "$tool" == "whiptail" ]]; then 
        choice=$(
            whiptail --ok-btn "${ok_btn}" --cancel-btn "${cancel_btn}" --passwordbox "${title}" "${height}" "${width}"  3>&2 2>&1 1>&3
        ) || exit_ask "${exit_msg}" "false"
    else
        error "can't ask for password as no TUI is available [${tool}]"
        exit 1
    fi

    if [ "${#choice}" -lt 8 ]; then
        log ""
        log ""
        error "The key you passed in was too short [${#choice}], please refer to the Promox docs for how to generate the key and test it out with Postman or equivalent if you're unsure if it's right"
        log ""
        exit 1
    else 
        echo "${choice}"
    fi
}

function was_cancelled() {
    local -r outcome="$1"

    if not_empty "$outcome" && [[ "$outcome" == "${CANCELLED}" ]]; then
        return 0
    else 
        return 1
    fi
}

# ask_inputbox {title|height|width|ok|cancel|exit}
function ask_inputbox() {
    allow_errors
    # shellcheck disable=SC2178
    local -n data=$1
    catch_errors

    if ! is_bound data; then
        panic "Call to ask_inputbox() received without any parameter configuration passed in!" 1
    elif is_not_typeof data "assoc-array"; then
        panic "ask_inputbox() expects an associative array to be passed in for configuration purposes but got '$(typeof data)' instead!"
        exit 1
    fi

    local -r title="${data["title"]}"
    local -r backmsg="${data["backmsg"]}"
    local -r height="${data["height"]}"
    local -r width="${data["width"]}" 
    local -r ok="${data["ok"]}"
    local -r cancel="${data["cancel"]}"
    local -r on_cancel="${data["on_cancel"]:-exit}"
    local -r exit_msg="${data["exit_msg"]:-Goodbye}"
    
    local -r tool="$(tui)"
    catch_errors

    local buttons
    if [[ "${tool}" == "dialog" ]]; then
        buttons="--ok-label \"${ok}\" --cancel-label \"${cancel}\""
    else
        buttons="--ok-btn \"${ok}\" --cancel-btn \"${cancel}\""
    fi
    local -ra params=(
        "--backtitle \"${backmsg}\""
        "${buttons}"
        "--inputbox \"${title}\" ${height} ${width}"
        "3>&2 2>&1 1>&3"
    )


    if [[ "$tool" == "dialog" ]]; then 
        cmd=$(eval "dialog ${params[*]} || echo ${CANCELLED}")
    elif [[ "$tool" == "whiptail" ]]; then
        cmd=$(whiptail "${params[*]}") || "${CANCELLED}"
    else
        error "can't ask for password as no TUI is available [${tool}]"
        exit 1
    fi

    if was_cancelled "${cmd}"; then
        if [[ "$on_cancel" == "exit" ]]; then
            clear
            exit_ask "${exit_msg}"
        else
            echo "${CANCELLED}"
            return 0
        fi
    fi
    
    printf "%s" "$cmd"
}


# ask_to_continue <continue msg> <exit msg> <y|n> <err>
function ask_to_continue() {
    # shellcheck disable=SC2178
    local -n data=$1
    local -r continue_msg="${data["continue"}]}"
    local -r exit_msg="${data["exit_msg"}]}"
    local -r def_val="${data["def_val"}]}"


    if [[ "$def_val" == "y" ]]; then 
        read -r -p "Continue? <Y/n> " prompt
        if echo "$prompt" | grep -Eq "^(n|no)$"; then
            log "${exit_msg}"
            exit_ask "${exit_msg}"
        else
            log "${continue_msg}"
            log ""
        fi

    else
        read -r -p "Continue? <y/N> " prompt
        if echo "$prompt" | grep -Eq "^(y|yes)$"; then
            log "${exit_msg}"
            exit 1
        else
            log "${continue_msg}"
            log ""
        fi
    fi
}


# ask_for_text <id> <title> <question> <[height]> <[width]> <[def_value]> <[validator fn]>
#
# interactively asks user for a text input and returns key/value pair to the
# "answers" variable which it assumes to be an existingly scoped local variable
#
# by default any text provided by the user is considered valid but the caller may
# pass in a validator function to limit this.
function ask_for_text() {
    local -r title="${1:?no title passed to ask_for_text()}"
    local -r question="${2:?no question text passed to ask_for_text()}"
    local -r height="${3:8}"
    local -r width="${4:60}"
    local -r def_value="${5:-}"
    local -rf validate="${6:-$default_validator}"

    if ui_availability; then
        local -r ui_pkg="$(ui_availability)"
        debug "ask_for_text" "\"${title}\" to be asked for text input by \"${ui_pkg}\""

        allow_errors
        def_value=$(${ui_pkg} --inputbox \""${question}"\" "${height}" "${width}" "${def_value}" --title "${title}" 3>&1 1>&2 2>&3)
        local -r cmd_response=$?
        catch_errors

        if ! ${cmd_response}; then
            debug "ask_for_text" "user opted to cancel the process"
            # shellcheck disable=SC2086
            return ${ERR_USER_CANCEL}
        fi

    else
        debug "ask_for_text" "\"${title}\" to be asked for text input in plain text"
        def_value=$(read -r -p "${BOLD}${title}${RESET}\n${question} [${value}]")
    fi

    if "$validate" "${value}"; then
        debug "ask_for_text" "valid text being returned: ${value}"
        echo "${value}"
        return 0
    else
        debug "ask_for_text" "invalid text: ${value}"
        # shellcheck disable=SC2086
        return ${ERR_INVALID_TEXT_RESPONSE}
    fi
}

function ask_from_menu() {
    local -r title="${1:?no title passed to ask_for_text()}"
    local -r question="${2:?no question text passed to ask_for_text()}"
    local -r choices="${3:?no choices provided to ask_for_menu}"

    local -r num_choices=iterable "count"
    local dialog_height=$(( num_options+2 ))
    if [[ dialog_height -gt 20 ]]; then
        dialog_height=$(( 20 ))
    fi
    local -r height="${3:8}"
    local -r width="${4:60}"
    local -r def_value="${5:-}"
    local -r validate="${6:-$default_validator}"
}

function ask_select_one() {
    local -r answers="${1:the dictionary of answers was not provided to ask_select_one}"
    local -r question="${2:the question text was not provided to ask_select_one}"
    local -r options="${3:the list of options was not provided to ask_select_one}"
    local -r value="${4:-$(first "$answers")}"

    echo "TODO"
}

function ask_select_many() {
    local -rA answers="${1:the dictionary of answers was not provided to ask_select_many}"
    local -r question="${2:the question text was not provided to ask_select_many}"
    local -r options="${3:the list of options was not provided to ask_select_many}"
    local default_value="${4}"

    echo "TODO"
}


