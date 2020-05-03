#!/bin/bash

# Let PATH include 'xpanes' and 'tmux-xpanes'.
if ! (type xpanes > /dev/null 2>&1 &&
  type      tmux-xpanes > /dev/null 2>&1); then
  __XPANES_DIR="$(  cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
  export   PATH="$PATH:$__XPANES_DIR/bin"
fi
