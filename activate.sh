#!/bin/bash

# Inspired by https://github.com/greymd/ttcopy/blob/master/ttcp_activate.sh
# Let PATH import 'xpanes' and 'tmux-xpanes' commands.
if ! (type xpanes > /dev/null 2>&1 &&
       type tmux-xpanes > /dev/null 2>&1); then
    __XPANES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")"; pwd)"
    export PATH="$PATH:$__XPANES_DIR/bin"
fi
