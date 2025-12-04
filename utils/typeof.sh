#!/usr/bin/env bash

# Source guard - prevents re-execution when sourced multiple times
[[ -n "${__TYPEOF_SH_LOADED:-}" ]] && declare -f "typeof" > /dev/null && return
__TYPEOF_SH_LOADED=1

# Stub functions for not-yet-implemented features
# TODO: Implement these properly
is_list() { return 1; }
is_kv_pair() { return 1; }
is_numeric() { [[ "$1" =~ ^[0-9]+$ ]]; }
is_function() { [[ "$(type -t "$1" 2>/dev/null)" == "function" ]]; }
ends_with() {
  local suffix="$1"
  local content="$2"
  [[ "$content" == *"$suffix" ]]
}

# Object prefix/suffix constants (TODO: define these properly)
OBJECT_PREFIX="${OBJECT_PREFIX:-\{}"
OBJECT_SUFFIX="${OBJECT_SUFFIX:-\}}"

function is_bound() {
    allow_errors
    local -n __test_by_ref=$1 2>/dev/null || { debug "is_bound" "unbounded ref";  return 1; }

    local name="${!__test_by_ref}" 2>/dev/null || { debug "is_bound" "unbounded name";  return 1; }
    local -r arithmetic='→+-=><%'
    if has_characters "${arithmetic}" "$1"; then
        debug "is_bound" "${name} is NOT bound"
        return 1
    else
        local idx=${!1} 2>/dev/null
        local a="${__test_by_ref@a}"

        if [[ -z "${idx}${a}" ]]; then
            debug "is_bound" "${name} is NOT bound: ${idx}, ${a}"
            catch_errors
            return 1
        else
            debug "is_bound" "${name} IS bound: ${idx}, ${a}"
            catch_errors
            return 0
        fi
    fi
}


function typeof() {
    allow_errors
    local -n _var_type=$1 2>/dev/null
    catch_errors

    if is_bound _var_type; then
        debug "typeof" "testing bound variable: $1"

        if is_array _var_type; then
            echo "array"
        elif is_assoc_array _var_type; then
            echo "assoc-array"
        elif is_numeric _var_type; then
            echo "number"
        elif is_list _var_type; then
            echo "list"
        elif is_kv_pair _var_type; then
            echo "kv"
        elif is_object _var_type; then
            echo "object"
        elif is_function _var_type; then
            echo "function"
        elif is_empty _var_type; then
            echo "empty"
        else
            echo "string"
        fi
    else
        debug "typeof" "testing unbound variable: $1"
        if is_numeric "$1"; then
            echo "number"
        elif is_list "$1"; then
            echo "list"
        elif is_kv_pair "$1"; then
            echo "kv"
        elif is_object "$1"; then
            echo "object"
        elif is_function "$1"; then
            echo "function"
        elif is_empty "${1}"; then
            echo "empty"
        else
            echo "string"
        fi
    fi
}


function is_not_typeof() {
    allow_errors
    local -n _var_reference_=$1
    local -r test="${2:-is_not_typeof(var,type) did not provide a type!}"
    catch_errors

    if is_bound _var_reference_; then
        if [[ "$test" != "$(typeof _var_reference_)" ]]; then

            return 0
        else
            return 1
        fi
    else
        local val="$1"

        if is_empty "$val"; then
            error "nothing was passed into the first parameter of is_not_typeof()"
        else
            local -r val_type="$(typeof val)"
            if [[ "$val_type" == "$test" ]]; then
                return 1
            else
                return 0
            fi
        fi

    fi

}


function is_typeof() {
    allow_errors
    local -n _var_reference_=$1
    local -r test="$2"

    if is_empty "$test"; then
        panic "Empty value passed in as type to test for in is_typeof(var,test)!"
    fi

    catch_errors

    if is_bound _var_reference_; then
        if [[ "$test" == "$(typeof _var_reference_)" ]]; then
            return 0
        else
            return 1
        fi
    else
        local val="$1"

        if is_empty "$val"; then
            error "nothing was passed into the first parameter of is_not_typeof()"
        else
            local -r val_type="$(typeof "$val")"
            if [[ "$val_type" == "$test" ]]; then
                return 0
            else
                return 1
            fi
        fi
    fi


}


