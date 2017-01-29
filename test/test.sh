#!/bin/bash

# Directory name of this file
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")"; pwd)"

BIN_DIR="${THIS_DIR}/../"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="./${BIN_NAME}"


_socket="${TMPDIR}/shunit.session"
_session_name="shunit_session"
_window_name="shunit_window"

create_tmux_session(){
    # echo "tmux kill-session -t $_session_name 2> /dev/null"
    tmux kill-session -t $_session_name 2> /dev/null

    # echo "rm -f ${TMPDIR}/shunit.session"
    rm -f ${TMPDIR}/shunit.session

    # echo "tmux new-session -s $_session_name -n $_window_name -d"
    tmux new-session -s $_session_name -n $_window_name -d
}

exec_in_tmux_session(){
    # echo "tmux send-keys -t $_session_name:$_window_name \"cd ${BIN_DIR} && $*; touch ${TMPDIR}/done\" C-m" >&2
    # `head -n 10` prevents that the output exceeds the buffer size.
    # If it is omitted, the test might be failed.
    tmux send-keys -t $_session_name:$_window_name "cd ${BIN_DIR} && $* | head -n 10; touch ${TMPDIR}/done" C-m

    # Wait until tmux session is completely established.
    for i in $(seq 100) ;do
        sleep 1
        if [ -e "${TMPDIR}/done" ]; then
            rm -f "${TMPDIR}/done"
            break
        fi
        # Tmux session does not work.
        if [ $i -eq 100 ]; then
            echo "Test failed" >&2
            return 1
        fi
    done

    # echo "tmux capture-pane -t $_session_name:$_window_name" >&2
    tmux capture-pane -t $_session_name:$_window_name

    # Show result
    # echo "tmux show-buffer | awk NF" >&2
    tmux show-buffer | awk NF
    return 0
}

setUp(){
    cd ${BIN_DIR}
    # create_tmux_session
}

kill_tmux_session(){
    tmux kill-session -t $_session_name
    rm -f ${TMPDIR}/shunit.session
}

# tearDown() {
#     kill_tmux_session
# }

test_version() {
    #
    # From out side of TMUX session
    #
    cmd="${EXEC} -V"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    cmd="${EXEC} --version"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    #
    # From in side of TMUX session
    #
    create_tmux_session
    cmd="exec_in_tmux_session ${EXEC} -V"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"
    kill_tmux_session

    create_tmux_session
    cmd="exec_in_tmux_session ${EXEC} --version"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"
    kill_tmux_session
}

test_help() {
    cmd="${EXEC} -h"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    cmd="${EXEC} --help"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    create_tmux_session
    cmd="exec_in_tmux_session ${EXEC} -h"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"
    kill_tmux_session

    create_tmux_session
    cmd="exec_in_tmux_session ${EXEC} --help"; result=$($cmd); echo $cmd
    echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"
    kill_tmux_session
}

test_devide_two_panes() {
    local window_name=""
    local socket_file_name=".xpanes-shunit"

    ${EXEC} -S $socket_file_name --no-attach XPANES AAAA
    # Wait until pane separation is completed
    for i in $(seq 100) ;do
        sleep 1
        window_name=$(tmux -S $socket_file_name list-windows -F '#{window_name}' | grep '^XPANES' | head -n 1)
        if ! [ -z "${window_name}" ]; then
            break
        fi
        # Still not separated.
        if [ $i -eq 100 ]; then
            echo "Test failed" >&2
            return 1
        fi
    done

    echo "Check number of panes"
    tmux -S $socket_file_name list-panes -t "$window_name"
    assertEquals 2 "$(tmux -S $socket_file_name list-panes -t "$window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==2')
    echo "A:$a_width B:$b_width"
    # true:1, false:0
    # a_width +- 1 is b_width
    assertEquals 1 "$(( ( $a_width + 1 ) == $b_width || $a_width == $b_width || ( $a_width - 1 ) == $b_width ))"

    echo "Check height"
    a_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==2')
    echo "A:$a_height B:$b_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    tmux -S $socket_file_name kill-window -t $window_name
    rm $socket_file_name
}

a_within_plus_minus_1_b() {
    echo "$(( ( $1 + 1 ) == $2 || $1 == $2 || ( $1 - 1 ) == $2 ))"
}

test_devide_four_panes() {
    local window_name=""
    local socket_file_name=".xpanes-shunit"

    ${EXEC} -S $socket_file_name --no-attach XPANES AAAA BBBB CCCC
    # Wait until pane separation is completed
    for i in $(seq 100) ;do
        sleep 1
        window_name=$(tmux -S $socket_file_name list-windows -F '#{window_name}' | grep '^XPANES' | head -n 1)
        if ! [ -z "${window_name}" ]; then
            break
        fi
        # Still not separated.
        if [ $i -eq 100 ]; then
            echo "Test failed" >&2
            return 1
        fi
    done

    echo "Check number of panes"
    tmux -S $socket_file_name list-panes -t "$window_name"
    assertEquals 4 "$(tmux -S $socket_file_name list-panes -t "$window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==3')
    d_width=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_width}' | awk 'NR==4')
    echo "A:$a_width B:$b_width C:$c_width D:$d_width"
    # Window should be devided like this.
    # ---------
    # | A | B |
    # +---+---+
    # | C | D |
    # ---------
    assertEquals 1 "$(($a_width == $c_width))"
    assertEquals 1 "$(($b_width == $d_width))"
    assertEquals 1 "$(a_within_plus_minus_1_b $a_width $b_width)"
    assertEquals 1 "$(a_within_plus_minus_1_b $c_width $d_width)"

    echo "Check height"
    a_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==3')
    d_height=$(tmux -S $socket_file_name list-panes -t "$window_name" -F '#{pane_height}' | awk 'NR==4')
    echo "A:$a_height B:$b_height C:$c_height D:$d_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(( $c_height == $d_height ))"
    assertEquals 1 "$(a_within_plus_minus_1_b $a_width $c_width)"
    assertEquals 1 "$(a_within_plus_minus_1_b $b_width $d_width)"
    tmux -S $socket_file_name kill-window -t $window_name
    rm $socket_file_name
}
. ${THIS_DIR}/shunit2/source/2.1/src/shunit2

