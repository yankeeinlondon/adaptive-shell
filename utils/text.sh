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

# Guard to prevent circular dependencies
[[ -n "${__TEXT_SH_LOADED:-}" ]] && return
__TEXT_SH_LOADED=1

# shellcheck source="./logging.sh"
source "${UTILS}/logging.sh"
# shellcheck source="./logging.sh"
source "${UTILS}/empty.sh"


# lc <string>
#
# converts the passed in <string> to lowercase
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

# starts_with <look-for> <content>
function starts_with() {
    local -r look_for="${1:?No look-for string provided to starts_with}"
    local -r content="${2:?No content passed to starts_with() fn!}"

    if is_empty "${content}"; then
        debug "starts_with" "starts_with(${look_for}, "") was passed empty content so will always return false"
        return 1;
    fi

    if [[ "${content}" == "${content#"$look_for"}" ]]; then
        debug "starts_with" "false (\"${DIM}${look_for}${RESET}\")"
        return 1; # was not present
    else
        debug "starts_with" "true (\"${DIM}${look_for}${RESET}\")"
        return 0; #: found "look_for"
    fi
}

# strip_before <find> <content>
#
# Retains all the characters after the first instance of <find> is
# found.
#
# Ex: strip_after ":" "hello:world:of:tomorrow" → "world:of:tomorrow"
function strip_before() {
    local -r find="${1:?strip_before() requires that a find parameter be passed!}"
    local -r content="${2:-}"

    echo "${content#*"${find}"}"
}


# strip_before_last <find> <content>
#
# Retains all the characters after the last instance of <find> is
# found.
#
# Ex: strip_after ":" "hello:world:of:tomorrow" → "tomorrow"
function strip_before_last() {
    local -r find="${1:?strip_before_last() requires that a find parameter be passed!}"
    local -r content="${2:-}"

    echo "${content##*"${find}"}"

}


# strip_after <find> <content>
#
# Strips all characters after finding <find> in content inclusive
# of the <find> text.
#
# Ex: strip_after ":" "hello:world:of:tomorrow" → "hello"
function strip_after() {
    local -r find="${1:?strip_after() requires that a find parameter be passed!}"
    local -r content="${2:-}"

    if not_empty "content"; then
        echo "${content%%"${find}"*}"
    else
        echo ""
    fi
}

