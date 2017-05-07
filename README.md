<h1 align="center">
  <img src="https://raw.githubusercontent.com/wiki/greymd/tmux-xpanes/img/xpanes_logo_1.png" height="206" width="208" />
  <h4 align="center">Ultimate terminal divider powered by tmux.</h2>
</h1>
<p align="center">
  <a href="https://github.com/greymd/tmux-xpanes/releases/latest"><img src="https://img.shields.io/github/release/greymd/tmux-xpanes.svg" alt="Latest version" /></a>
  <a href="https://travis-ci.org/greymd/tmux-xpanes"><img src="https://travis-ci.org/greymd/tmux-xpanes.svg?branch=master" alt="Build Status" /></a>
  <a href="LICENSE" alt="MIT License"><img src="http://img.shields.io/badge/license-MIT-blue.svg?style=flat" /></a>
  <a href="https://tmux.github.io/"><img src="https://img.shields.io/badge/powered_by-tmux-green.svg" alt="tmux" /></a>
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/wiki/greymd/tmux-xpanes/img/movie.gif" alt="Introduction Git Animation" />
</p>

# Features
* Split tmux's window into multiple panes.
  + Build command lines from given arguments & execute them on the panes.
* Runable from tmux session.
* Runnable within tmux session.
* Operation logging.
* Pane layout arrangement.
* Generate command lines from standard-input (Pipe mode).

# Requirements

* `bash` (version 3.2 and more)
* `tmux` (version 1.6 and more)

# Installation

