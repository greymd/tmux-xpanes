#!/usr/bin/env bash

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

#test_xpns_log() {
#local tmpfile=$(mktemp)
#xpns_log "info" "This is an info message" > "$tmpfile" 2>&1
#  local actual=$(cat "$tmpfile")
#  rm "$tmpfile"
#expected="[unit.sh:info] This is an info message  "
#assertEquals "$expected" "$actual"
#
#xpns_log "warning" "This is a warning message" > "$tmpfile" 2>&1
#  local actual=$(cat "$tmpfile")
#  rm "$tmpfile"
#expected="[unit.sh:warning]: This is a warning message"
#assertEquals "$expected" "$actual"
#
#xpns_log "error" "This is an error message" > "$tmpfile" 2>&1
#  local actual=$(cat "$tmpfile")
#  rm "$tmpfile"
#expected="[unit.sh:error] This is an error message" 
#assertEquals "$expected" "$actual"
#
##should not trigger without XP_OPT_DEBUG=1
#XP_OPT_DEBUG=0 xpns_log "debug" "This is a debug message"  > "$tmpfile" 2>&1
#  local actual=$(cat "$tmpfile")
#  rm "$tmpfile"
#expected=""
#assertEquals "$expected" "$actual"
#
#xpns_log "nonlogleveltype" "string" > "$tmpfile" 2>&1
#  local actual=$(cat "$tmpfile")
#  rm "$tmpfile"
#expected="[unit.sh:internal error] invalid log type, if you get this error. Please file an issue on github: https://github.com/greymd/tmux-xpanes/issues"
#assertEquals "$expected" "$actual"
#}

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

test_xpns_merge_array_elements () {
  TEST_ARR=(1 2 3 4 5 6)
  # set -x
  xpns_merge_array_elements 3 'TEST_ARR'
  # set +x
  assertEquals "1 2 3" "${TEST_ARR[0]}"
  assertEquals "4 5 6" "${TEST_ARR[1]}"
}

test_xpns_merge_array_elements2 () {
  TEST_ARR=(2 '' 4 '' 6 8 10)
  xpns_merge_array_elements 2 'TEST_ARR'
  assertEquals "2 " "${TEST_ARR[0]}"
  assertEquals "4 " "${TEST_ARR[1]}"
  assertEquals "6 8" "${TEST_ARR[2]}"
  assertEquals "10" "${TEST_ARR[3]}"
}

test_xpns_newline2space () {
  actual=$(echo 1 | xpns_newline2space)
  assertEquals "1" "${actual}"

  actual=$(seq 2 | xpns_newline2space)
  assertEquals "1 2" "${actual}"

  actual=$(seq 3 | xpns_newline2space)
  assertEquals "1 2 3" "${actual}"

  actual=$(seq 4 | sed 's/[24]//' | xpns_newline2space)
  assertEquals "1  3 " "${actual}"

  actual=$(echo | xpns_newline2space)
  assertEquals "" "${actual}"
}

test_xpns_parse_options1 () {
  export XP_ARGS=()
  export XP_OPTIONS=()
  export XP_NO_OPT=0
  xpns_parse_options A B C
  assertEquals "A" "${XP_ARGS[0]}"
  assertEquals "B" "${XP_ARGS[1]}"
  assertEquals "C" "${XP_ARGS[2]}"
  assertEquals "-c" "${XP_OPTIONS[0]}"
  assertEquals "echo {} " "${XP_OPTIONS[1]}"
}

test_xpns_parse_options2 () {
  export XP_ARGS=()
  export XP_OPTIONS=()
  export XP_NO_OPT=0
  xpns_parse_options --log -I@ -c'echo HOGE_@_ | sed s/HOGE/GEGE/' '' AA '' BB
  assertEquals "" "${XP_ARGS[0]}"
  assertEquals "AA" "${XP_ARGS[1]}"
  assertEquals "" "${XP_ARGS[2]}"
  assertEquals "BB" "${XP_ARGS[3]}"
  assertEquals "--log" "${XP_OPTIONS[0]}"
  assertEquals "-I" "${XP_OPTIONS[1]}"
  assertEquals "@" "${XP_OPTIONS[2]}"
  assertEquals "-c" "${XP_OPTIONS[3]}"
  assertEquals "echo HOGE_@_ | sed s/HOGE/GEGE/" "${XP_OPTIONS[4]}"
}

test_xpns_parse_options3 () {
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -c '' -B '' -B '' '' '' '' )
  assertEquals "0" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -l tiled _ _ _ )
  assertEquals "0" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -l tiled -C 2 _ _ _ )
  assertEquals "0" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -l tiled -R 2 _ _ _ )
  assertEquals "0" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -C 2 -x _ _ _ )
  assertEquals "0" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -x -l tiled -R 2 _ _ _ )
  assertEquals "0" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --bulk-cols=1,2,3  _ _ _ _ _ _ )
  assertEquals "0" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --bulk-cols=6  _ _ _ _ _ _ )
  assertEquals "0" "$?"
}