# strip_after_last <find> <content>
#
# Strips all characters after finding the FINAL <find> substring
# in the content.
#
# Ex: strip_after_last ":" "hello:world:of:tomorrow" → "hello:world:of"
function strip_after_last() {
    local -r find="${1:?strip_after_last() requires that a find parameter be passed!}"
    local -r content="${2:-}"

    if not_empty "content"; then
        echo "${content%"${find}"*}"
    else
        echo ""
    fi
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


# newline_on_word_boundary <content> [length]
#
# Splits the content onto a new line when the character length
# reaches <length> but doesn't split until a word boundary is found.
# If length is not provided, defaults to terminal columns minus 5.
# Preserves escape codes like ${DIM}, ${ITALIC}, ${RESET}, etc.
function newline_on_word_boundary() {
    local -r content="${1:-}"
    local len="${2:-}"

    # Handle empty content early
    if [[ -z "$content" ]]; then
        debug "newline_on_word_boundary()" "received empty content"
        echo ""
        return 0
    fi

    # If no length provided, calculate default from terminal columns minus 5
    if [[ -z "$len" ]]; then
        if [[ -n "${COLUMNS:-}" ]]; then
            len=$((COLUMNS - 5))
            debug "newline_on_word_boundary()" "using COLUMNS env var: $len"
        else
            # Try OSC/CSI query to get terminal size directly
            local cols=""
            if [[ -t 1 ]]; then
                # Save terminal state
                local old_state
                old_state=$(stty -g 2>/dev/null)
                if [[ -n "$old_state" ]]; then
                    # Request terminal size using CSI 18 t sequence
                    stty -echo -icanon time 0 min 0 2>/dev/null
                    printf '\e[18t' >/dev/tty

                    # Read response with timeout (format: ESC[8;rows;colst)
                    local response=""
                    local char=""
                    local count=0
                    while IFS= read -r -n1 -t 0.1 char 2>/dev/null && [[ $count -lt 50 ]]; do
                        response="${response}${char}"
                        [[ "$char" == "t" ]] && break
                        count=$((count + 1))
                    done </dev/tty

                    # Restore terminal state
                    stty "$old_state" 2>/dev/null

                    # Parse response: ESC[8;rows;colst
                    if [[ "$response" =~ \[8\;[0-9]+\;([0-9]+)t ]]; then
                        cols="${BASH_REMATCH[1]}"
                        debug "newline_on_word_boundary()" "got columns from OSC query: $cols"
                    fi
                fi
            fi

            # Fallback to tput if OSC query didn't work
            if [[ -z "$cols" ]] && command -v tput >/dev/null 2>&1; then
                cols=$(tput cols 2>/dev/null)
                debug "newline_on_word_boundary()" "got columns from tput: $cols"
            fi

            # Use discovered columns or fallback to 75
            if [[ -n "$cols" && "$cols" =~ ^[0-9]+$ && "$cols" -gt 5 ]]; then
                len=$((cols - 5))
            else
                len=75  # Fallback to 80 columns - 5
                debug "newline_on_word_boundary()" "using hard-coded fallback: $len"
            fi
        fi
    fi

    # Validate length parameter
    if ! [[ "$len" =~ ^[0-9]+$ ]] || [[ "$len" -le 0 ]]; then
        error "newline_on_word_boundary()" "length must be a positive number, received: $len" 2
        return 2
    fi

    # Process character by character, respecting newlines and escape sequences
    local result=""
    local current_line=""
    local -i pos=0
    local last_word_boundary_pos=-1  # Position of last space/tab in current line
    local last_word_boundary_content=""  # Content up to last word boundary

    while [[ $pos -lt ${#content} ]]; do
        local char="${content:$pos:1}"

        # Handle newlines - output current line and reset
        if [[ "$char" == $'\n' ]]; then
            if [[ -n "$result" || -n "$current_line" ]]; then
                if [[ -n "$result" ]]; then
                    result="${result}"$'\n'
                fi
                result="${result}${current_line}"
            fi
            current_line=""
            last_word_boundary_pos=-1
            last_word_boundary_content=""
            pos=$((pos + 1))
            continue
        fi

        # Handle escape sequences - add them to current line without affecting width
        if [[ "$char" == $'\x1b' ]]; then
            local seq_start=$pos
            pos=$((pos + 1))

            if [[ $pos -lt ${#content} ]]; then
                local next_char="${content:$pos:1}"

                if [[ "$next_char" == '[' ]]; then
                    # CSI sequence
                    pos=$((pos + 1))
                    while [[ $pos -lt ${#content} ]]; do
                        local seq_char="${content:$pos:1}"
                        pos=$((pos + 1))
                        [[ "$seq_char" =~ [A-Za-z~@] ]] && break
                    done
                elif [[ "$next_char" == ']' ]]; then
                    # OSC sequence
                    pos=$((pos + 1))
                    while [[ $pos -lt ${#content} ]]; do
                        local seq_char="${content:$pos:1}"
                        if [[ "$seq_char" == $'\x07' ]]; then
                            pos=$((pos + 1))
                            break
                        elif [[ "$seq_char" == $'\x1b' && $((pos + 1)) -lt ${#content} && "${content:$((pos + 1)):1}" == $'\\' ]]; then
                            pos=$((pos + 2))
                            break
                        fi
                        pos=$((pos + 1))
                    done
                else
                    # Other escape sequence
                    pos=$((pos + 1))
                fi
            fi

            # Add the entire escape sequence to current line
            current_line="${current_line}${content:$seq_start:$((pos - seq_start))}"
            continue
        fi

        # Handle word boundaries (space or tab)
        if [[ "$char" == ' ' || "$char" == $'\t' ]]; then
            current_line="${current_line}${char}"
            # Mark this as a potential break point
            last_word_boundary_pos=${#current_line}
            last_word_boundary_content="$current_line"
            pos=$((pos + 1))

            # Check if we've exceeded the width AFTER adding this space/tab
            local -i current_width
            current_width=$(char_width "$current_line")
            if [[ $current_width -gt $len ]]; then
                # We need to break, but we have a word boundary
                # Break at the last word boundary before this one if available
                if [[ -n "$last_word_boundary_content" ]]; then
                    if [[ -n "$result" ]]; then
                        result="${result}"$'\n'
                    fi
                    # Trim trailing space from the line we're outputting
                    local trimmed="${last_word_boundary_content% }"
                    trimmed="${trimmed%$'\t'}"
                    result="${result}${trimmed}"
                    # Start new line with everything after the boundary
                    current_line="${current_line:$last_word_boundary_pos}"
                    last_word_boundary_pos=-1
                    last_word_boundary_content=""
                fi
            fi
            continue
        fi

        # Regular character - add to current line
        current_line="${current_line}${char}"
        pos=$((pos + 1))

        # Check if we've exceeded the width
        local -i current_width
        current_width=$(char_width "$current_line")
        if [[ $current_width -gt $len ]]; then
            # We've exceeded width - need to find a word boundary to break at
            if [[ $last_word_boundary_pos -gt 0 ]]; then
                # We have a word boundary - break there
                if [[ -n "$result" ]]; then
                    result="${result}"$'\n'
                fi
                # Trim trailing space/tab from the line we're outputting
                local trimmed="${last_word_boundary_content% }"
                trimmed="${trimmed%$'\t'}"
                result="${result}${trimmed}"
                # Start new line with everything after the boundary
                current_line="${current_line:$last_word_boundary_pos}"
                last_word_boundary_pos=-1
                last_word_boundary_content=""
            fi
            # If no word boundary found, keep accumulating (single long word)
        fi
    done

    # Output any remaining content
    if [[ -n "$current_line" ]]; then
        if [[ -n "$result" ]]; then
            result="${result}"$'\n'
        fi
        result="${result}${current_line}"
    fi

    debug "newline_on_word_boundary()" "split content to max width $len"
    echo "$result"
    return 0
}


# char_width <content>
#
# Calculates the visual width (number of columns) of the content.
# This function is aware of:
#
# - ANSI Escape codes for color and formatting (CSI sequences like \e[31m)
# - OSC8 embedded links (\e]8;;URL\e\\)
# - OSC52 clipboard sequences (\e]52;...)
# - Multi-byte UTF-8 characters (approximate handling)
#
# Returns the visual width as a number.
function char_width() {
    # Ensure no debug output leaks
    set +x
    set +v

    local -r content="${1:-}"

    [[ -z "$content" ]] && echo "0" && return 0

    # Remove all escape sequences to get displayable content
    local -i pos=0
    local result=""

    while [[ $pos -lt ${#content} ]]; do
        local char="${content:$pos:1}"

        # Check for ESC character (start of escape sequence)
        if [[ "$char" == $'\x1b' && $((pos + 1)) -lt ${#content} ]]; then
            local next_char="${content:$((pos + 1)):1}"

            # CSI sequence: ESC [ ... letter
            if [[ "$next_char" == '[' ]]; then
                pos=$((pos + 2))
                # Skip until we find the terminating letter
                while [[ $pos -lt ${#content} ]]; do
                    local seq_char="${content:$pos:1}"
                    pos=$((pos + 1))
                    # CSI terminators are in range 0x40-0x7E (@ through ~)
                    if [[ "$seq_char" =~ [A-Za-z~@] ]]; then
                        break
                    fi
                done
                continue
            fi

            # OSC sequence: ESC ] ... BEL or ESC ] ... ESC \
            if [[ "$next_char" == ']' ]]; then
                pos=$((pos + 2))
                # Skip until we find BEL or ESC \
                while [[ $pos -lt ${#content} ]]; do
                    local seq_char="${content:$pos:1}"
                    if [[ "$seq_char" == $'\x07' ]]; then
                        # BEL terminator
                        pos=$((pos + 1))
                        break
                    elif [[ "$seq_char" == $'\x1b' && $((pos + 1)) -lt ${#content} && "${content:$((pos + 1)):1}" == $'\\' ]]; then
                        # ESC \ terminator
                        pos=$((pos + 2))
                        break
                    fi
                    pos=$((pos + 1))
                done
                continue
            fi

            # Other escape sequences (typically 2 characters)
            # Like ESC c (reset), ESC 7 (save cursor), etc.
            pos=$((pos + 2))
            continue
        fi

        # Handle tab characters - expand to TAB_WIDTH columns (default 4)
        if [[ "$char" == $'\t' ]]; then
            local -i tab_width=${TAB_WIDTH:-4}
            local i
            for ((i = 0; i < tab_width; i++)); do
                result="${result} "
            done
            pos=$((pos + 1))
            continue
        fi

        # Regular character - add to result
        result="${result}${char}"
        pos=$((pos + 1))
    done

    # Now count the visual width of the clean content
    # For simplicity, we count characters. This handles multi-byte characters correctly
    # as 1 unit, but treats wide characters (CJK/Emoji) as 1 column instead of 2.
    # This avoids complex and fragile ordinal calculation logic across shells.
    local -i width=${#result}

    debug "char_width" "content length ${#content}, visual width: $width"
    echo "$width"
    return 0
}


# strip_escape_sequences() <content>
#
# Strips all escape sequences from the `content` passed in.
#   - includes all ANSI escape codes for color and formatting
#   - includes all OSC8 sequences for embedded links
#   - includes all OSC52 sequences to copy content to clipboard
function strip_escape_sequences() {
    local -r content="${1:-}"

    [[ -z "$content" ]] && echo "" && return 0

    local -i pos=0
    local result=""

    while [[ $pos -lt ${#content} ]]; do
        local char="${content:$pos:1}"

        # Check for ESC character (start of escape sequence)
        if [[ "$char" == $'\x1b' && $((pos + 1)) -lt ${#content} ]]; then
            local next_char="${content:$((pos + 1)):1}"

            # CSI sequence: ESC [ ... letter
            if [[ "$next_char" == '[' ]]; then
                pos=$((pos + 2))
                # Skip until we find the terminating letter
                while [[ $pos -lt ${#content} ]]; do
                    local seq_char="${content:$pos:1}"
                    pos=$((pos + 1))
                    # CSI terminators are in range 0x40-0x7E (@ through ~)
                    if [[ "$seq_char" =~ [A-Za-z~@] ]]; then
                        break
                    fi
                done
                continue
            fi

            # OSC sequence: ESC ] ... BEL or ESC ] ... ESC \
            if [[ "$next_char" == ']' ]]; then
                pos=$((pos + 2))
                # Skip until we find BEL or ESC \
                while [[ $pos -lt ${#content} ]]; do
                    local seq_char="${content:$pos:1}"
                    if [[ "$seq_char" == $'\x07' ]]; then
                        # BEL terminator
                        pos=$((pos + 1))
                        break
                    elif [[ "$seq_char" == $'\x1b' && $((pos + 1)) -lt ${#content} && "${content:$((pos + 1)):1}" == $'\\' ]]; then
                        # ESC \ terminator
                        pos=$((pos + 2))
                        break
                    fi
                    pos=$((pos + 1))
                done
                continue
            fi

            # Other escape sequences (typically 2 characters)
            # Like ESC c (reset), ESC 7 (save cursor), etc.
            pos=$((pos + 2))
            continue
        fi

        # Regular character - add to result
        result="${result}${char}"
        pos=$((pos + 1))
    done

    debug "strip_escape_sequences" "stripped ${#content} to ${#result} characters"
    echo "$result"
    return 0
}

# is_start_of_escape_sequence <content>
#
# Checks whether the last character in `content` is the beginning
# of an ANSI or OSC escape sequence (ESC character).
# Returns 0 if true, 1 if false.
function is_start_of_escape_sequence() {
    local -r content="${1:-}"

    [[ -z "$content" ]] && return 1

    local -r last_char="${content: -1}"

    # Check if last character is ESC (\x1b)
    if [[ "$last_char" == $'\x1b' ]]; then
        debug "is_start_of_escape_sequence" "found ESC at end"
        return 0
    fi

    return 1
}

# is_part_of_escape_sequence <content>
#
# Checks whether the last character in `content` is _part_ of a ANSI
# or OSC escape sequence (but not necessarily the start).
# Returns 0 if true, 1 if false.
function is_part_of_escape_sequence() {
    local -r content="${1:-}"

    [[ -z "$content" ]] && return 1

    # Look backwards from the end to find if we're in an escape sequence
    local -i pos=${#content}
    local -i found_esc=0

    # Scan backwards up to 50 characters or until we find ESC or a terminator
    local -i scan_limit=$((pos > 50 ? pos - 50 : 0))

    while [[ $pos -gt $scan_limit ]]; do
        pos=$((pos - 1))
        local char="${content:$pos:1}"

        # Found ESC - we're in an escape sequence
        if [[ "$char" == $'\x1b' ]]; then
            found_esc=1
            local next_char="${content:$((pos+1)):1}"

            # Determine sequence type
            if [[ "$next_char" == '[' ]]; then
                # CSI sequence - terminated by a letter (40-126 range, typically A-Z, a-z)
                # Format: ESC [ parameters letter
                local -i check_pos=$((pos + 2))
                while [[ $check_pos -lt ${#content} ]]; do
                    local check_char="${content:$check_pos:1}"
                    # CSI terminators are typically 0x40-0x7E (@ through ~)
                    if [[ "$check_char" =~ [A-Za-z~] ]]; then
                        # Found terminator - check if we're past it
                        if [[ $check_pos -lt $((${#content} - 1)) ]]; then
                            # We're past the sequence end
                            return 1
                        else
                            # Still in the sequence
                            debug "is_part_of_escape_sequence" "in CSI sequence"
                            return 0
                        fi
                    fi
                    check_pos=$((check_pos + 1))
                done
                # No terminator found yet, still in sequence
                debug "is_part_of_escape_sequence" "in incomplete CSI sequence"
                return 0

            elif [[ "$next_char" == ']' ]]; then
                # OSC sequence - terminated by BEL (\x07) or ESC\ (\x1b\)
                # Format: ESC ] parameters BEL or ESC ] parameters ESC \
                local -i check_pos=$((pos + 2))
                while [[ $check_pos -lt ${#content} ]]; do
                    local check_char="${content:$check_pos:1}"
                    if [[ "$check_char" == $'\x07' ]]; then
                        # BEL terminator
                        if [[ $check_pos -lt $((${#content} - 1)) ]]; then
                            return 1  # Past the sequence
                        else
                            debug "is_part_of_escape_sequence" "in OSC sequence"
                            return 0  # At the end
                        fi
                    elif [[ "$check_char" == $'\x1b' ]]; then
                        local next="${content:$((check_pos+1)):1}"
                        if [[ "$next" == '\' ]]; then
                            # ESC\ terminator
                            if [[ $((check_pos + 1)) -lt $((${#content} - 1)) ]]; then
                                return 1  # Past the sequence
                            else
                                debug "is_part_of_escape_sequence" "in OSC sequence"
                                return 0  # At or near the end
                            fi
                        fi
                    fi
                    check_pos=$((check_pos + 1))
                done
                # No terminator found yet
                debug "is_part_of_escape_sequence" "in incomplete OSC sequence"
                return 0
            fi

            # Other escape sequences (typically 2 chars)
            if [[ $((pos + 1)) -ge $((${#content} - 1)) ]]; then
                debug "is_part_of_escape_sequence" "in short escape sequence"
                return 0
            fi
            return 1
        fi

        # If we hit a letter/control char that could terminate a sequence, stop scanning
        if [[ "$char" =~ [A-Za-z] ]] && [[ $found_esc -eq 0 ]]; then
            break
        fi
    done

    return 1
}

# trim_val <value>
#
# Take the content passed to it and then trims all leading and
# trailing whitespace. The trimmed value is returned.
function trim_val() {
  # Usage: trim "   some text   "
  local input="$*"
  # Remove leading and trailing whitespace using parameter expansion
  # (requires Bash 4+)
  input="${input#"${input%%[![:space:]]*}"}"   # remove leading
  input="${input%"${input##*[![:space:]]}"}"   # remove trailing
  echo "$input"
}

# trim_ref <ref>
#
# Take a reference to a variable and changes the variable to
# a string with all leading and trailing whitespace removed.
trim_ref() {
  # Usage: trim_ref var_name
  local var_name="$1"
  local value="${!var_name}"

  # Remove leading whitespace
  value="${value#"${value%%[![:space:]]*}"}"
  # Remove trailing whitespace
  value="${value%"${value##*[![:space:]]}"}"

  # Reassign the trimmed value to the original variable
  printf -v "$var_name" '%s' "$value"
}

# trim <ref_or_value>
#
# Takes either a reference to a variable _or_ textual content as a
# parameter. It then leverages the `trim_ref()` or `trim_val()` functions
# based on the type of parameters you pass it.
trim() {
  # Usage:
  #   trim "  some text  "     → echoes trimmed text
  #   trim var_name             → trims var in-place

  local arg="$1"

  if [[ $# -eq 1 && $arg =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ && ${!arg+_} ]]; then
    # 🧭 Case 1: variable name (in-place)
    local value="${!arg}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf -v "$arg" '%s' "$value"
  else
    # 🧭 Case 2: direct string (echo result)
    local value="$*"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    echo "$value"
  fi
}