Please refer to [wiki > Installation](https://github.com/greymd/tmux-xpanes/wiki/Installation) in further details. Here is the some examples for installing.

## With `apt` (For Ubuntu users)

```sh
$ sudo add-apt-repository ppa:greymd/tmux-xpanes

$ sudo apt update
$ sudo apt install tmux-xpanes
```

## With [Homebrew](https://github.com/Homebrew/brew) (for macOS users)

```sh
$ brew tap greymd/tools
$ brew install tmux-xpanes
```


## With Zsh plugin managers

Add this line to `~/.zshrc` in case of [zplug](https://zplug.sh).

```sh
zplug "greymd/tmux-xpanes"
```

## Manual Installation

**Attention:** With this way, please install tmux manually.

```bash:Terminal
# Download with wget
$ wget https://raw.githubusercontent.com/greymd/tmux-xpanes/master/bin/xpanes -O ./xpanes

# Put it under PATH and make it executable.
$ sudo install -m 0755 xpanes /usr/local/bin/xpanes
```

# Usage

Two commands `xpanes` and `tmux-xpanes` are installed. They are same commands (`tmux-xpanes` is alias of `xpanes`). Please use as you like.

```
Usage:
  xpanes [OPTIONS] [argument ...]
  command ... | xpanes [OPTIONS] [<utility> ...]
OPTIONS:
  -h,--help                    Show this screen.
  -V,--version                 Show version.
  -c <utility>                 Specify <utility> which is executed as a command in each panes. If <utility> is omitted, echo(1) is used.
  -d,--desync                  Make synchronize-panes option off on new window.
  -e                           Execute given arguments as is.
  -I <repstr>                  Replacing one or more occurrences of <repstr> in <utility> given by -c option. Default value of <repstr> is {}.
  -l <layout>                  Specify a layout for a window. Recognized layout arguments are:
                               t    tiled (default)
                               eh   even-horizontal
                               ev   even-vertical
                               mh   main-horizontal
                               mv   main-vertical
  -S <socket-path>             Specify a full alternative path to the server socket.
  --log[=<directory>]          Enable logging and store log files to ~/.cache/xpanes/logs or given <directory>.
  --log-format=<FORMAT>        File name of log files follows given <FORMAT>.
  --ssh                        Let <utility> 'ssh -o StrictHostKeyChecking=no {}'.
  --stay                       Do not switch to new window.
```

## Simple examples

Try this command line.

```sh
$ xpanes 1 2 3 4
```

You will get the screen like this.

```
$ echo 1                       │$ echo 2
1                              │2
                               │
                               │
                               │
                               │
                               │
                               │
-------------------------------+-------------------------------
$ echo 3                       │$ echo 4
3                              │4
                               │
                               │
                               │
                               │
                               │
                               │
```

Oh, you are not familiar with key bindings of tmux?
Do not worry. Type `exit` and "Enter" key to close the panes.

```
$ exit                         │$ exit
                               │
                               │
                               │
                               │
                               │
                               │
                               │
-------------------------------+-------------------------------
$ exit                         │$ exit
                               │
                               │
                               │
                               │
                               │
                               │
                               │
```

### `-c` option and `-I` option.
`-c` option allow to execute original command line.
For example, try this one.

```sh
$ xpanes -c 'seq {}' 1 2 3 4
```

You will get this screen like this.

```
$ seq 1                        │$ seq 2
1                              │1
                               │2
                               │
                               │
                               │
                               │
                               │
-------------------------------+-------------------------------
$ seq 3                        │$ seq 4
1                              │1
2                              │2
3                              │3
                               │4
                               │
                               │
                               │
```

`seq` command which generates sequencial numbers is specified by `-c`.
As you can see, `{}` is replaced each arguments. This placeholder can be changed by `-I` option like this.

```sh
$ xpanes -I@ -c 'seq @' 1 2 3 4
```

`echo {}` is used as the default placeholder without `-c` option.

[Brace expantion](https://www.gnu.org/software/bash/manual/html_node/Brace-Expansion.html) given by Bash or Zsh is quite useful to generate sequential numbers or alphabetical characters.

```
# Same as $ xpanes 1 2 3 4
$ xpanes {1..4}
```

## Modes of behavior.

Basic usages are explained as shown above. Before showing applicable usages, it is good to know behavior modes of `xpanes`  command.

### Behavior out of the tmux session.

If the tmux is not being opened and `xpanes` command executed on the normal terminal, the command would follow following behavior.

The command newly creates a tmux session and new window on the session.
In addition, it separates the window into multiple panes. Finally, the session will be attached.

### Behavior in the tmux session.

If the tmux is already being opened and `xpanes` command is executed on the tmux, the command's behavior follows follwing.

The command newly creates a window **on the exisging active session**.
In addition, it separates the window into multiple panes.
Finally, the window will be active window.

### [Pipe mode] Behavior in the tmux session & Accepting standard input.

If the tmux is already being opened and `xpanes` command is executed on the tmux (same as above).
And, when the command is accepting standard input ( the command followed by any commands and pipe `|`),
the command's follows "Pipe mode". "Pipe mode" will be instructed later.

## Further Examples

#### Ping multiple hosts

```sh
$ xpanes -c "ping {}" 192.168.1.5 192.168.1.6 192.168.1.7 192.168.1.8
```

The result is like this.

```
$ ping 192.168.1.5             │$ ping 192.168.1.6
                               │
                               │
                               │
                               │
                               │
                               │
                               │
-------------------------------+-------------------------------
$ ping 192.168.1.7             │$ ping 192.168.1.8
                               │
                               │
                               │
                               │
                               │
                               │
                               │
```

#### Monitor multiple files

```sh
$ xpanes -c "tail -f {}" /var/log/apache/{error,access}.log /var/log/application/{error,access}.log
```

The result is like this.

```
$ tail -f /var/log/apache/error.log       │$ tail -f /var/log/apache/access.log
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
------------------------------------------+------------------------------------------
$ tail -f /var/log/application/error.log  │$ tail -f /var/log/application/access.log
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
```

#### Connecting multiple hosts with ssh and **logging operations**.

```sh
$ xpanes --log=~/operation_log -c "ssh {}" user1@host1 user2@host2
```

The result is like this.

```
$ ssh user1@host1              │ $ ssh user2@host2
                               │
                               │
                               │
                               │
                               │
                               │
```

In addition, log files will be created.

```
$ ls ~/operation_log/
user1@host1-1.log.2017-03-15_21-30-07
user2@host2-1.log.2017-03-15_21-30-07
```

File name format for log file can be specified with `--log-format` option. Please refer to `xpanes --help`.

**Attention:** Logging feature does not work properly with specific tmux version. Please refer to [wiki > Known Bugs](https://github.com/greymd/tmux-xpanes/wiki/Known-Bugs) in further details.

#### Execute different commands on the different panes.

`-e` option executes given argument as it is.

```sh
$ xpanes -e "top" "vmstat 1" "watch -n 1 free"
```

```
$ top                          │$ vmstat 1
                               │
                               │
                               │
                               │
                               │
                               │
-------------------------------┴------------------------------
$ watch -n 1 free






```

This is same as here.

```sh
$ xpanes -I@ -c "@" "top" "vmstat 1" "watch -n 1 free"
```

#### Create multiple windows and make each one devided into multiple panes.

```sh
$ xpanes -c "xpanes -I@ -c 'echo @' {} && exit" "groupA-host1 groupA-host2" "groupB-host1 groupB-host2 groupB-host3" "groupC-host1 groupC-host2"
```

Result will be this.

| window  | pane1              | pane2              | pane3              |
| ------  | -----              | -----              | -----              |
| window1 | `ssh groupA-host1` | `ssh groupA-host2` | none               |
| window2 | `ssh groupB-host1` | `ssh groupB-host2` | `ssh groupB-host3` |
| window3 | `ssh groupC-host1` | `ssh groupC-host2` | none               |

#### Share terminal sessions with others.

 `~/.cache/xpanes/socket` file will automatically be created when `xpanes` is used.
Importing this socket file, different users can share their screens each other.
Off course, with you can specify file name with `-S` option.

* user1

```sh
[user1@host] $ xpanes -S /home/user1/mysocket a b c d ...
```

* user2

```sh
[user2@host] $ tmux -S /home/user1/mysocket attach
```

... then, user1 and user2 can share their screen each other.

## Pipe mode

Pipe mode is activated when `xpanes` command is accepting standard input.
With this mode, `xpanes` behaves like UNIX `xargs`.

```bash:tmux_session
# Pipe mode
$ seq 3 | xpanes
```

```
$ echo 1                                  │$ echo 2
1                                         │2
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
                                          │
------------------------------------------+------------------------------------------
$ echo 3
3                                          
                                          
                                          
                                          
                                          
                                          
                                          
                                          
                                          
```

# License

The scripts is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

