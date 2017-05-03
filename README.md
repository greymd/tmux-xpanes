<p align="center">
  <img src="https://raw.githubusercontent.com/wiki/greymd/tmux-xpanes/img/xpanes_logo_1.png" height="206" width="208" />
</p>
<p align="center">
  <a href="https://github.com/greymd/tmux-xpanes/releases/latest"><img src="https://img.shields.io/github/release/greymd/tmux-xpanes.svg" alt="Latest version" /></a>
  <a href="https://travis-ci.org/greymd/tmux-xpanes"><img src="https://travis-ci.org/greymd/tmux-xpanes.svg?branch=master" alt="Build Status" /></a>
  <a href="LICENSE" alt="MIT License"><img src="http://img.shields.io/badge/license-MIT-blue.svg?style=flat" /></a>
  <a href="https://tmux.github.io/"><img src="https://img.shields.io/badge/powered_by-tmux-green.svg" alt="tmux" /></a>
</p>

Ultimate terminal divider powered by tmux.

# Features
* Split tmux's window into multiple panes.
  + Build command lines from given arguments & execute them on the panes.
* It works on both situations.
  + Normal terminal (out of tmux session).
  + In tmux session.

# Requirements

* `bash` (version 3.2 and more)
* `tmux` (version 1.6 and more)

# Installation

## With [Homebrew](https://github.com/Homebrew/brew) (for macOS users)

```sh
# Install
$ brew tap greymd/tools
$ brew install tmux-xpanes

# Uninstall
$ brew uninstall tmux-xpanes
```

## With [zplug](https://zplug.sh) (for zsh users)

If you are using zplug, it is easy and recommended way.
Add those lines to `.zshrc`.

```sh
zplug "greymd/tmux-xpanes", as:command, use:"bin/*"
```

After that, `xpanes` command is yours.

## Manual Installation

If you are not using `zplug` (includeing bash users), execute following commands.

```sh
$ wget https://raw.githubusercontent.com/greymd/tmux-xpanes/master/bin/xpanes -O /usr/local/bin/xpanes
$ chmod +x /usr/local/bin/xpanes
```


# Usage

There are two commands. `xpanes` and `tmux-xpanes`.
`tmux-xpanes` is alias of `xpanes`.

```
Usage:
  xpanes [OPTIONS] [argument ...]
  command ... | xpanes [OPTIONS] [<utility> ...]

OPTIONS:
  -h,--help                    Show this screen.
  -V,--version                 Show version.
  -c <utility>                 Specify <utility> which is executed as a command in each panes. If <utility> is omitted, echo(1) is used.
  -e                           Execute given arguments as is.
  -I <repstr>                  Replacing one or more occurrences of <repstr> in <utility> given by -c option. Default value of <repstr> is {}.
  --ssh                        Let <utility> 'ssh -o StrictHostKeyChecking=no {}'.
  -S <socket-path>             Specify a full alternative path to the server socket.
  -l <layout>                  Specify a layout for a window. Recognized layout arguments are:
                               t    tiled (default)
                               eh   even-horizontal
                               ev   even-vertical
                               mh   main-horizontal
                               mv   main-vertical
  --log[=<directory>]          Enable logging and store log files to ~/.cache/xpanes/logs or given <directory>.
  --log-format=<FORMAT>        File name of log files follows given <FORMAT>.
  -d,--desync                  Make synchronize-panes option off on new window.
  --kill                       Close a pane itself after new window is created.
  --stay                       Do not switch to new window.
```

# Simple example

Try it.

```sh
$ xpanes 1 2 3 4
```

You will get the screen like this.

```
$ echo 1                       │$ echo 2
                               │
                               │
                               │
                               │
                               │
                               │
                               │
-------------------------------+-------------------------------
$ echo 3                       │$ echo 4
                               │
                               │
                               │
                               │
                               │
                               │
                               │
```

# Examples

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

#### Execute different commands on the different panes.

```sh
$ xpanes -I@ -c "@" "top" "vmstat 1" "watch -n 1 free"
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

#### Create multiple windows and make each one devided into multiple panes.

```sh
$ xpanes -c "xpanes  -I@ -c 'echo @' {}" "groupA-host1 groupA-host2" "groupB-host1 groupB-host2 groupB-host3" "groupC-host1 groupC-host2"
```

Result will be this.

| window  | pane1              | pane2              | pane3              |
| ------  | -----              | -----              | -----              |
| window1 | `ssh groupA-host1` | `ssh groupA-host2` | none               |
| window2 | `ssh groupB-host1` | `ssh groupB-host2` | `ssh groupB-host3` |
| window3 | `ssh groupC-host1` | `ssh groupC-host2` | none               |


## Other features

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


#### Use without messing up `PATH`

`xpanes` command is portable command. Even if PATH does not include `xpanes` file, it works.

```sh
$ ./xpanes ARG1 ARG2 ARG3 ...
```

# License

The scripts is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
