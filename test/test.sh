#!/bin/bash

# Directory name of this file
TEST_DIR="$(cd $(dirname $0) && pwd)"

BIN_DIR="${TEST_DIR}/../"
# Get repository name which equals to bin name.
BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
EXEC="./${BIN_NAME}"

setUp(){
    cd ${BIN_DIR}
}

test_version() {
    result=`${EXEC} -v`
    echo ${result} | grep -q "${BIN_NAME} .*"
    assertEquals "0" "$?"

    result=`${EXEC} --version`
    echo ${result} | grep -q "${BIN_NAME} .*"
    assertEquals "0" "$?"
}

test_help() {
    result=`${EXEC} -h`
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    result=`${EXEC} --help`
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"
}


. ${TEST_DIR}/shunit2/source/2.1/src/shunit2

