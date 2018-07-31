#!/bin/bash

# Try this script on the docker container

rm -f "$HOME"/work/*

tmux -S "$HOME"/work/sess new-session -d

printf "%s\\n" A B C D | while read -r f;do
  mkfifo "$HOME/work/$f"
  echo "start to wait: mkfifo $HOME/work/$f"
  _pane_id=$( tmux -S "$HOME"/work/sess splitw -P "grep -q 1 $HOME/work/$f"$'\n'"echo 'This is $f'" )
  echo "start logging: pipe-pane cat >> $HOME/work/$f.log"
  tmux -S "$HOME"/work/sess pipe-pane -t "$_pane_id" "cat >> $HOME/work/$f.log"
done

printf "%s\\n" A B C D | while read -r f;do
  echo "notify to $f"
  printf "%s\\n" 1 > "$HOME/work/$f" &
done

printf "%s\\n" "$HOME/work"/*.log | while read -r file;do
  echo "$file"
  cat "$file"
done

# $ bash fifo.sh
# start to wait: mkfifo /home/docker/work/A
# start logging: pipe-pane cat >> /home/docker/work/A.log
# start to wait: mkfifo /home/docker/work/B
# start logging: pipe-pane cat >> /home/docker/work/B.log
# start to wait: mkfifo /home/docker/work/C
# start logging: pipe-pane cat >> /home/docker/work/C.log
# start to wait: mkfifo /home/docker/work/D
# start logging: pipe-pane cat >> /home/docker/work/D.log
# notify to A
# notify to B
# notify to C
# notify to D
# /home/docker/work/A.log
# This is A
# /home/docker/work/B.log
# This is B
# /home/docker/work/C.log <<<<<<<<<<<<<<<<<<< WTF !?
# /home/docker/work/D.log <<<<<<<<<<<<<<<<<<< WTF !?
