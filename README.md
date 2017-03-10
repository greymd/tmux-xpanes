[![latest version](https://img.shields.io/github/release/greymd/tmux-xpanes.svg)](https://github.com/greymd/tmux-xpanes/releases/latest)
[![Build Status](https://travis-ci.org/greymd/tmux-xpanes.svg?branch=master)](https://travis-ci.org/greymd/tmux-xpanes)

# `xpanes` powered by [tmux](https://tmux.github.io/)
Build and eXecute command lines on PANES.

# Features
* Split tmux's window into multiple panes.
  + Build command lines from given arguments & execute them on the panes.
* It works on both situations.
  + Normal terminal (out of tmux session).
  + In tmux session.

# Dependencies

* `zsh` (version 4.x, 5.x) or `bash` (version 3.x, 4.x)
* `tmux` (version 1.6 and more)


# Installation

## With [Homebrew](https://github.com/Homebrew/brew) (for macOS users)

```sh
# Install
$ brew tap greymd/tools
$ brew install greymd/tools/tmux-xpanes

# Uninstall
$ brew uninstall greymd/tools/tmux-xpanes
```

## With [zplug](https://zplug.sh) (for zsh users)

If you are using zplug, it is easy and recommended way.
Add those lines to `.zshrc`.

```sh
zplug "greymd/tmux-xpanes", as:command, use:"bin/*"
```

After that, `xpanes` and `tmssh` commands are yours.

## Manual Installation

If you are not using `zplug` (includeing bash users), execute following commands.

```sh
$ wget https://raw.githubusercontent.com/greymd/tmux-xpanes/master/bin/xpanes -O /usr/local/bin/xpanes
$ chmod +x /usr/local/bin/xpanes

# If you want to use `tmssh`, follow those lines also.
$ wget https://raw.githubusercontent.com/greymd/tmux-xpanes/master/bin/tmssh -O /usr/local/bin/tmssh
$ chmod +x /usr/local/bin/tmssh
```


# Usage

There are two commands,

`xpanes` and `tmssh`.

```
$ xpanes --help
Usage:
  xpanes [OPTIONS] [argument ...]

  -h --help                    Show this screen.
  -V --version                 Show version.
  -c utility                   Specify utility which is executed as a command in each panes. If utility is omitted, echo(1) is used.
  -I replstr                   Replacing one or more occurrences of replstr in utility given by -c option.
  -S socket-path               Specify a full alternative path to the server socket.
  -l --log[=<directory>]       Enable logging and store log files to /Users/yasuhiro.yamada/.xpanes-logs or given <directory>.
     --log-format=<FORMAT>     File name of log files follows given <FORMAT>.
  -d --desync                  Make synchronize-panes option off on new window.
```

`tmssh` is the command which has more specific feature of `xpanes`.
It executes `ssh` command to given arguments.

```
Usage:
  tmssh [OPTIONS] [<USER NAME>@]<HOST NAME> [<USER NAME>@<HOST NAME> ...]

OPTIONS:
  -h --help                    Show this screen.
  -v --version                 Show version.
  -S socket-path               Specify a full alternative path to the server socket.
  -l --log[=<directory>]       Enable logging and store log files to /Users/yasuhiro.yamada/.tmssh-logs or given <directory>.
     --log-format=<FORMAT>     File name of log files follows given <FORMAT>.
  -d --desync                  Make synchronize-panes option off on new window.
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
───────────────────────────────┼───────────────────────────────
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

#### Monitor multiple files

```sh
$ xpanes -c "tail -f {}" /var/log/apache/{error,access}.log /var/log/application/{error,access}.log
```

#### Connecting multiple hosts with ssh and **logging operations**.

```sh
$ xpanes --log=~/operation_log -c "ssh {}" user1@host1 user2@host2
```

#### Execute different commands on the different panes.

```sh
$ xpanes -I@ -c "@" "top" "vmstat 1" "watch -n 1 free"
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

 `~/.xpanes-socket` file will automatically be created when `xpanes` is used.
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
