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

# Directory name of this file
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")"; pwd)"

BIN_DIR="${THIS_DIR}/../"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="./${BIN_NAME}"


shunit_socket="${TMPDIR}/shunit.session"
shunit_session_name="shunit_session"
shunit_window_name="shunit_window"

create_tmux_session(){
    # echo "tmux kill-session -t $shunit_session_name 2> /dev/null"
    tmux kill-session -t $shunit_session_name 2> /dev/null

    # echo "rm -f ${TMPDIR}/shunit.session"
    rm -f ${TMPDIR}/shunit.session

    # echo "tmux new-session -s $shunit_session_name -n $shunit_window_name -d"
    tmux new-session -s $shunit_session_name -n $shunit_window_name -d
}

exec_in_tmux_session(){
    # echo "tmux send-keys -t $shunit_session_name:$shunit_window_name \"cd ${BIN_DIR} && $*; touch ${TMPDIR}/done\" C-m" >&2
    # `head -n 10` prevents that the output exceeds the buffer size.
    # If it is omitted, the test might be failed.
    tmux send-keys -t $shunit_session_name:$shunit_window_name "cd ${BIN_DIR} && $* | head -n 10; touch ${TMPDIR}/done" C-m

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

    # echo "tmux capture-pane -t $shunit_session_name:$shunit_window_name" >&2
    tmux capture-pane -t $shunit_session_name:$shunit_window_name

    # Show result
    # echo "tmux show-buffer | awk NF" >&2
    tmux show-buffer | awk NF
    return 0
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
        _window_name=$(tmux -S $socket_file_name list-windows -F '#{window_name}' | grep "^${_window_name_prefix}" | head -n 1)
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
    # create_tmux_session
}

kill_tmux_session(){
    tmux kill-session -t $shunit_session_name
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

test_start_separation() {
    local window_name=""
    local socket_file_name=".xpanes-shunit"

    ${EXEC} -S $socket_file_name --no-attach AAAA BBBB
    wait_panes_separation "$socket_file_name" "AAAA" "2"
    # Number of window is 1
    assertEquals "1" "$(tmux -S $socket_file_name list-windows -F '#{window_name}' | grep -c .)"
    tmux -S $socket_file_name kill-session
    rm $socket_file_name
}

test_devide_two_panes() {
    local window_name=""
    local socket_file_name=".xpanes-shunit"

    ${EXEC} -S $socket_file_name --no-attach AAAA BBBB
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

    ${EXEC} -S $socket_file_name --no-attach AAAA BBBB CCCC
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

    ${EXEC} -S $socket_file_name --no-attach AAAA BBBB CCCC DDDD
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

    ${EXEC} -S $socket_file_name --no-attach AAAA BBBB CCCC DDDD EEEE
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
