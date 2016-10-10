#!/bin/bash

# Directory name of this file
TEST_DIR="$(cd $(dirname $0) && pwd)"

BIN_DIR="${TEST_DIR}/../"
# Get repository name which equals to bin name.
BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
EXEC="./${BIN_NAME}"

# Load declared functions.
source ${BIN_DIR}${BIN_NAME} --dry-run

test_version() {
    result=`version`
    echo ${result} | grep -q "$0 .*"
    assertEquals "0" "$?"
}

test_generate_window_name() {
    result=`generate_window_name "aaa.bbb.ccc"`
    assertEquals "0" "$?"
}

test_get_tmux_conf() {
    result=`get_tmux_conf "pane-base-index"`
    echo ${result} | grep -Eq '^[0-9]+$'
    assertEquals "0" "$?"
}

test_log_filenames() {
    results=($(echo aaa bbb ccc aaa ccc ccc | xargs -n 1 | log_filenames '[:ARG:]_[:PID:]_%Y%m%d.log'))
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
