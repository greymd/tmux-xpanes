#!/bin/bash

# Inspired by https://github.com/greymd/ttcopy/blob/master/ttcp_activate.sh
# Let PATH import 'xpanes' and 'tmux-xpanes' commands.
if ! (type xpanes > /dev/null 2>&1 &&
       type tmux-xpanes > /dev/null 2>&1); then
    XP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")"; pwd)"
    export PATH="$PATH:$XP_DIR/bin"
fi
