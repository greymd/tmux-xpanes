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
    tmux send-keys -t $_session_name:$_window_name "cd ${BIN_DIR} && $*; touch ${TMPDIR}/done" C-m

    for i in $(seq 100) ;do
        sleep 1
        if [ -e ${TMPDIR}/done ]; then
            rm -f ${TMPDIR}/done
            break
        fi
        if [ $i -eq 100 ]; then
            echo "Test failed" >&2 && return 1
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
    create_tmux_session
}

kill_tmux_session(){
    tmux kill-session -t $_session_name
    rm -f ${TMPDIR}/shunit.session
}

tearDown() {
    kill_tmux_session
}

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
    cmd="exec_in_tmux_session ${EXEC} -V"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    cmd="exec_in_tmux_session ${EXEC} --version"; result=$($cmd); echo $cmd
    echo ${result} | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"
}

# test_help() {
#     result=`${EXEC} -h`
#     echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
#     assertEquals "0" "$?"
# 
#     result=`${EXEC} --help`
#     echo ${result} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
#     assertEquals "0" "$?"
# }


. ${THIS_DIR}/shunit2/source/2.1/src/shunit2

