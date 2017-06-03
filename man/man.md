XPANES 1 "MAY 2017" "User Commands" ""
=======================================

NAME
----

tmux-xpanes, xpanes - Ultimate terminal divider powered by tmux

SYNOPSIS
--------

### Normal mode

`xpanes` [`OPTIONS`] *argument* ...

### Pipe mode

command ... | `xpanes` [`OPTIONS`] [<*utility*> ...]

DESCRIPTION
-----------

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
Default value is "[:ARG:].log.%Y-%m-%d_%H-%M-%S"
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


AUTHOR AND COPYRIGHT
------

Copyright (c) 2017 Yamada, Yasuhiro <greengregson@gmail.com> Released under the MIT License.
https://github.com/greymd/tmux-xpanes

SEE ALSO
--------

tmux(1)
