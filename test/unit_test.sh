#!/bin/bash

# Directory name of this file
TEST_DIR="$(cd $(dirname $0) && pwd)"

BIN_DIR="${TEST_DIR}/../"
# Get repository name which equals to bin name.
BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
EXEC="./${BIN_NAME}"

# Load declared functions.
source ${BIN_DIR}${BIN_NAME} --dry-run

test_version(){
    result=`version`
    echo ${result} | grep -q "$0 .*"
    assertEquals "0" "$?"
}

test_generate_window_name(){
    result=`generate_window_name "aaa.bbb.ccc"`
    echo ${result} | grep -Eq 'aaa-[0-9]+'
    echo ${result}
    assertEquals "0" "$?"
}

. ${TEST_DIR}/shunit2/source/2.1/src/shunit2