test_xpns_parse_options4 () {
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  xpns_parse_options -I@ -x -c'echo @ hoge' -- -h -V -d -e -t -x -s
  (( i = 0 ))
  assertEquals "-h" "${XP_ARGS[i++]}"
  assertEquals "-V" "${XP_ARGS[i++]}"
  assertEquals "-d" "${XP_ARGS[i++]}"
  assertEquals "-e" "${XP_ARGS[i++]}"
  assertEquals "-t" "${XP_ARGS[i++]}"
  assertEquals "-x" "${XP_ARGS[i++]}"
  assertEquals "-s" "${XP_ARGS[i++]}"
  (( i = 0 ))
  assertEquals "-I" "${XP_OPTIONS[i++]}"
  assertEquals "@" "${XP_OPTIONS[i++]}"
  assertEquals "-x" "${XP_OPTIONS[i++]}"
  assertEquals "-c" "${XP_OPTIONS[i++]}"
  assertEquals "echo @ hoge" "${XP_OPTIONS[i++]}"
}

test_xpns_parse_options5 () {
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  xpns_parse_options -I@ -x -d -c'echo @ hoge' a -h -V -d -e -t -x -s
  (( i = 0 ))
  assertEquals "a" "${XP_ARGS[i++]}"
  assertEquals "-h" "${XP_ARGS[i++]}"
  assertEquals "-V" "${XP_ARGS[i++]}"
  assertEquals "-d" "${XP_ARGS[i++]}"
  assertEquals "-e" "${XP_ARGS[i++]}"
  assertEquals "-t" "${XP_ARGS[i++]}"
  assertEquals "-x" "${XP_ARGS[i++]}"
  assertEquals "-s" "${XP_ARGS[i++]}"
  (( i = 0 ))
  assertEquals "-I" "${XP_OPTIONS[i++]}"
  assertEquals "@" "${XP_OPTIONS[i++]}"
  assertEquals "-x" "${XP_OPTIONS[i++]}"
  assertEquals "-d" "${XP_OPTIONS[i++]}"
  assertEquals "-c" "${XP_OPTIONS[i++]}"
  assertEquals "echo @ hoge" "${XP_OPTIONS[i++]}"
}

test_xpns_parse_options_error1 () {
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -I '' -c 'ssh {}' a b c )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -n '' _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -n ABC _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --bulk-cols '' _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -C ABC _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -R ABC _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options -S '' _ _ _ )
  assertEquals "4" "$?"
}

test_xpns_parse_options_error2 () {
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --bulk-cols='' -c 'ssh {}' a b c )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --log-format='' -c 'ssh {}' a b c )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --log='' -c 'ssh {}' a b c )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --cols='' _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --cols=ABC _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --rows='' _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --rows=ABC _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --bulk-cols=2,a,2  _ _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --bulk-cols=,  _ _ _ _ )
  assertEquals "4" "$?"
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( xpns_parse_options --bulk-cols=a  _ _ _ _ )
  assertEquals "4" "$?"
}

test_xpns_parse_options_pipe () {
  export XP_ARGS=(); export XP_OPTIONS=(); export XP_NO_OPT=0
  ( echo 2 4 6 8 | xpns_parse_options -n 2 -c 'seq {}')
  assertEquals "0" "$?"
}

test_xpns_parse_options_interval () {
  ( xpns_parse_options --interval 1 _ _ _)
  assertEquals "0" "$?"
  ( xpns_parse_options --interval=1 _ _ _)
  assertEquals "0" "$?"
  ( xpns_parse_options --interval 101 _ _ _)
  assertEquals "0" "$?"
  ( xpns_parse_options --interval 0.1 _ _ _)
  assertEquals "0" "$?"
  ( xpns_parse_options --interval 0.001 _ _ _)
  assertEquals "0" "$?"
  ( xpns_parse_options --interval 0.99 _ _ _)
  assertEquals "0" "$?"
  ( xpns_parse_options --interval=0.99 _ _ _)
  assertEquals "0" "$?"
  ( xpns_parse_options --interval -0.99 _ _ _)
  assertEquals "4" "$?"
  ( xpns_parse_options --interval=-0.99 _ _ _)
  assertEquals "4" "$?"
  ( xpns_parse_options --interval a _ _ _)
  assertEquals "4" "$?"
  ( xpns_parse_options --interval --hoge _ _ _)
  assertEquals "4" "$?"
}

test_xpns_opt_checker () {
  ( xpns_opt_checker --bulk-cols 1,2,3,4 csv )
  assertEquals "0" "$?"
  ( xpns_opt_checker -n 1 )
  assertEquals "0" "$?"
  ( xpns_opt_checker -S ~/dummy string )
  assertEquals "0" "$?"
  ( xpns_opt_checker --interval 1.1 float )
  assertEquals "0" "$?"
  ( xpns_opt_checker --bulk-cols "invalid" csv )
  assertEquals "4" "$?"
  ( xpns_opt_checker --bulk-cols "1,2,a" csv )
  assertEquals "4" "$?"
  ( xpns_opt_checker -n "invalid" )
  assertEquals "4" "$?"
  ( xpns_opt_checker -n "1.1.1.1" )
  assertEquals "4" "$?"
  ( xpns_opt_checker --interval "invalid" float )
  assertEquals "4" "$?"
  ( xpns_opt_checker --interval "1.1.1.1" float )
  assertEquals "4" "$?"
}

# shellcheck source=/dev/null
. "${THIS_DIR}/shunit2/shunit2"
