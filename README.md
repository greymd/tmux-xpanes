# tmssh
SSH multiple servers over multiple tmux panes.

<p align="center">
<img src="./img/tmssh_movie_720.gif" />
</p>

# Features
* Split tmux's window into multiple panes and each one has ssh connection.
* **It works even if the current shell is already in the tmux session.**
* Off course, it works if the current shell is NOT in the tmux session.

# Dependencies
* `bash` 4.x
* `tmux` 1.6 and more

The author has not confirmed other versions, but they may work.

# Install

## 1. Put the executable file in your local path.

```sh
$ wget https://raw.githubusercontent.com/greymd/tmssh/master/tmssh -O /usr/local/bin/tmssh
$ chmod +x /usr/local/bin/tmssh
```

## 2. Install `tmux` if you have not done yet.
Please refer to [here](http://linoxide.com/how-tos/install-tmux-manage-multiple-linux-terminals/).

# Usage

```sh
$ tmssh USER1@SERVER1 USER2@SERVER2 USER3@SERVER3 ...
```

Example

```sh
$ tmssh root@192.168.1.2 user@example.com
```

## Share terminal sessions with multiple different users.

 `~/.tmssh-socket` file will automatically be created when `tmssh` is used.
Importing this socket file, different users can share their screens each other.

* user1

```sh
[user1@host] $ tmssh USER1@SERVER1 USER2@SERVER2 USER3@SERVER3 ...
```

* user2

```sh
[user2@host] $ tmux -S /home/user1/.tmssh-socket attach
```

... then, user1 and user2 can share their screen each other.


## Use without messing up $PATH

```sh
$ wget https://raw.githubusercontent.com/greymd/tmssh/master/tmssh
$ chmod +x ./tmssh
$ ./tmssh USER1@SERVER1 USER2@SERVER2 USER3@SERVER3 ...
```

# References
* http://linuxpixies.blogspot.jp/2011/06/tmux-copy-mode-and-how-to-control.html
* https://gist.github.com/dmytro/3984680

# License

The scripts is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
