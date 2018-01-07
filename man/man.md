XPANES 1 "MAY 2017" "User Commands" ""
=======================================

NAME
----

xpanes, tmux-xpanes - Ultimate terminal divider powered by tmux

SYNOPSIS
--------

### Normal mode

`xpanes` [`OPTIONS`] *argument* ...

### Pipe mode

command ... | `xpanes` [`OPTIONS`] [<*utility*> ...]

DESCRIPTION
-----------

`xpanes` and `tmux-xpanes` (alias of `xpanes`) commands have following features.

* Split tmux window into multiple panes.
  * Build command lines from given arguments & execute them on the panes.
* Runnable from outside of tmux session.
* Runnable from inside of tmux session.
* Record operation log.
* Layout arrangement for panes.
* Generate command lines from standard input (Pipe mode).

OPTIONS
-------

`-h`, `--help`
  Show this screen.

`-V`, `--version`
  Show version.

`-c` <*utility*>
  Specify <*utility*> which is executed as a command in each panes. If <*utility*> is omitted, `echo(1)` is used.

`-d`, `--desync`
  Make synchronize-panes option off on new window.

`-e`
  Execute given arguments as is.

`-I` <*repstr*>
  Replacing one or more occurrences of <*repstr*> in <*utility*> given by -c option. Default value of <*repstr*> is {}.

`-l` <*layout*>
  Specify a layout for a window. Recognized layout arguments are:
    `t`    tiled (default)
    `eh`   even-horizontal
    `ev`   even-vertical
    `mh`   main-horizontal
    `mv`   main-vertical

`-n` <*number*>
  Set the maximum number of arguments taken for each pane of <*utility*>.

`-S` <*socket-path*>
  Specify a full alternative path to the server socket.

`--log`[`=`<*directory*>]
  Enable logging and store log files to ~/.cache/xpanes/logs or given <*directory*>.

`--log-format=`<*FORMAT*>
  File name of log files follows given <*FORMAT*>.

`--ssh`
  Let <*utility*> 'ssh -o StrictHostKeyChecking=no {}'.

`--stay`
  Do not switch to new window.

### *FORMAT*
Default value is "[:ARG:].log.%Y-%m-%d_%H-%M-%S".
  Interpreted sequences are:
    `[:PID:]`   Process id of the tmux session. (e.g, 41531)
    `[:ARG:]`   Argument name

In addition, sequences same as `date(1)` command are available.
  For example:
    `%Y`   year  (e.g, 1960)
    `%m`   month (e.g, 01)
    `%d`   date  (e.g, 31)
    And etc.
Other sequences are available. Please refer to `date(1)` manual.

### ENVIRONMENT VARIABLES
Contents of environment variable `TMUX_XPANES_EXEC` is preferentially used as a internal `tmux` command.
It is helpful if you want to use specific tmux version, or enable specific option always.

MODES
------

### [Normal mode1] Outside of tmux session.

When the tmux is not opened and `xpanes` command is executed on the normal terminal, the command's behavior is as follows:

* The command newly creates a tmux session and new window on the session.
* In addition, it separates the window into multiple panes.
* Finally, the session will be attached.

### [Normal mode2] Inside of tmux session.

When the tmux is already opened and `xpanes` command is executed from within the existing tmux session, the command's behavior is as follows:

* The command newly creates a window **on the existing active session**.
* In addition, it separates the window into multiple panes.
* Finally, the window will be active window.

### [Pipe mode] Inside of tmux session & Accepting standard input.

When the tmux is already being opened and `xpanes` command is executed on the tmux (Normal mode2)and the command is accepting standard input ( the command followed by any other commands and pipe `|`), the command's behavior will be special one called "Pipe mode". Then, `xpanes` behaves like UNIX `xargs(1)`.

Pipe mode has two features.

1. `xpanes` command's argument will be the common command line which will be used within all panes (this is corresponding to the `-c` option's argument in Normal mode).
1. Single line given by standard input is corresponding to the single pane's command line (this is corresponding to normal argument of `xpanes` in Normal mode).

EXAMPLES
-------

#### Simple example

`xpanes` 1 2 3 4

    +-------------------------------+-------------------------------+
    │$ echo 1                       │$ echo 2                       │
    │1                              │2                              │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
    │$ echo 3                       │$ echo 4                       │
    │3                              │4                              │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+

### `-c` option and `-I` option

`xpanes` -I@ -c 'seq @' 1 2 3 4

    +-------------------------------+-------------------------------+
    |$ seq 1                        │$ seq 2                        |
    │1                              │1                              │
    │                               │2                              │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
    |$ seq 3                        │$ seq 4                        |
    │1                              │1                              │
    │2                              │2                              │
    │3                              │3                              │
    │                               │4                              │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+

### Ping multiple hosts

`xpanes` -c "ping {}" 192.168.1.{5..8}

    +-------------------------------+-------------------------------+
    |$ ping 192.168.1.5             │$ ping 192.168.1.6             |
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
    |$ ping 192.168.1.7             │$ ping 192.168.1.8             |
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+

#### Use SSH without key checking

`xpanes` --ssh myuser1@host1 myuser2@host2

    +-----------------------------------------------+------------------------------------------------+
    │$ ssh -o StrictHostKeyChecking=no myuser@host1 │ $ ssh -o StrictHostKeyChecking=no myuser@host2 │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    │                                               │                                                │
    +-----------------------------------------------+------------------------------------------------+

#### Execute different commands on the different panes

`xpanes` -e "top" "vmstat 1" "watch -n 1 free"

    +-------------------------------+------------------------------+
    │$ top                          │$ vmstat 1                    │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
    |$ watch -n 1 free                                             |
    │                                                              │
    │                                                              │
    │                                                              │
    │                                                              │
    │                                                              │
    │                                                              │
    +--------------------------------------------------------------+

#### Change layout of panes

`xpanes` -l ev -c "{}" "top" "vmstat 1" "watch -n 1 df"

    +-------------------------------------------------------------+
    |$ top                                                        |
    |                                                             |
    |                                                             |
    |                                                             |
    |                                                             |
    +-------------------------------------------------------------+
    |$ vmstat 1                                                   |
    |                                                             |
    |                                                             |
    |                                                             |
    |                                                             |
    +-------------------------------------------------------------+
    |$ watch -n 1 df                                              |
    |                                                             |
    |                                                             |
    |                                                             |
    |                                                             |
    +-------------------------------------------------------------+

#### Pipe mode

`seq` 3 | `xpanes`

    +------------------------------+------------------------------+
    |$ echo 1                      │$ echo 2                      |
    |1                             │2                             |
    |                              │                              |
    |                              │                              |
    |                              │                              |
    |                              │                              |
    |                              │                              |
    |                              │                              |
    +------------------------------+------------------------------+
    |$ echo 3                                                     |
    |3                                                            |
    |                                                             |
    |                                                             |
    |                                                             |
    |                                                             |
    |                                                             |
    |                                                             |
    +------------------------------+------------------------------+

#### Pipe mode with an argument

`seq` 4 | `xpanes` seq

    +-------------------------------+------------------------------+
    │$ seq 1                        │$ seq 2                       |
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
    │$ seq 3                        │$ seq 4                       |
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+

AUTHOR AND COPYRIGHT
------

Copyright (c) 2017 Yamada, Yasuhiro <greengregson@gmail.com> Released under the MIT License.
https://github.com/greymd/tmux-xpanes

SEE ALSO
--------

tmux(1)
