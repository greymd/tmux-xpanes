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

  actual=$(xpns_generate_window_name 'EMPTY' "$(yes A | head -n 500 | tr -d '\n')")
  expected="$(yes A | head -n 200 | tr -d '\n')-$$"
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

test_xpns_seq() {
  actual="$(xpns_seq 0 3)"
  expected="0
1
2
3"
  assertEquals "$expected" "$actual"

  actual="$(xpns_seq 3 0)"
  expected="3
2
1
0"
  assertEquals "$expected" "$actual"
}

test_xpns_is_valid_layout() {
  ( xpns_is_valid_layout "tiled" )
  actual=$?
  expected=0
  assertEquals "$expected" "$actual"

  ( xpns_is_valid_layout "tile" 2> /dev/null )
  actual=$?
  expected=6
  assertEquals "$expected" "$actual"

  ( xpns_is_valid_layout "" 2> /dev/null )
  actual=$?
  expected=6
  assertEquals "$expected" "$actual"

  ( xpns_is_valid_layout 2> /dev/null )
  actual=$?
  expected=6
  assertEquals "$expected" "$actual"

  ( xpns_is_valid_layout "even-horizontal" )
  actual=$?
  expected=0
  assertEquals "$expected" "$actual"

  ( xpns_is_valid_layout "horizontal" 2> /dev/null )
  actual=$?
  expected=6
  assertEquals "$expected" "$actual"
}

test_xpns_DSL_syntax_check () {
  xpns_DSL_syntax_check "1 - 1 + 1 + 3435 - LP"
  actual=$?
  expected=0
  assertEquals "$expected" "$actual"

  xpns_DSL_syntax_check "1 - 1 + 1 + 3435 - NG"
  actual=$?
  expected=1
  assertEquals "$expected" "$actual"
}

test_xpns_DSL_execute () {
  xpns_DSL_execute "1-2"
  actual=$?
  expected=2
  assertEquals "$expected" "$actual"
}

test_xpns_DSL_result_check () {
  xpns_DSL_result_check "-2"
  actual=$?
  expected=1
  assertEquals "$expected" "$actual"
}

test_xpns_DSL_biggest_pane () {
  local panes="0 12 102
1 11 51
2 11 50
3 24 101
4 23 102
5 23 101"
  actual=$(echo "$panes" | xpns_DSL_biggest_pane)
  expected=3
  assertEquals "$expected" "$actual"

  # If there are multiple biggest size panes, smaller index is selected.
  panes="0 12 102
1 11 51
2 11 50
3 24 101
4 24 101
5 23 101"
  actual=$(echo "$panes" | xpns_DSL_biggest_pane)
  expected=3
  assertEquals "$expected" "$actual"
}

test_xpns_DSL_smallest_pane () {
  local panes="1 12 102
2 11 51
3 11 50
4 24 101
5 23 102
6 23 101"
  actual=$(echo "$panes" | xpns_DSL_smallest_pane)
  expected=3
  assertEquals "$expected" "$actual"

  # If there are multiple smallest size panes, smaller index is selected.
  panes="1 10 50
2 10 50
3 11 50
4 24 101
5 23 102
6 23 101"
  actual=$(echo "$panes" | xpns_DSL_smallest_pane)
  expected=1
  assertEquals "$expected" "$actual"
}


# shellcheck source=/dev/null
. "${THIS_DIR}/shunit2/source/2.1/src/shunit2"
