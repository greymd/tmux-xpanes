#!/bin/bash

# Test cases given by this file is not executed on the CI server.
# This file is just used for brief behavior checking during the development.

if [ -n "$BASH_VERSION" ]; then
  # This is bash
  echo "Testing for bash $BASH_VERSION"
  echo "            $(tmux -V)"
fi

# Directory name of this file
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")" && pwd)"

BIN_DIR="${THIS_DIR}/../bin/"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="${BIN_DIR}${BIN_NAME}"

# shellcheck source=/dev/null
source "${EXEC}" --dry-run -- -

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

test_xpns_generate_window_name() {
  actual=$(xpns_generate_window_name 'EMPTY' 'aaa bbb ccc')
  expected="aaa-$$"
  assertEquals "$expected" "$actual"

  actual=$(xpns_generate_window_name 'EMPTY' '')
  expected="EMPTY-$$"
  assertEquals "$expected" "$actual"
}

test_xpns_unique_line () {
  actual="$(echo aaa bbb ccc aaa ccc ccc | xargs -n 1 | xpns_unique_line)"
  expected="aaa-1
bbb-1
ccc-1
aaa-2
ccc-2
ccc-3"
  assertEquals "$expected" "$actual"
}

test_xpns_unique_line () {
  actual=$(echo aaa bbb ccc aaa ccc ccc | xargs -n 1 | xpns_log_filenames '[:ARG:]_[:PID:].log')
  expected="aaa-1_$$.log
bbb-1_$$.log
ccc-1_$$.log
aaa-2_$$.log
ccc-2_$$.log
ccc-3_$$.log"
  assertEquals "$expected" "$actual"
}


test_xpns_value2key () {
  actual=$(printf "%s" ほげほげ | xpns_value2key)
  expected="e381bbe38192e381bbe38192"
  assertEquals "$expected" "$actual"

  actual=$(printf "%s" yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy | xpns_value2key)
  expected="7979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979"
  assertEquals "$expected" "$actual"
}

test_xpns_key2value () {
  actual=$(echo e381bbe38192e381bbe38192 | xpns_key2value)
  expected="ほげほげ"
  assertEquals "$expected" "$actual"

  actual=$(echo 7979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979797979 | xpns_key2value)
  expected="yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
  assertEquals "$expected" "$actual"
}

test_xpns_rm_empty_line() {
  actual="$( echo 'a b c
   
 d e f
	
 f g
' | xpns_rm_empty_line)"
  expected="a b c
 d e f
 f g"
  assertEquals "$expected" "$actual"
}

test_xpns_extract_matched() {
  actual="$(xpns_extract_matched "aaa123bbb" "[0-9]{3}")"
  expected="123"
  assertEquals "$expected" "$actual"
}

# shellcheck source=/dev/null
. "${THIS_DIR}/shunit2/source/2.1/src/shunit2"
