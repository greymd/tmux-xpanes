#!/bin/bash

# Test cases given by this file is not executed on the CI server.
# This file is just used for brief behavior checking during the development.

if [ -n "$BASH_VERSION" ]; then
  # This is bash
  echo "Testing for bash $BASH_VERSION"
  echo "            $(tmux -V)"
fi

# Directory name of this file
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")"; pwd)"

BIN_DIR="${THIS_DIR}/../bin/"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="${BIN_DIR}${BIN_NAME}"

# Load functions.
source ${EXEC} --dry-run A

setUp(){
    echo ">>>>>>>>>>" >&2
}

tearDown(){
    echo "<<<<<<<<<<" >&2
    echo >&2
}

test_xpns_tmux_is_greater_equals() {
  xpns_tmux_is_greater_equals 1.5  1.7
  assertEquals "0" "$?"
  xpns_tmux_is_greater_equals 1.6  1.7
  assertEquals "0" "$?"
  xpns_tmux_is_greater_equals 1.7  1.7
  assertEquals "0" "$?"
  xpns_tmux_is_greater_equals 1.8  1.7
  assertEquals "1" "$?"
  xpns_tmux_is_greater_equals 1.9  1.7
  assertEquals "1" "$?"
  xpns_tmux_is_greater_equals 1.9a 1.7
  assertEquals "1" "$?"
  xpns_tmux_is_greater_equals 2.0  1.7
  assertEquals "1" "$?"
}

. ${THIS_DIR}/shunit2/source/2.1/src/shunit2
