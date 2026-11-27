# Adaptive Shell

## Features

This repo presents a powerful means for your **bash** and **zsh** terminals to become super charged. By simply _sourcing_ the `adaptive.sh` you will get:

### Functions

- `h` a history shortcut that provides numeric and string based filtering
- `sys` a summary of your systems network, hardware, etc.
- `about` provides a descriptive summary of the machine you are on which works
_out of the box_ but will also incorporate environment variables such as MACHINE_NAME
and MACHINE_DESC as well as include any content found in the file `${HOME}/about.md`.

### First Run Initialization

To help you get your system up and running with a useful set of utilities you always want to have installed (per OS/distro)

On first run and when you run `adaptive_bootstrap`, Adaptive checks the running
shell and the account's login shell for Bash 3. It can install Bash 4 or newer
through the host's package manager, or reuse a copy you already have. If Bash 3
is your login shell and you choose to keep using Bash, the offer can also make
the newer Bash your login shell. Start a new shell to use the installed version.

### Edit the current command

Adaptive offers prompt editing on first run and when you run `adaptive_bootstrap`,
unless it finds `zoxide` on PATH or `edit_prompt` in the current shell. Saying yes
enables **Ctrl+X, Ctrl+E** for this and future interactive shells. Check
**Prompt editing** in the bootstrap output for the result and to see if the shell
is ready for Cmd+E. If setup is skipped
because zoxide is installed, you can still use Adaptive's binding by adding
the following line after you source Adaptive in `.bashrc` or `.zshrc`.

```sh
source "$ADAPTIVE_SHELL/utils/prompt-edit.sh"
```

The shortcut opens the current command in `VISUAL` or `EDITOR`. In zsh and Bash
4+, the saved text returns to the prompt for review. Bash 3 uses its built-in
`edit-and-execute-command`, which runs the edited command after a successful editor exit.

For **Cmd+E**, configure the terminal app you type into to send the same two
keys. This also works when the shell is on a remote host.

**WezTerm** — add this entry to your `config.keys` table.

```lua
{ key = "e", mods = "SUPER", action = wezterm.action.SendString("\x18\x05") },
```

**Rex** — add this to your `rex/init.lua`.

```lua
rex.action{
  name = "edit_shell_prompt",
  title = "Edit shell prompt",
  run = function()
    rex.client.queue("pane.send_key", { key = "ctrl+x" })
    rex.client.queue("pane.send_key", { key = "ctrl+e" })
  end,
}
rex.bind("cmd+e", "edit_shell_prompt")
```

### Adaptive Features

- **Auto Aliasing** - detects some commonly found utilities on a system and uses them to create useful aliases. Examples include:

    - if the **eza** (_or **exa**_) utilities are found on the system then the following aliases will be setup: `ls`, `la`, `ll`, `ld`
    - if the **dust** utility is installed (which improves upon the basic `du` functionality) then a function called `du` will be added to point to `dust` instead
    - if the **bat** utility is installed then an alias for `cat` will be create to redirect it to it's more powerful cousin.
    - if Lazygit is found installed the an alias `lg` will be added

    the full list of auto aliases will be presented when you run the `about` function

- **Auto Binary Paths** - if common folders for binaries exist on your system but are _not_ included in PATH then they will be automatically added.

- **Install Prompts** - for common tools like `cargo`, `go`, etc., if the command is not installed, a wrapper function is defined that prompts you to install it on first use. Once installed, the wrapper is removed and the real binary takes over.
