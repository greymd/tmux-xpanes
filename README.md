<h1 align="center">
  <img src="https://raw.githubusercontent.com/wiki/greymd/tmux-xpanes/img/xpanes_logo_1.png" height="206" width="208" />
  <h4 align="center">Ultimate terminal divider powered by <a href="https://tmux.github.io/">tmux</a></h2>
</h1>
<p align="center">
  <a href="https://github.com/greymd/tmux-xpanes/releases/latest"><img src="https://img.shields.io/github/release/greymd/tmux-xpanes.svg" alt="Latest version" /></a>
  <a href="https://travis-ci.org/greymd/tmux-xpanes"><img src="https://travis-ci.org/greymd/tmux-xpanes.svg?branch=master" alt="Build Status" /></a>
  <a href="LICENSE" alt="MIT License"><img src="http://img.shields.io/badge/license-MIT-blue.svg?style=flat" /></a>
  <a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=A7ZRLWLDKHK36&source=url"><img src="https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif" alt="Donation" /></a>
</p>


<p align="center">
  <img src="https://raw.githubusercontent.com/wiki/greymd/tmux-xpanes/img/movie_v4.gif" alt="Introduction Git Animation" />
</p>

## TL;DR

#### Ping multiple hosts

```sh
$ xpanes -c "ping {}" 192.168.0.{1..9}
```

#### Connect to multiple hosts over SSH and start logging for each operation

```sh
$ xpanes --log=~/log --ssh user1@host1 user2@host2 user2@host3
```

#### Monitor CPU, Memory, Load, Processes and Disk info every seconds

```sh
$ xpanes -x -e "top" "vmstat 1" "watch -n 1 df"
```

#### Log in to multiple EC2 instances with Session Manager

```sh
$ xpanes -stc 'aws ssm start-session --target {}' i-abcdefg123 i-abcdefg456 i-abcdefg789
```

#### Operate running Docker containers on the interactive screen

```sh
$ docker ps -q | xpanes -s -c "docker exec -it {} sh"
```


# Features
* Split tmux window into multiple panes
  + Build command lines & execute them on the panes
* Runnable from outside of tmux session
* Runnable from inside of tmux session
* Record operation log
* Flexible layout arrangement for panes
  + Select layout presets
  + Set columns or rows as you like
* Display pane title on each pane
* Generate command lines from standard input (Pipe mode)

# Requirements

* Bash (version 3.2 or later)
* tmux (version 1.8 or later)

