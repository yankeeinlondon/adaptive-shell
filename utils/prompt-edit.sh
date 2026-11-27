#!/usr/bin/env bash

# edit_prompt
#
# Edits the current command in VISUAL or EDITOR and puts it back at the
# prompt. Called by the Ctrl+X Ctrl+E binding in Readline or ZLE.
function edit_prompt() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        zle edit-command-line
        return
    fi

    [[ -n "${READLINE_LINE+x}" ]] || return 1
    local edited
    edited=$(
        local prompt_file editor
        prompt_file=$(mktemp "${TMPDIR:-/tmp}/adaptive-prompt.XXXXXXXX") || exit
        trap 'command rm -f -- "${prompt_file}"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM

        printf '%s\n' "${READLINE_LINE}" > "${prompt_file}" || exit
        editor="${VISUAL:-${EDITOR:-vi}}"
        # Editor settings may include arguments. The filename is passed separately.
        if command -v "${editor}" > /dev/null 2>&1; then
            "${editor}" "${prompt_file}" < /dev/tty >&2 || exit
        else
            eval "${editor} \"\${prompt_file}\"" < /dev/tty >&2 || exit
        fi

        # A sentinel keeps the command substitution from stripping newlines.
        command cat -- "${prompt_file}" && printf '.'
    ) || return

    edited="${edited%.}"
    READLINE_LINE="${edited%$'\n'}"
    # Readline tracks the cursor as a byte offset.
    local LC_ALL=C
    READLINE_POINT="${#READLINE_LINE}"
}

# _bind_prompt_edit
#
# Registers the prompt shortcut in the shell's Emacs and vi keymaps.
function _bind_prompt_edit() {
    local keymap
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        if ! zle -l edit-command-line > /dev/null; then
            autoload -Uz edit-command-line || return
            zle -N edit-command-line || return
        fi
        zle -N edit_prompt || return
        for keymap in main emacs viins vicmd; do
            bindkey -M "${keymap}" '^X^E' edit_prompt || return
        done
    else
        for keymap in emacs-standard vi-insert vi-command; do
            if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
                # Bash 3 has no READLINE_LINE. Its native binding runs the saved command.
                bind -m "${keymap}" '"\C-x\C-e": edit-and-execute-command' || return
            else
                bind -m "${keymap}" -x '"\C-x\C-e": edit_prompt' || return
            fi
        done
    fi
}

_bind_prompt_edit
