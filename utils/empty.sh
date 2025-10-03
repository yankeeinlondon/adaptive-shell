#!/usr/bin/env bash



# not_empty() <test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is NOT empty and 1 when it is.
function not_empty() {
    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "not_empty(${1})" "was empty, returning 1/false"
        return 1
    else
        debug "not_empty(${1})" "was indeed not empty, returning 0/true"
        return 0
    fi
}


# is_empty_string() <test | ref:test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is empty and 1 when it is NOT.
function is_empty_string() {

    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "is_empty(${1})" "was empty, returning 0/true"
        return 0
    else
        debug "is_empty(${1}))" "was NOT empty, returning 1/false"
        return 1
    fi
}


# is_empty() <test | ref:test>
# 
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is empty and 1 when it is NOT.
function is_empty() {
    allow_errors
    local -n __ref__=$1 2>/dev/null
    catch_errors

    if is_bound __ref__; then
        if is_array __ref__; then
            if [[ ${#__ref__[@]} -eq 0 ]]; then
                debug "is_empty" "found an array with no elements so returning true"
                return 0
            else
                debug "is_empty" "found an array with some elements so returning false"
                return 1
            fi
        elif is_assoc_array __ref__; then
            if [[ ${#!__ref__[@]} -eq 0 ]]; then
                debug "is_empty" "found an associative array with no keys so returning true"
                return 0
            else
                debug "is_empty" "found an associative array with some key/values so returning false"
                return 1
            fi
        else
            allow_errors
            local -r try_pass_by_val="$__ref__" 2>/dev/null
            catch_errors
            if [ -z "$try_pass_by_val" ] || [[ "$try_pass_by_val" == "" ]]; then
                debug "is_empty" "was empty, returning 0/true"
                return 0
            else
                debug "is_empty" "was NOT empty, returning 1/false"
                return 1
            fi
        fi

    else 
        if [ -z "$1" ] || [[ "$1" == "" ]]; then
            debug "is_empty(${1})" "was empty, returning 0/true"
            return 0
        else
            debug "is_empty(${1}))" "was NOT empty, returning 1/false"
            return 1
        fi
    fi
    
}
