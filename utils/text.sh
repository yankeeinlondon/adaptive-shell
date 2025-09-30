#!/usr/bin/env bash

if [ -z "${ADAPTIVE_SHELL}" ] || [[ "${ADAPTIVE_SHELL}" == "" ]]; then
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

# shellcheck source="./logging.sh"
source "${UTILS}/logging.sh"
# shellcheck source="./logging.sh"
source "${UTILS}/empty.sh"


# lc() <str>
#
# converts the passed in <str> to lowercase
function lc() {
    local -r str="${*}"
    debug "lc(${str})" "$(echo "${str}" | tr '[:upper:]' '[:lower:]')"
    echo "${str}" | tr '[:upper:]' '[:lower:]'
}

# contains <find> <content>
# 
# given the "content" string, all other parameters passed in
# will be looked for in this content.
function contains() {
    local -r find="${1}"
    local -r content="${2}"

    if is_empty "$find"; then
        error "contains("", ${content}) function did not receive a FIND string! This is an invalid call!" 1
    fi

    if is_empty "$content"; then
        debug "contains" "contains(${find},"") received empty content so always returns false"
        return 1;
    fi

    if [[ "${content}" =~ ${find} ]]; then
        debug "contains" "found: ${find}"
        return 0 # successful match
    fi

    debug "contains" "did not find '${find}' in: ${content}"
    return 1
}


# ensure_starting <ensure> <content>
#
# ensures that the "content" will start with the <ensure>
function ensure_starting() {
    local -r ensured="${1:?No ensured string provided to ensure_starting}"
    local -r content="${2:?-}"

    if starts_with "${ensured}" "$content"; then
        debug "ensure_starting" "the ensured text '${ensured}' was already in place"
        echo "${content}"
    else
        debug "ensure_starting" "the ensured text '${ensured}' was added in front of '${content}'"

        echo "${ensured}${content}"
    fi

    return 0
}

# has_characters <chars> <content>
#
# tests whether the content has any of the characters passed in
function has_characters() {
    local -r char_str="${1:?has_characters() did not receive a CHARS string!}"
    local -r content="${2:?content expression not passed to has_characters()}"
    # shellcheck disable=SC2207
    # local -ra chars=( $(echo "${char_str}" | grep -o .) )
    # local found="false"

    if [[ "$content" == *["$char_str"]* ]]; then
        debug "has_characters" "does have some of these characters: '${char_str}'"
        return 0
    else
        debug "has_characters" "does NOT have any of these characters: '${char_str}'"
        return 1
    fi
}

# find_replace(find, replace, content)
#
# receives a string or RegExp as the "find" parameter and then uses that
# to replace a substring with the "replace" parameter.
# 
# - if the "find" variable is a RegExp it must have a "$1" section identified
# as the text to replace.
#     - the RegExp `/foobar/` would be invalid and should return an error code
#     - the RegExp `/foo(bar)/` is valid as it defines a section to replace
# - if the "find" variable is a string then it's just a simple 
# find-and-replace-all operation.
find_replace() {
  local find="$1"
  local replace="$2"
  local content="$3"

  # Test whether the "find" argument is in the regex form: /pattern/modifiers
  if printf "%s" "$find" | grep -qE '^/.*/[a-zA-Z]*$'; then
    local pattern modifiers
    pattern=$(printf "%s" "$find" | sed -E 's|^/(.*)/([a-zA-Z]*)$|\1|')
    modifiers=$(printf "%s" "$find" | sed -E 's|^/(.*)/([a-zA-Z]*)$|\2|')

    # Pass the replacement string in the REPL environment variable.
    # This prevents any shell-quoting issues from stripping or mangling ANSI codes.
    REPL="$replace" \
      printf "%s" "$content" | perl -pe 's/'"$pattern"'/$ENV{REPL}/'"$modifiers"
  else
    # For literal string replacement, use Bash's built-in substitution.
    printf "%s" "${content//$find/$replace}"
  fi
}


# indent(indent_txt, main_content)
function indent() {
    local -r indent_txt="${1:?No indentation text passed to indent()!}"
    local -r main_content="${2:?No main content passed to indent()!}"

    printf "%s\n" "$main_content" | while IFS= read -r line; do
        printf "%s%s\n" "${indent_txt}" "${line}"
    done
}

