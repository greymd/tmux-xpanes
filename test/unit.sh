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

oneTimeSetUp(){
  BIN_DIR="${THIS_DIR}/../bin/"
  # Get repository name which equals to bin name.
  # BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
  BIN_NAME="xpanes"
  EXEC="${BIN_DIR}${BIN_NAME}"
  export XDG_CACHE_HOME="${SHUNIT_TMPDIR}/spa ce/.cache"
  export XP_CACHE_HOME="${XDG_CACHE_HOME}/xpanes"
  # shellcheck source=/dev/null
  source "${EXEC}" --dry-run -- -
}

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

test_xpns_clean_session() {
  touch "${XP_CACHE_HOME}/socket"
  xpns_clean_session
  # echo "Remove socket"
  [[ -e "${XP_CACHE_HOME}/socket" ]]
  actual=$?
  expected=1
  assertEquals "$expected" "$actual"

  touch "${XP_CACHE_HOME}/socket.$$"
  touch "${XP_CACHE_HOME}/socket.01234"
  xpns_clean_session

  # echo "Keep ${XP_CACHE_HOME}/socket.$$"
  [[ -e "${XP_CACHE_HOME}/socket.$$" ]]
  actual=$?
  expected=1
  assertEquals "$expected" "$actual"

  # echo "Remove ${XP_CACHE_HOME}/socket.01234"
  [[ -e "${XP_CACHE_HOME}/socket.01234" ]]
  actual=$?
  expected=1
  assertEquals "$expected" "$actual"
}

test_xpns_adjust_col_row () {
  actual=$(xpns_adjust_col_row "" "" 20)
  expected="4 5"
  assertEquals "$expected" "$actual"

  actual=$(xpns_adjust_col_row "" "" 1)
  expected="1 1"
  assertEquals "$expected" "$actual"

  actual=$(xpns_adjust_col_row "" "" 2)
  expected="2 1"
  assertEquals "$expected" "$actual"

  actual=$(xpns_adjust_col_row 6 0 20)
  expected="6 4"
  assertEquals "$expected" "$actual"

  actual=$(xpns_adjust_col_row 5 5 20)
  expected="5 4"
  assertEquals "$expected" "$actual"

  actual=$(xpns_adjust_col_row 2 0 20)
  expected="2 10"
  assertEquals "$expected" "$actual"
}

test_xpns_ceiling () {
  actual=$(xpns_ceiling 11 2)
  expected="6"
  assertEquals "$expected" "$actual"

  actual=$(xpns_ceiling 100 10)
  expected="10"
  assertEquals "$expected" "$actual"
}

test_xpns_divide_equally () {
  actual=$(xpns_divide_equally 10 3)
  expected="4 3 3 "
  assertEquals "$expected" "$actual"

  actual=$(xpns_divide_equally 12 3)
  expected="4 4 4 "
  assertEquals "$expected" "$actual"
}

test_xpns_nums_transpose () {
  actual=$(xpns_nums_transpose 3 2 2 2)
  expected="4 4 1"
  assertEquals "$expected" "$actual"

  actual=$(xpns_nums_transpose 3 1 1 1)
  expected="4 1 1"
  assertEquals "$expected" "$actual"

  actual=$(xpns_nums_transpose 2 2)
  expected="2 2"
  assertEquals "$expected" "$actual"

  actual=$(xpns_nums_transpose 2 1)
  expected="2 1"
  assertEquals "$expected" "$actual"

  actual=$(xpns_nums_transpose 2 1)
  expected="2 1"
  assertEquals "$expected" "$actual"

  actual=$(xpns_nums_transpose 9)
  expected="1 1 1 1 1 1 1 1 1"
  assertEquals "$expected" "$actual"
}

test_xpns_get_window_height_width () {
  export XP_OPT_DEBUG=1

  # Run with parent process
  actual_output=$(xpns_get_window_height_width)
  actual=$?
  ideal_output="^[0-9]+ [0-9]+$"
  if [[ "$actual_output" =~ $ideal_output ]]; then
    expected=0
    assertEquals "$expected" "$actual"
  else
    expected=1
    assertEquals "$expected" "$actual"
  fi

  # Run with pipe
  actual_output=$(seq 10 | cat | cat | xpns_get_window_height_width)
  actual=$?
  ideal_output="^[0-9]+ [0-9]+$"
  if [[ "$actual_output" =~ $ideal_output ]]; then
    expected=0
    assertEquals "$expected" "$actual"
  else
    expected=1
    assertEquals "$expected" "$actual"
  fi
}

test_xpns_set_args_per_pane () {
  XP_ARGS=(1 2 3 4 5 6)
  # set -x
  xpns_set_args_per_pane 3
  # set +x
  assertEquals "1 2 3" "${XP_ARGS[0]}"
  assertEquals "4 5 6" "${XP_ARGS[1]}"
}

test_xpns_set_args_per_pane2 () {
  XP_ARGS=(1 '' 2 '' 3 4)
  xpns_set_args_per_pane 2
  assertEquals "1 " "${XP_ARGS[0]}"
  assertEquals "2 " "${XP_ARGS[1]}"
  assertEquals "3 4" "${XP_ARGS[2]}"
}

# shellcheck source=/dev/null
. "${THIS_DIR}/shunit2/shunit2"
