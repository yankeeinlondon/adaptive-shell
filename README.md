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

### Adaptive Features

- **Auto Aliasing** - detects some commonly found utilities on a system and uses them to create useful aliases. Examples include:

    - if the **eza** (_or **exa**_) utilities are found on the system then the following aliases will be setup: `ls`, `la`, `ll`, `ld`
    - if the **dust** utility is installed (which improves upon the basic `du` functionality) then a function called `du` will be added to point to `dust` instead
    - if the **bat** utility is installed then an alias for `cat` will be create to redirect it to it's more powerful cousin.
    - if Lazygit is found installed the an alias `lg` will be added

    the full list of auto aliases will be presented when you run the `about` function

- **Auto Binary Paths** - if common folders for binaries exist on your system but are _not_ included in PATH then they will be automatically added.
-
