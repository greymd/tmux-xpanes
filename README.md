# tmssh
ssh multiple servers over multiple tmux panes

# Features
* Split tmux's window into multiple panels and each one has ssh connection.
* It works even if the current shell is already in the tmux session.
* Off course, it works if the current shell is NOT in the tmux session.

# Dependencies
* `bash` 4.x
* `tmux` 2.1

Other versions may work, but author have not confirmed that.

# Install

## 1. Put executable file in your local path.

```
wget https://raw.githubusercontent.com/greymd/tmssh/master/tmssh /usr/local/bin/tmssh
chmod +x /usr/local/bin/tmssh
```

## 2. Install `tmux` if you have not done yet.
Please refer to [here](http://linoxide.com/how-tos/install-tmux-manage-multiple-linux-terminals/).

# Usage

```
$ tmssh USER1@SERVER1 USER2@SERVER2 USER3@SERVER3 ...
```

Example

```
$ tmssh root@192.168.1.2 user@example.com
```

# References
* http://linuxpixies.blogspot.jp/2011/06/tmux-copy-mode-and-how-to-control.html
* https://gist.github.com/dmytro/3984680

# License

The scripts is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
