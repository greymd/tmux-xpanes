#!/bin/bash

if [ -n "$ZSH_VERSION" ]; then
  # This is zsh
  echo "Testing for zsh $ZSH_VERSION"
  echo "            $(tmux -V)"
  # Following two lines are necessary to run shuni2 with zsh
  SHUNIT_PARENT="$0"
  setopt shwordsplit
elif [ -n "$BASH_VERSION" ]; then
  # This is bash
  echo "Testing for bash $BASH_VERSION"
  echo "            $(tmux -V)"
fi

# Directory name of this file
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")"; pwd)"

BIN_DIR="${TEST_DIR}/../"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="./${BIN_NAME}"

# Load declared functions.
source ${BIN_DIR}${BIN_NAME} --dry-run

test_version() {
    result=`__xpanes::version`
    echo ${result} | grep -q "$0 .*"
    assertEquals "0" "$?"
}

test_generate_window_name() {
    result=`__xpanes::generate_window_name "aaa.bbb.ccc"`
    assertEquals "0" "$?"
}

test_get_tmux_conf() {
    result=`__xpanes::get_tmux_conf "pane-base-index"`
    echo ${result} | grep -Eq '^[0-9]+$'
    assertEquals "0" "$?"
}

test_log_filenames() {
    results=($(echo aaa bbb ccc aaa ccc ccc | xargs -n 1 | __xpanes::log_filenames '[:ARG:]_[:PID:]_%Y%m%d.log'))
    echo ${results[0]} | grep -qE 'aaa-1_[0-9]+_[0-9]{4}[0-9]{2}[0-9]{2}.log$'
    assertEquals "0" "$?"
    echo ${results[1]} | grep -qE 'bbb-1_[0-9]+_[0-9]{4}[0-9]{2}[0-9]{2}.log$'
    assertEquals "0" "$?"
    echo ${results[2]} | grep -qE 'ccc-1_[0-9]+_[0-9]{4}[0-9]{2}[0-9]{2}.log$'
    assertEquals "0" "$?"
    echo ${results[3]} | grep -qE 'aaa-2_[0-9]+_[0-9]{4}[0-9]{2}[0-9]{2}.log$'
    assertEquals "0" "$?"
    echo ${results[4]} | grep -qE 'ccc-2_[0-9]+_[0-9]{4}[0-9]{2}[0-9]{2}.log$'
    assertEquals "0" "$?"
    echo ${results[5]} | grep -qE 'ccc-3_[0-9]+_[0-9]{4}[0-9]{2}[0-9]{2}.log$'
    assertEquals "0" "$?"
}

. ${TEST_DIR}/shunit2/source/2.1/src/shunit2
