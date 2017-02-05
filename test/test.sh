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

if [ -n "$TMUX" ]; then
 echo "Do not execute this test inside TMUX session." >&2
 exit 1
fi

# Directory name of this file
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")"; pwd)"

BIN_DIR="${THIS_DIR}/../"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="./${BIN_NAME}"

create_tmux_session() {
    local _socket_file="$1"
    tmux -S $_socket_file new-session -d
}

exec_tmux_session() {
    local _socket_file="$1" ;shift
    # echo "send-keys: cd ${BIN_DIR} && $* && touch ${TMPDIR}/done" >&2
    tmux -S $_socket_file send-keys "cd ${BIN_DIR} && $* && touch ${TMPDIR}/done" C-m
    # Wait until tmux session is completely established.
    for i in $(seq 30) ;do
        sleep 1
        if [ -e "${TMPDIR}/done" ]; then
            rm -f "${TMPDIR}/done"
            break
        fi
        # Tmux session does not work.
        if [ $i -eq 30 ]; then
            echo "Test failed" >&2
            return 1
        fi
    done
}

capture_tmux_session() {
    local _socket_file="$1"
    tmux -S $_socket_file capture-pane
    tmux -S $_socket_file show-buffer
}

close_tmux_session() {
    local _socket_file="$1"
    tmux -S $_socket_file kill-session
    rm $_socket_file
}

wait_panes_separation() {
    local _socket_file_name="$1"
    local _window_name_prefix="$2"
    local _expected_window_num="$3"
    local _window_name=""
    local _window_num=""
    local _wait_seconds=30
    # Wait until pane separation is completed
    echo "Check number of panes"
    for i in $(seq $_wait_seconds) ;do
        sleep 1
        _window_name=$(tmux -S $_socket_file_name list-windows -F '#{window_name}' | grep "^${_window_name_prefix}" | head -n 1)
        if ! [ -z "${_window_name}" ]; then
            _window_num="$(tmux -S $_socket_file_name list-panes -t "$_window_name" | grep -c .)"
            if [ "${_window_num}" = "${_expected_window_num}" ]; then
                tmux -S $_socket_file_name list-panes -t "$_window_name" >&2
                break
            fi
        fi
        # Still not separated.
        if [ $i -eq $_wait_seconds ]; then
            echo "Test failed" >&2
            return 1
        fi
    done
}

between_plus_minus_1() {
    echo "$(( ( $1 + 1 ) == $2 || $1 == $2 || ( $1 - 1 ) == $2 ))"
}

setUp(){
    cd ${BIN_DIR}
    echo ">>>>>>>>>>" >&2
}

tearDown(){
    echo "<<<<<<<<<<" >&2
    echo >&2
}

test_insufficient_cmd() {
    XPANES_DEPENDENCIES="hogehoge123 cat" ${BIN_NAME}
    assertEquals "1" "$?"
}

test_invalid_args() {
    cmd="${BIN_NAME} -Z"
    echo $cmd
    # execute
    $cmd > /dev/null
    assertEquals "4" "$?"
}


test_version() {
    cmd="${EXEC} -V"; echo $cmd
    $cmd | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    cmd="${EXEC} --version"; echo $cmd
    $cmd | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    : "In TMUX session" && {
    local _socket_file="${TMPDIR}/.xpanes-shunit"
        cmd="${EXEC} -V"; echo "TMUX($cmd)"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" $cmd
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
        assertEquals "0" "$?"
        close_tmux_session $_socket_file

        cmd="${EXEC} --version"; echo "TMUX($cmd)"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" $cmd
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
        assertEquals "0" "$?"
        close_tmux_session $_socket_file
    }
}

test_help() {
    cmd="${EXEC} -h"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    cmd="${EXEC} --help"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    : "In TMUX session" && {
        local _socket_file="${TMPDIR}/.xpanes-shunit"
        create_tmux_session "$_socket_file"
        # "| head " is added to prevent that the result exceeds the buffer limit of TMUX.
        exec_tmux_session  "$_socket_file" "${EXEC} -h | head"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} \[OPTIONS\] .*"
        assertEquals "0" "$?"
        close_tmux_session $_socket_file

        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "${EXEC} --help | head"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} \[OPTIONS\] .*"
        assertEquals "0" "$?"
        close_tmux_session $_socket_file
    }
}


test_start_separation() {
    local window_name=""
    local _socket_file=".xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB"
    echo "$_cmd"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "2"
    # Number of window is 1
    assertEquals "1" "$(tmux -S $_socket_file list-windows -F '#{window_name}' | grep -c .)"
    tmux -S $_socket_file kill-session
    rm $_socket_file

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB"
        echo "TMUX($_cmd)"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        # There must be 2 windows -- default window & new window.
        tmux -S $_socket_file list-windows
        assertEquals "2" "$(tmux -S $_socket_file list-windows | grep -c .)"
        close_tmux_session "$_socket_file"
    }
}

