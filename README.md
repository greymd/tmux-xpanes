# xpanes
Execute UNIX commands on multiple tmux panes
more easily, casually, and smarter way.

<p align="center">
<img src="./img/tmssh_movie_720.gif" />
</p>

# Try it

```
$ xpanes 1 2 3 4
```

# Features
* Split tmux's window into multiple panes.
  + Each pane executes given argument & command.
* It works on both situations.
  + Normal terminal (out of tmux session).
  + In tmux session.

# Dependencies
* `bash` 3.x, 4.x
* `zsh` 4.x, 5.x
* `tmux` 1.6 and more

The author has not confirmed other versions, but they may work.

# Install

```sh
$ wget https://raw.githubusercontent.com/greymd/tmssh/master/bin/xpanes -O /usr/local/bin/xpanes
$ chmod +x /usr/local/bin/xpanes
```

# Usage

```
$ xpanes -c "ssh {}" user1@host1 user2@host2
```

```sh
$ tmssh USER1@HOST1 USER2@HOST2 USER3@HOST3 ...
```

### Use without messing up $PATH

```sh
$ ./tmssh USER1@HOST1 USER2@HOST2 USER3@HOST3 ...
```


## Options

```
$ tmssh --help
Usage:
  tmssh [OPTIONS] [<USER NAME>@]<HOST NAME> [<USER NAME>@<HOST NAME> ...]

OPTIONS:
  -h --help                    Show this screen.
  -v --version                 Show version.
  -l --log[=<directory>]       Enable logging and store log files to ~/.tmssh-logs or given <directory>.
     --log-format=<FORMAT>     File name of log files follows given <FORMAT>.
```

### Examples

* Create new window and separate it into two panes.

```
$ tmssh root@192.168.1.2 user@example.com
```

* Four panes.

```
$ tmssh host{1..4}
```


* Logging

With `-l` option, start to saving logs.

```
$ tmssh -l user1@host1 user1@host1
```

For example, following files will be created and each one is corresponding to each pane.

```
~/.tmssh-logs/user1@host1-1.log.2016-01-31_23-59-59.log
~/.tmssh-logs/user1@host1-2.log.2016-01-31_23-59-59.log
```

* Save log files to another directory.

```
$ tmssh -l --log=/tmp/logs user1@host1 user2@host2
/tmp/logs/user1@host1-1.log.2016-01-31_23-59-59.log
/tmp/logs/user2@host2-1.log.2016-01-31_23-59-59.log
will be created as their log files.
```

## Share terminal sessions with others.

 `~/.tmssh-socket` file will automatically be created when `tmssh` is used.
Importing this socket file, different users can share their screens each other.

* user1

```sh
[user1@host] $ tmssh USER1@HOST1 USER2@HOST2 USER3@HOST3 ...
```

* user2

```sh
[user2@host] $ tmux -S /home/user1/.tmssh-socket attach
```

... then, user1 and user2 can share their screen each other.


# References
* http://linuxpixies.blogspot.jp/2011/06/tmux-copy-mode-and-how-to-control.html
* https://gist.github.com/dmytro/3984680

# License

The scripts is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