# is_assoc_array() <ref:var>
#
# tests whether the passed in variable reference is
# an associative array.
#
# Note: this only works on later versions of bash which
# definitely means not v3 but also may exclude parts of v4
#
# Note: this check only works after the variable passed in
# is actually set and set -u is in effect
function is_assoc_array() {
    local -r var="$1"
    if has_characters '!@#$%^&()_+' "$var"; then
        return 1;
    fi
    allow_errors
    local -n __var__=$1 2>/dev/null

    if [[ ${__var__@a} = A ]] || [[ ${__var__@a} = Ar ]]; then
        catch_errors
        return 0; # true
    else
        catch_errors
        return 1; # false
    fi
}

# has_newline() <str>
#
# returns 0/1 based on whether <str> has a newline character in it
function has_newline() {
    local str="${1:?no parameter passed into has_newline()}"

    if [[ "$str" ==  *$'\n'* ]]; then
        return 0;
    else
        return 1;
    fi
}

function is_keyword() {
    allow_errors
    local _var=${1:?no parameter passed into is_array}
    local declaration=""
    # shellcheck disable=SC2086
    declaration=$(LC_ALL=C type -t $1)

    if [[ "$declaration" == "keyword" ]]; then
        catch_errors
        return 0
    else
        catch_errors
        return 1
    fi
}

# not_empty() <test>
#
# tests whether the <test> value passed in is an empty string (or is unset)
# and returns 0 when it is NOT empty and 1 when it is.
function not_empty() {
    if [ -z "$1" ] || [[ "$1" == "" ]]; then
        debug "not_empty" "WAS empty, returning 1/false"
        return 1
    else
        debug "not_empty" "was not empty [${#1} chars], returning 0/true"
        return 0
    fi
}


# is_array() <ref:var>
#
# tests whether the passed in variable reference is
# a base array.
#
# Note: this only works on later versions of bash which
# definitely means not v3 but also may exclude parts of v4
#
# Note: this check only works after the variable passed in
# is actually set and set -u is in effect
function is_array() {
    allow_errors
    local -n __var__=$1 2>/dev/null
    local -r test=${__var__@a} 2>/dev/null
    catch_errors

    if is_bound __var__; then
        if not_empty "$test" && [[ $test = a ]]; then
            debug "is_array" "is an array!"
            return 0; # true
        else
            debug "is_array" "' is not an array!"
            return 1; # false
        fi
    else
        debug "is_array" "is_array was called without a reference so returning false!"
        return 1
    fi

}


# NOTE: is_empty() is defined in empty.sh (simpler version without nameref issues)
# The complex version was removed because it caused problems with set -e and namerefs.
# The simple version handles string emptiness which is sufficient for most use cases.
# For array emptiness checks, use is_array first then check ${#array[@]} -eq 0.


# is_shell_alias() <candidate>
#
# Boolean check on whether <candidate> is the name of a
# SHELL alias that exists in the user's terminal.
function is_shell_alias() {
    local candidate="${1:?no parameter passed into is_shell_alias}"
    local -r state=$(manage_err)
    alias "$candidate" 1>/dev/null 2>/dev/null
    local -r error_state="$?"
    set "-${state}" # reset error handling to whatever it had been

    if [[ "${error_state}" == "0" ]]; then
        debug "is_shell_alias" "\"$1\" is a shell alias"
        echo "$declaration"
        return 0
    else
        debug "is_shell_alias" "\"$1\" is ${ITALIC}${RED}not${RESET} a shell alias"

        return 1
    fi
}

# is_object() <candidate>
#
# tests whether <candidate> is an object and returns 0/1
function is_object() {
    allow_errors
    local -n candidate=$1 2>/dev/null
    catch_errors

    if is_bound candidate; then
        if not_empty "$candidate" && starts_with  "${OBJECT_PREFIX}" "${candidate}" ; then
            if not_empty "$candidate" && ends_with "${OBJECT_SUFFIX}" "${candidate}"; then
                debug "is_object" "true"
                return 0
            fi
        fi
    else
        local var="$1"
        if not_empty "$var" && starts_with  "${OBJECT_PREFIX}" "${var}" ; then
            if not_empty "$var" && ends_with "${OBJECT_SUFFIX}" "${var}"; then
                debug "is_object" "true"
                return 0
            fi
        fi
    fi

    debug "is_object" "false"
    return 1
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