If you prefer older tmux versions (1.6 and 1.7),
Use stable version [v2.2.3](https://github.com/greymd/tmux-xpanes/tree/v2.2.3).

# Installation

Please refer to [wiki > Installation](https://github.com/greymd/tmux-xpanes/wiki/Installation) in further details. Here is the some examples for installing.

## With [Homebrew](https://github.com/Homebrew/brew) (for macOS users)

```sh
$ brew install tmux-xpanes
```

## With `yum` (For CentOS, RHEL users)

```sh
$ sudo yum install https://github.com/greymd/tmux-xpanes/releases/download/v4.0.0/tmux-xpanes_v4.0.0.rpm
```

## With `apt` (For Ubuntu users)

```sh
# Install `add-apt-repository` command, if necessary.
$ sudo apt install software-properties-common

$ sudo add-apt-repository ppa:greymd/tmux-xpanes
$ sudo apt update
$ sudo apt install tmux-xpanes
```

## With Zsh plugin managers

**Attention:** With this way, please install tmux manually.

Add this line to `~/.zshrc` for [zplug](https://github.com/zplug/zplug).
Zsh-completion for `xpanes` is also available. See [Wiki > Installation](https://github.com/greymd/tmux-xpanes/wiki/Installation).

```sh
zplug "greymd/tmux-xpanes"
```

## Manual Installation

**Attention:** With this way, please install tmux manually.

```sh
# Download with wget
$ wget https://raw.githubusercontent.com/greymd/tmux-xpanes/v4.0.0/bin/xpanes -O ./xpanes

# Put it under PATH and make it executable.
$ sudo install -m 0755 xpanes /usr/local/bin/xpanes
```

# Usage

Two commands `xpanes` and `tmux-xpanes` will be installed. They are actually same commands (`tmux-xpanes` is alias of `xpanes`). Use whichever you like.

```
Usage:
  xpanes [OPTIONS] [argument ...]

Usage(Pipe mode):
  command ... | xpanes [OPTIONS] [<command> ...]

OPTIONS:
  -h,--help                    Display this help and exit.
  -V,--version                 Output version information and exit.
  -c <command>                 Set <command> to be executed in each pane. Default is `echo {}`.
  -B <begin-command>           Run <begin-command> before processing <command> in each pane. Multiple options are allowed.
  -d,--desync                  Make synchronize-panes option off in new window.
  -e                           Execute given arguments as is. Same as `-c '{}'`
  -I <repstr>                  Replacing one or more occurrences of <repstr> in command provided by -c or -B. Default is `{}`.
  -C NUM,--cols=NUM            Number of columns of window layout.
  -R NUM,--rows=NUM            Number of rows of window layout.
  -l <layout>                  Set the layout presets for window layout. Recognized layout arguments are:
                               t    tiled
                               eh   even-horizontal
                               ev   even-vertical
                               mh   main-horizontal
                               mv   main-vertical
  -n <number>                  Set the maximum number of <argument> taken for each pane.
  -s                           Speedy mode: Run command without opening an interactive shell.
  -ss                          Speedy mode AND close a pane automatically at the same time as process exiting.
  -S <socket-path>             Set a full alternative path to the server socket.
  -t                           Display each argument on the each pane's border as their title.
  -x                           Create extra panes in the current active window.
  --log[=<directory>]          Enable logging and store log files to ~/.cache/xpanes/logs or <directory>.
  --log-format=<FORMAT>        Make name of log files follow <FORMAT>. Default is `[:ARG:].log.%Y-%m-%d_%H-%M-%S`.
  --ssh                        Same as `-t -s -c 'ssh -o StrictHostKeyChecking=no {}'`.
  --stay                       Do not switch to new window.
  --bulk-cols=NUM1[,NUM2 ...]  Set number of columns on multiple rows (i.e, "2,2,2" represents 2 cols x 3 rows).
  --debug                      Print debug message.
```

## Getting Started

Try this command line.

```sh
$ xpanes 1 2 3 4
```

You will get the screen like this.

```
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
```

You can split the window into multiple panes successfully, great!
As you can see, each argument of `xpanes` is re-assigned to `echo`'s argument.

Next, let's close those panes.
Don't worry if you are not familiar with key bindings of tmux.
Just type `exit` and "Enter" key to close the panes.

```
    +-------------------------------+-------------------------------+
    │$ exit                         │$ exit                         │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
    │$ exit                         │$ exit                         │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
```

As shown above, input from keyboard is synchronized within multiple panes by default.

#### Suppress input synchronization

To disable the synchronization of keyboard input within panes, use `-d` (or `--desync`)  option. The input is applied to only one of them. Set `tmux synchronized-pane` `on` to re-enable synchronization.

```
$ xpanes -d 1 2 3 4
```

### `-c` option and `-I` option

`-c` option is one of the fundamental options of `xpanes`.
Its argument is used as a command to be executed.
For example, try this one.

```sh
$ xpanes -c 'seq {}' 1 2 3 4
```

You will get the screen like this.

```
    +-------------------------------+-------------------------------+
    │$ seq 1                        │$ seq 2                        │
    │1                              │1                              │
    │                               │2                              │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
    │$ seq 3                        │$ seq 4                        │
    │1                              │1                              │
    │2                              │2                              │
    │3                              │3                              │
    │                               │4                              │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
```

`seq` command which generates sequential numbers is specified by `-c`.
As you can see, `{}` is replaced each arguments. This placeholder can be changed by `-I` option like this.

```sh
$ xpanes -I@ -c 'seq @' 1 2 3 4
```

`echo {}` is used as the default placeholder when no command is specified by `-c` option.

[Brace expansion](https://www.gnu.org/software/bash/manual/html_node/Brace-Expansion.html) provided by Bash or Zsh is very useful to generate sequential numbers or alphabetical characters.

```sh
# Same as $ xpanes 1 2 3 4
$ xpanes {1..4}
```

## Behavior modes

It is good to know about the conditional behavior of `xpanes` before checking further usages.


### [Normal mode1] Outside of tmux session

When the tmux is not open and `xpanes` is executed on the normal terminal, the `xpanes`'s behavior is as follows:

 - It newly creates a tmux session and new window on the session.
 - In addition, it separates the window into multiple panes.
 - Finally, the session will be attached.

### [Normal mode2] Inside of tmux session

When the tmux is already open and `xpanes` is executed on the existing tmux session, the command's behavior is as follows:

 - It newly creates a window **on the existing active session**.
 - In addition, it separates the window into multiple panes.
 - Finally, the window will be active.

### [Pipe mode] Inside of tmux session & Accepting standard input

When `xpanes` accepts standard input (i.e, `xpanes` follows another command and pipe `|`) under **Normal mode2** , `xpanes`'s behavior is going to be the special one called "Pipe mode".
It is documented in the [Pipe mode section](#pipe-mode).

## Further Examples

#### Monitor multiple files

```sh
$ xpanes -c "tail -f {}" /var/log/apache/{error,access}.log /var/log/application/{error,access}.log
```

The result is like this.

```
    +------------------------------------------+------------------------------------------+
    │$ tail -f /var/log/apache/error.log       │$ tail -f /var/log/apache/access.log      │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    +------------------------------------------+------------------------------------------+
    │$ tail -f /var/log/application/error.log  │$ tail -f /var/log/application/access.log │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    +------------------------------------------+------------------------------------------+
```

Hmm? Do you want to monitor those files through the SSH? Just do it.

```sh
# 'ssh user@host' is added.
$ xpanes -c "ssh user@host tail -f {}" \
/var/log/apache/{error,access}.log \
/var/log/application/{error,access}.log
```

#### Connecting multiple hosts over SSH with same user

```sh
$ xpanes -c "ssh myuser@{}" host1 host2
```

```
    +-------------------------------+-------------------------------+
    │$ ssh myuser@host1             │ $ ssh myuser@host2            │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
```

#### Use SSH with ignoring alert message

`--ssh` option is helpful to ignore the alert message from OpenSSH. It is not required to answer yes/no question against it. Use it if you are fully sure that the connection is reliable one.

```sh
$ xpanes --ssh myuser1@host1 myuser2@host2
```

This is same as below.

```
$ xpanes -t -s -c "ssh -o StrictHostKeyChecking=no {}" myuser1@host1 myuser2@host2
```

`-t` and `-s` options are introduced later.

#### Connecting multiple hosts over SSH **AND logging operations**

```sh
$ xpanes --log=~/operation_log -c "ssh {}" user1@host1 user2@host2
```

The result is like this.

```
    +-------------------------------+-------------------------------+
    │$ ssh user1@host1              │ $ ssh user2@host2             │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
```

In addition, log files will be created.

```
$ ls ~/operation_log/
user1@host1-1.log.2017-03-15_21-30-07
user2@host2-1.log.2017-03-15_21-30-07
```

File name format for log file can be specified with `--log-format` option. Please refer to `xpanes --help`.

**Attention:** Logging feature does not work properly with particular tmux versions. Please refer to [wiki > Known Bugs](https://github.com/greymd/tmux-xpanes/wiki/Known-Bugs) in further details.

#### Execute the same sudo command on multiple hosts via SSH, entering your password once

```
$ xpanes -c "ssh -t {} 'sudo some command'" host-{1,2} some-third-host.example.com
```

```
    +------------------------------------+-------------------------------------+
    │$ ssh -t host-1 'sudo some command' │$ ssh -t host-2 'sudo some command'  │
    │                                    │                                     │
    │                                    │                                     │
    │                                    │                                     │
    │                                    │                                     │
    │                                    │                                     │
    │                                    │                                     │
    │                                    │                                     │
    │                                    │                                     │
    │                                    │                                     │
    │                                    │                                     │
    │------------------------------------+-------------------------------------│
    │$ ssh -t some-third-host.example.com 'sudo some command'                  │
    │                                                                          │
    │                                                                          │
    │                                                                          │
    │                                                                          │
    │                                                                          │
    │                                                                          │
    │                                                                          │
    │                                                                          │
    +------------------------------------+-------------------------------------+
```

#### Run commands promtply

`-s` option is useful if you have following issues.

 * It takes long time to open the multiple new panes because default shell loads a bunch of configures (i.e `~/.zshrc` loads something ).
 * If you do not want to leave commands on your shell history.

With `-s` option, `xpanes` does not create a new interactive shell.
Instead, a command is going to be executed as a direct child process of `xpanes`.

Here is the example.

```sh
$ xpanes -s -c "seq {}" 2 3 4 5
```

As you can see, each pane starts from command's result, not shell's prompt like `$ seq ...`.

```
    +------------------------------------------+------------------------------------------+
    │1                                         │1                                         │
    │2                                         │2                                         │
    │Pane is dead: Press [Enter] to exit...    │3                                         │
    │                                          │Pane is dead: Press [Enter] to exit...    │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    +------------------------------------------+------------------------------------------+
    │1                                         │1                                         │
    │2                                         │2                                         │
    │3                                         │3                                         │
    │4                                         │4                                         │
    │Pane is dead: Press [Enter] to exit...    │5                                         │
    │                                          │Pane is dead: Press [Enter] to exit...    │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    │                                          │                                          │
    +------------------------------------------+------------------------------------------+
```

Confirmation message like "Pane is dead..." is displayed when every process ends.
To suppress the message, use `-ss` instead of `-s`.


#### Preprocessing for each pane

`-B` option allow to run another command before processing `-c` option's command.

```sh
$ xpanes -B 'echo Preprocessing' -c 'echo Test' _
```

```
    +-------------------------------+
    │$ echo Preprocessing           │
    │Preprocessing                  │
    │$ echo Test                    │
    │Test                           │
    │                               │
    │                               │
    │                               │
    +-------------------------------+
```

`-B` and `-c` are similar.
However, `-B` can be used multiple times.

```sh
$ xpanes -B 'echo Pre1' -B 'echo Pre2' -B 'echo Pre3' -c 'echo {}' A B C D
```

```
    +-------------------------------+------------------------------+
    │$ echo Pre1                    │$ echo Pre1                   │
    │Pre1                           │Pre1                          │
    │$ echo Pre2                    │$ echo Pre2                   │
    │Pre2                           │Pre2                          │
    │$ echo Pre3                    │$ echo Pre3                   │
    │Pre3                           │Pre3                          │
    │$ echo A                       │$ echo B                      │
    +-------------------------------+------------------------------+
    │$ echo Pre1                    │$ echo Pre1                   │
    │Pre1                           │Pre1                          │
    │$ echo Pre2                    │$ echo Pre2                   │
    │Pre2                           │Pre2                          │
    │$ echo Pre3                    │$ echo Pre3                   │
    │Pre3                           │Pre3                          │
    │$ echo C                       │$ echo D                      │
    +-------------------------------+------------------------------+
```

It is helpful to customize default `xpanes` behavior with `alias`.

Here is the useful example.
Define the alias on your shell's startup file (i.e `~/.bashrc`) like this.

```sh
alias xpanes='xpanes -B "set {}"'
```

After that, execute this command.

```sh
$ xpanes -c 'echo $1-$2-$3' 'A B C' 'E F G' 'H I J' 'L M N'
## Same as:
##    xpanes -B "set {}" -c 'echo $1-$2-$3' 'A B C' 'E F G'
```

```
    +-------------------------------+------------------------------+
    │$ echo $1-$2-$3                │$ echo $1-$2-$3               │
    │A-B-C                          │E-F-G                         │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
    │$ echo $1-$2-$3                │$ echo $1-$2-$3               │
    │H-I-J                          │L-M-N                         │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
```

`A` is assigned to `$1`, and `B` is `$2` as same ... due to `set` command (see [Positional parameters](https://www.gnu.org/software/bash/manual/html_node/Positional-Parameters.html)).
Finally, `$N` variables can be refered by `-c`.

#### Get index number

Here is one more example of `-B`.

Alias:
```sh
_opt='INDEX=`tmux display -pt "${TMUX_PANE}" "#{pane_index}"`'
alias xpanes="xpanes -B '${_opt}'"
```

Command:
```sh
$ xpanes -sc 'echo $INDEX' _ _ _ _
```

Result:
```
    +-------------------------------+------------------------------+
    │$ echo $INDEX                  │$ echo $INDEX                 │
    │0                              │1                             │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
    │$ echo $INDEX                  │$ echo $INDEX                 │
    │2                              │3                             │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
```

As shown above, `$INDEX` has the index number of pane.
This technique is helpful to avoid that all the commands start simultaneously.
To wait each command start every second, just do it with the above alias.

```sh
$ xpanes -B 'sleep $INDEX' -c 'command {}' argA argB argC ...
```


#### Display host always

```sh
$ xpanes -t -c "ping {}" 192.168.1.{5..8}
```

The result is like this.

![png image](https://raw.githubusercontent.com/wiki/greymd/tmux-xpanes/img/ping_pane_title.png)

As you notice, `-t` displays each argument on the each pane border.
It is called "pane title". The pane title is displayed with green background and black characters by default.
See [Environment variables](#shell-variables) section to change the default format.

#### Create new panes on existing window

`-x` option creates extra panes to the window.
New window is not created then.

Here is the example `xpanes` is executed on the one of the three panes.

```
    +-------------------------------+-------------------------------+
    │$                              │$                              │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
    │ $ xpanes -x 4 5 6                                             │
    │                                                               │
    │                                                               │
    │                                                               │
    │                                                               │
    │                                                               │
    │                                                               │
    │                                                               │
    +-------------------------------+-------------------------------+
```

Additional three panes are created.

```
    +-------------------------------+-------------------------------+
    │$                              │$                              │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
    │$ xpanes -x 4 5 6              │$ echo 4                       │
    │$                              │4                              │
    │                               │$                              │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
    │$ echo 5                       │$ echo 6                       │
    │5                              │6                              │
    │$                              │$                              │
    │                               │                               │
    │                               │                               │
    +-------------------------------+-------------------------------+
```

#### Execute different commands on the different panes

`-e` option executes given argument as it is.

```sh
$ xpanes -e "top" "vmstat 1" "watch -n 1 free"
```

Then the result will be like this.

```
    +-------------------------------+------------------------------+
    │$ top                          │$ vmstat 1                    │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
    │$ watch -n 1 free                                             │
    │                                                              │
    │                                                              │
    │                                                              │
    │                                                              │
    │                                                              │
    │                                                              │
    +--------------------------------------------------------------+
```

You will get the same result with this command line.

```sh
$ xpanes -I@ -c "@" "top" "vmstat 1" "watch -n 1 free"
```

## Layout of panes

### Columns and rows

`-C` and `-R` options are useful to change tha layout of panes.

A number of columns can be specified by `-C` (or `--cols`) option.
Here is the example that panes are organized in 2 columns.

```sh
$ xpanes -C 2 AAA BBB CCC DDD EEE FFF GGG HHH III
```

The result is like this.

```
    +------------------------------+------------------------------+
    │$ echo AAA                    │$ echo BBB                    │
    │                              │                              │
    │                              │                              │
    +------------------------------+------------------------------+
    │$ echo CCC                    │$ echo DDD                    │
    │                              │                              │
    │                              │                              │
    +------------------------------+------------------------------+
    │$ echo EEE                    │$ echo FFF                    │
    │                              │                              │
    │                              │                              │
    +------------------------------+------------------------------+
    │$ echo GGG                    │$ echo HHH                    │
    │                              │                              │
    │                              │                              │
    +------------------------------+------------------------------+
```

As you may expect, `-R` (or `--rows`) option can fix the number of rows.

```sh
$ xpanes -R 5 AAA BBB CCC DDD EEE FFF GGG HHH
```

Panes are organized in 5 rows.

```
    +------------------------------+------------------------------+
    │$ echo AAA                    │$ echo BBB                    │
    │                              │                              │
    +------------------------------+------------------------------+
    │$ echo CCC                    │$ echo DDD                    │
    │                              │                              │
    +------------------------------+------------------------------+
    │$ echo EEE                    │$ echo FFF                    │
    │                              │                              │
    +------------------------------+------------------------------+
    │$ echo GGG                                                   │
    │                                                             │
    +-------------------------------------------------------------+
    │$ echo HHH                                                   │
    │                                                             │
    +-------------------------------------------------------------+
```

Even if the number of arguments is not multiple of provided number, the number of panes on each row is adjusted to be as close as possible.

### Set columns in bulk

`--bulk-cols` accepts comma-separated numbers.
Each number is corresponding to the number of columns of each row.

```sh
$ xpanes --bulk-cols=1,3,1,2,5 {A..L}
```

Here is the result.

```
    +-------------------------------------------------------------+
    │$ echo A                                                     │
    │                                                             │
    +-------------------------------------------------------------+
    │$ echo B            │$ echo C            │$ echo D           │
    │                    │                    │                   │
    +-------------------------------------------------------------+
    │$ echo E                                                     │
    │                                                             │
    +-------------------------------------------------------------+
    │$ echo F                      │$ echo G                      │
    │                              │                              │
    +-------------------------------------------------------------+
    │$ echo H     │$ echo I    │$ echo J    │$ echo K   │$ echo L │
    │             │            │            │           │         │
    +-------------------------------------------------------------+
```

The number of argument must equal to the sum of the comma-separated numbers.
In this example, the sum of the numbers of `--bulk-cols` is 12 (1 + 3 + 1 + 2 + 5 = 12) because there are 12 characters from A to L.

### Layout presets

`-l` option is also useful to change the layout of panes.
For example, to line up panes vertically, put `ev` (it is corresponding to `even-vertical` in [tmux manual](http://man7.org/linux/man-pages/man1/tmux.1.html)) followed by `-l`.

```bash
$ xpanes -l ev -c "{}" "top" "vmstat 1" "watch -n 1 df"
```

It would be like this.

```
    +-------------------------------------------------------------+
    │$ top                                                        │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    +-------------------------------------------------------------+
    │$ vmstat 1                                                   │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    +-------------------------------------------------------------+
    │$ watch -n 1 df                                              │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    +-------------------------------------------------------------+
```

With same way, `eh` (`even-horizontal`), `mv`(`main-vertical`) and `mh`(`main-horizontal`) are available. Please refer to `xpanes --help` also.

## Pipe mode

Pipe mode is activated when `xpanes` command is accepting standard input.
With this mode, `xpanes` behaves like UNIX `xargs`.

```sh
# Pipe mode
$ seq 3 | xpanes
```

With this command line, the output would be like this.

```
    +------------------------------+------------------------------+
    │$ echo 1                      │$ echo 2                      │
    │1                             │2                             │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    +------------------------------+------------------------------+
    │$ echo 3                                                     │
    │3                                                            │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    +------------------------------+------------------------------+
```

Pipe mode has two features.

1. `xpanes`'s argument will be the common command line which will be used within all panes (this is same as the `-c` option's argument in Normal mode).
1. Each line provided by standard input is corresponding to the each pane's command line (this is corresponding to normal argument of `xpanes` in Normal mode).


```bash:tmux_session
# The command line generates some numbers.
$ seq 4
1
2
3
4

# Add those numbers to xpanes command.
$ seq 4 | xpanes seq
```

The result will be like this.

```
    +-------------------------------+------------------------------+
    │$ seq 1                        │$ seq 2                       │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
    │$ seq 3                        │$ seq 4                       │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    │                               │                              │
    +-------------------------------+------------------------------+
```

Off-course, `-c` and `-I` options are available.

```sh
$ seq 4 | xpanes -c 'seq {}'
## xpanes seq
##    and
## xpanes -c 'seq {}'
##    are same.
```

However, giving both `-c` and any arguments causes error. Because the command cannot decide which argument should be used.

```bash:tmux_session
$ echo test | xpanes -c 'echo {}' echo
xpanes:Error: Both arguments and other options (like '-c', '-e') which updates <command> are given.
```

### Connecting to multiple hosts given by `~/.ssh/config`

Pipe mode allows you to make combinations between tmux and other general UNIX commands.
For example, let's prepare `~/.ssh/config` file like this.

```text
Host host1
    User user1
    HostName 192.168.0.2
    IdentityFile ~/.ssh/id_rsa

Host host2
    User user2
    HostName 192.168.0.3
    IdentityFile ~/.ssh/id_rsa

Host host3
    User user3
    HostName 192.168.0.4
    IdentityFile ~/.ssh/id_rsa
```

Parse host name with general UNIX commands.

```sh
$ cat ~/.ssh/config | awk '$1=="Host"{print $2}'
host1
host2
host3
```

Giving the results to `xpanes ssh` command.

```sh
$ cat ~/.ssh/config | awk '$1=="Host"{print $2}' | xpanes ssh
```

The results would be like this.

```
    +------------------------------+------------------------------+
    │$ ssh host1                   │$ ssh host2                   │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    │                              │                              │
    +------------------------------+------------------------------+
    │$ ssh host3                                                  │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    │                                                             │
    +------------------------------+------------------------------+
```

## Operate session

### Recover disconnected session

You may restore the tmux session created by `xpanes` even if it is unexpectedly disconnected from your terminal.
`xpanes` creates `~/.cache/xpanes/socket.<PID>` file as socket file by default.

Try to find socket file like this.

```sh
$ ls ~/.cache/xpanes/socket.*
/home/user/.cache/xpanes/socket.1234
```

If you find any socket files, try to attach it.
The session might be recovered.

```sh
$ tmux -S /home/user/.cache/xpanes/socket.1234 attach
```

### Share terminal sessions with others

You can specify the socket file name with `-S` option.
Importing this socket file, different users can share their screens each other.

* user1

```sh
[user1@host] $ xpanes -S /home/user1/mysocket a b c d ...
```

* user2

```sh
[user2@host] $ tmux -S /home/user1/mysocket attach
```

... then, user1 and user2 can share their screen each other.

## Shell variables

`xpanes` refers to following shell variables.
Add the statement to your default shell's
startup file file (i.e `.bashrc`, `.zshrc`) to change them as you like.

### `TMUX_XPANES_EXEC`

**DEFAULT VALUE:** `tmux`

It is preferentially used as a internal `tmux` command.
It is helpful if you want to use specific tmux version for xpanes, or enable specific options always.

Example:

```sh
export TMUX_XPANES_EXEC="/usr/local/bin/tmux1.8 -2"
# => xpanes command calls "/usr/local/bin/tmux1.8 -2" internally.
```

### `TMUX_XPANES_LOG_DIRECTORY`

**DEFAULT VALUE:** `$HOME/.cache/xpanes/logs`

Path to store log files generated by `--log` option.
It is ignored if the path is explicitly given by `--log=`.

### `TMUX_XPANES_LOG_FORMAT`

**DEFAULT VALUE:** `[:ARG:].log.%Y-%m-%d_%H-%M-%S`

Format of the log file name generated by `--log` option.
It is ignored if the format is explicitly given by `--log-format=`.

Example:

```sh
export TMUX_XPANES_LOG_FORMAT="[:ARG:]_mylog.log"
```

### `TMUX_XPANES_PANE_BORDER_FORMAT`

**DEFAULT VALUE:** `#[bg=green,fg=black] #T #[default]`

It defines format of the pane's title.
See [FORMATS section in man of tmux](http://man7.org/linux/man-pages/man1/tmux.1.html#FORMATS) for further details.
It overwrites tmux's [`pane-border-format`](http://man7.org/linux/man-pages/man1/tmux.1.html#OPTIONS) in the `xpanes`'s session.

There are some examples [here](https://github.com/greymd/tmux-xpanes/wiki/Utilize-pane-title).

### `TMUX_XPANES_PANE_BORDER_STATUS`

**DEFAULT VALUE:** `bottom`

It defines location of the pane's title.
It overwrites tmux's [`pane-border-status`](http://man7.org/linux/man-pages/man1/tmux.1.html#OPTIONS) in the `xpanes`'s session.

Example:

```sh
# Change value from bottom to top
export TMUX_XPANES_PANE_BORDER_STATUS="top"
```

## ... and [let's play!](https://github.com/greymd/tmux-xpanes/wiki/Let's-play!)

# Contributing

Please check out the [CONTRIBUTING](CONTRIBUTING.md) about how to proceed.

## Testing

Please note the following points before running the test.

* Run it from **outside of tmux session**
* Set `allow-rename` option **off**

Follow this.

```sh
## Clone repository together with shunit2 (kward/shunit2)
$ git clone --recursive https://github.com/greymd/tmux-xpanes.git
$ cd tmux-xpanes

## Suppress window name change
$ echo 'set-window-option -g allow-rename off' >> ~/.tmux.conf
$ echo 'set-window-option -g automatic-rename off' >> ~/.tmux.conf

## Run smoke test
$ bash test/cases_smoke.sh

## => Testing will start ...
```

# License

The scripts is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


# Donation

If this project help you reduce time, you can give me a cup of coffee :)

<a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=A7ZRLWLDKHK36&source=url" target="_blank" rel="noopener"><img src="https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif" alt="Donation" /></a>