test_devide_two_panes() {
    local window_name=""
    local socket_file_name=".xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $socket_file_name --no-attach AAAA BBBB"
    echo "$_cmd"
    $_cmd
    wait_panes_separation "$socket_file_name" "AAAA" "2"
    window_name=$(tmux -S $socket_file_name list-windows -F '#{window_name}' | grep '^AAAA' | head -n 1)

    # Window should be devided like this.
    # +---+---+
    # | A | B |
    # +---+---+

    echo "Check number of panes"
    assertEquals 2 "$(tmux -S $socket_file_name list-panes -t "$window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==2')
    echo "A:$a_width B:$b_width"
    # true:1, false:0
    # a_width +- 1 is b_width
    assertEquals 1 "$(between_plus_minus_1 $a_width $b_width)"

    echo "Check height"
    a_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==2')
    echo "A:$a_height B:$b_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    tmux -S $socket_file_name kill-window -t $window_name
    rm $socket_file_name
}

test_devide_three_panes() {
    local window_name=""
    local socket_file_name=".xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $socket_file_name --no-attach AAAA BBBB CCCC"
    echo "$_cmd"
    $_cmd
    wait_panes_separation "$socket_file_name" "AAAA" "3"
    window_name="$(tmux -S $socket_file_name list-windows -F '#{window_name}' | grep '^AAAA' | head -n 1)"

    # Window should be devided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # |   C   |
    # +---+---+

    echo "Check number of panes"
    assertEquals 3 "$(tmux -S $socket_file_name list-panes -t "$window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==3')
    echo "A:$a_width B:$b_width C:$c_width"
    assertEquals 1 "$(between_plus_minus_1 $a_width $b_width)"
    assertEquals 1 "$(( $(( $a_width + $b_width + 1 )) == $c_width ))"

    echo "Check height"
    a_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==3')
    echo "A:$a_height B:$b_height C:$c_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(between_plus_minus_1 $c_height $a_height)"
    tmux -S $socket_file_name kill-window -t $window_name
    rm $socket_file_name
}

test_devide_four_panes() {
    local window_name=""
    local socket_file_name=".xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $socket_file_name --no-attach AAAA BBBB CCCC DDDD"
    echo "$_cmd"
    $_cmd
    wait_panes_separation "$socket_file_name" "AAAA" "4"
    window_name=$(tmux -S $socket_file_name list-windows -F '#{window_name}' | grep '^AAAA' | head -n 1)

    # Window should be devided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # | C | D |
    # +---+---+

    echo "Check width"
    a_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==3')
    d_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==4')
    echo "A:$a_width B:$b_width C:$c_width D:$d_width"

    assertEquals 1 "$(($a_width == $c_width))"
    assertEquals 1 "$(($b_width == $d_width))"
    assertEquals 1 "$(between_plus_minus_1 $a_width $b_width)"
    assertEquals 1 "$(between_plus_minus_1 $c_width $d_width)"

    echo "Check height"
    a_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==3')
    d_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==4')
    echo "A:$a_height B:$b_height C:$c_height D:$d_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(( $c_height == $d_height ))"
    assertEquals 1 "$(between_plus_minus_1 $a_height $c_height)"
    assertEquals 1 "$(between_plus_minus_1 $b_height $d_height)"
    tmux -S $socket_file_name kill-window -t $window_name
    rm $socket_file_name
}


test_devide_five_panes() {
    local window_name=""
    local socket_file_name=".xpanes-shunit"
    local _cmd=""

    ${EXEC} -S $socket_file_name --no-attach AAAA BBBB CCCC DDDD EEEE
    echo "$_cmd"
    $_cmd
    wait_panes_separation "$socket_file_name" "AAAA" "5"
    window_name=$(tmux -S $socket_file_name list-windows -F '#{window_name}' | grep '^AAAA' | head -n 1)

    # Window should be devided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # | C | D |
    # +---+---+
    # |   E   |
    # +---+---+

    echo "Check width"
    a_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==3')
    d_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==4')
    e_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==5')
    echo "A:$a_width B:$b_width C:$c_width D:$d_width E:$e_width"
    assertEquals 1 "$(($a_width == $c_width))"
    assertEquals 1 "$(($b_width == $d_width))"
    assertEquals 1 "$(between_plus_minus_1 $a_width $b_width)"
    assertEquals 1 "$(between_plus_minus_1 $c_width $d_width)"
    # Width of A + B is greater than E with 1 px. Because of the border.
    assertEquals 1 "$(( $(( $a_width + $b_width + 1 )) == $e_width))"

    echo "Check height"
    a_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==3')
    d_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==4')
    e_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==5')
    echo "A:$a_height B:$b_height C:$c_height D:$d_height E:$e_height"
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(( $c_height == $d_height ))"
    assertEquals 1 "$(between_plus_minus_1 $a_height $c_height)"
    assertEquals 1 "$(between_plus_minus_1 $b_height $d_height)"
    assertEquals 1 "$(between_plus_minus_1 $a_height $e_height)"
    assertEquals 1 "$(between_plus_minus_1 $c_height $e_height)"

    tmux -S $socket_file_name kill-window -t $window_name
    rm $socket_file_name
}

. ${THIS_DIR}/shunit2/source/2.1/src/shunit2
