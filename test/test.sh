#!/bin/bash

if [ -n "$BASH_VERSION" ]; then
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
readonly TEST_TMP="$THIS_DIR/test_tmp"

BIN_DIR="${THIS_DIR}/../bin/"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="./${BIN_NAME}"

tmux_version_number() {
    local _tmux_version=""
    tmux -V &> /dev/null
    if [ $? -ne 0 ]; then
        # From tmux 0.9 to 1.3, there is no -V option.
        # Adjust all to 0.9
        _tmux_version="tmux 0.9"
    else
        _tmux_version="$(tmux -V)"
    fi
    echo "$_tmux_version" | perl -anle 'printf $F[1]'
}

# Check whether the given version is less than current tmux version.
# In case of tmux version is 1.7, the result will be like this.
##  arg  -> result
#   1.5  -> 1
#   1.6  -> 1
#   1.7  -> 1
#   1.8  -> 0
#   1.9  -> 0
#   1.9a -> 0
#   2.0  -> 0
is_less_than() {
    # Simple numerical comparison does not work because there is the version like "1.9a".
    if [[ "$((echo "$(tmux_version_number)"; echo "$1") | sort -n | head -n 1)" != "$1" ]];then
        return 0
    else
        return 1
    fi
}

# !!Run this function at first!!
check_version() {
    ${BIN_DIR}${EXEC} --dry-run A
    # If tmux version is less than 1.6, skip rest of the tests.
    if is_less_than "1.6" ;then
        echo "Skip rest of the tests." >&2
        echo "Because this version is out of support." >&2
        exit 0
    fi
}

check_version

create_tmux_session() {
    local _socket_file="$1"
    tmux -S $_socket_file new-session -d
    # Once attach tmux session and detach it.
    # Because, pipe-pane feature does not work with tmux 1.8 (it might be bug).
    # To run pipe-pane, it is necessary to attach the session.
    tmux -S $_socket_file send-keys "sleep 1 && tmux detach-client" C-m
    tmux -S $_socket_file attach-session
}

exec_tmux_session() {
    local _socket_file="$1" ;shift
    local _tmpdir=${SHUNIT_TMPDIR:-/tmp}
    echo "send-keys: cd ${BIN_DIR} && $* && touch ${SHUNIT_TMPDIR}/done" >&2
    # Same reason as the comments near "create_tmux_session".
    tmux -S $_socket_file send-keys "cd ${BIN_DIR} && $* && touch ${SHUNIT_TMPDIR}/done && sleep 1 && tmux detach-client" C-m
    tmux -S $_socket_file attach-session
    # Wait until tmux session is completely established.
    for i in $(seq 30) ;do
        sleep 1
        if [ -e "${SHUNIT_TMPDIR}/done" ]; then
            rm -f "${SHUNIT_TMPDIR}/done"
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
    local _socket_file="$1"
    local _window_name_prefix="$2"
    local _expected_pane_num="$3"
    local _window_name=""
    local _pane_num=""
    local _wait_seconds=30
    # Wait until pane separation is completed
    for i in $(seq $_wait_seconds) ;do
        sleep 1
        _window_name=$(tmux -S $_socket_file list-windows -F '#{window_name}' | grep "^${_window_name_prefix}" | head -n 1)
        # printf "wait_panes_separation: " >&2
        # tmux -S $_socket_file list-windows -F '#{window_name}' >&2
        if ! [ -z "${_window_name}" ]; then
            _pane_num="$(tmux -S $_socket_file list-panes -t "$_window_name" | grep -c .)"
            # tmux -S $_socket_file list-panes -t "$_window_name"
            if [ "${_pane_num}" = "${_expected_pane_num}" ]; then
                tmux -S $_socket_file list-panes -t "$_window_name" >&2
                # Wait several seconds to ensure the completion.
                # Even the number of panes equals to expected number,
                # the separation is not complated sometimes.
                sleep 3
                break
            fi
        fi
        # Still not separated.
        if [ $i -eq $_wait_seconds ]; then
            echo "wait_panes_separation: Test failed" >&2
            return 1
        fi
    done
    return 0
}

wait_all_files_creation(){
    local _wait_seconds=30
    local _break=1
    # Wait until specific files are created.
    for i in $(seq $_wait_seconds) ;do
        sleep 1
        _break=1
        for f in "$@" ;do
            if ! [ -e "$f" ]; then
                # echo "$f:does not exist." >&2
                _break=0
            fi
        done
        if [ $_break -eq 1 ]; then
            break
        fi
        if [ $i -eq $_wait_seconds ]; then
            echo "wait_all_files_creation: Test failed" >&2
            return 1
        fi
    done
    return 0
}

wait_existing_file_number(){
    local _target_dir="$1"
    local _expected_num="$2"
    local _num_of_files=0
    local _wait_seconds=30
    # Wait until specific number of files are created.
    for i in $(seq $_wait_seconds) ;do
        sleep 1
        _num_of_files=$(ls "$_target_dir" | grep -c .)
        if [ "$_num_of_files" = "$_expected_num" ]; then
            break
        fi
        if [ $i -eq $_wait_seconds ]; then
            echo "wait_existing_file_number: Test failed" >&2
            return 1
        fi
    done
    return 0
}

between_plus_minus() {
    local _range="$1"
    shift
    echo "$(( ( $1 + $_range ) >= $2 && $2 >= ( $1 - $_range ) ))"
}

# Returns the index of the window and number of it's panes.
# The reason why it does not use #{window_panes} is, tmux 1.6 does not support the format.
get_window_having_panes() {
    local _socket_file="$1"
    local _pane_num="$2"
    tmux  -S "$_socket_file" list-windows -F '#{window_index}' \
        | while read idx;
            do
                echo -n "$idx "; tmux -S "$_socket_file" list-panes -t $idx -F '#{pane_index}' | grep -c .
            done | awk '$2=='$_pane_num'{print $1}' | head -n 1
}

divide_two_panes_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "$_socket_file" "2")

    # Window should be divided like this.
    # +---+---+
    # | A | B |
    # +---+---+

    echo "Check number of panes"
    assertEquals 2 "$(tmux -S $_socket_file list-panes -t "$_window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==2')
    echo "A:$a_width B:$b_width"
    # true:1, false:0
    # a_width +- 1 is b_width
    assertEquals 1 "$(between_plus_minus 1 $a_width $b_width)"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    echo "A:$a_height B:$b_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
}

divide_three_panes_impl() {
    local _window_name=""
    _window_name=$(get_window_having_panes "$_socket_file" "3")

    # Window should be divided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # |   C   |
    # +---+---+

    echo "Check number of panes"
    assertEquals 3 "$(tmux -S $_socket_file list-panes -t "$_window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==3')
    echo "A:$a_width B:$b_width C:$c_width"
    assertEquals 1 "$(between_plus_minus 1 $a_width $b_width)"
    assertEquals 1 "$(( $(( $a_width + $b_width + 1 )) == $c_width ))"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==3')
    echo "A:$a_height B:$b_height C:$c_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(between_plus_minus 1 $c_height $a_height)"
}

divide_four_panes_impl() {
    local _window_name=""
    _window_name=$(get_window_having_panes "$_socket_file" "4")

    # Window should be divided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # | C | D |
    # +---+---+

    echo "Check width"
    a_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==3')
    d_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==4')
    echo "A:$a_width B:$b_width C:$c_width D:$d_width"

    assertEquals 1 "$(($a_width == $c_width))"
    assertEquals 1 "$(($b_width == $d_width))"
    assertEquals 1 "$(between_plus_minus 1 $a_width $b_width)"
    assertEquals 1 "$(between_plus_minus 1 $c_width $d_width)"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==3')
    d_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==4')
    echo "A:$a_height B:$b_height C:$c_height D:$d_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(( $c_height == $d_height ))"
    assertEquals 1 "$(between_plus_minus 1 $a_height $c_height)"
    assertEquals 1 "$(between_plus_minus 1 $b_height $d_height)"
}

divide_five_panes_impl() {
    local _window_name=""
    _window_name=$(get_window_having_panes "$_socket_file" "5")

    # Window should be divided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # | C | D |
    # +---+---+
    # |   E   |
    # +---+---+

    echo "Check width"
    a_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==3')
    d_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==4')
    e_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==5')
    echo "A:$a_width B:$b_width C:$c_width D:$d_width E:$e_width"
    assertEquals 1 "$(($a_width == $c_width))"
    assertEquals 1 "$(($b_width == $d_width))"
    assertEquals 1 "$(between_plus_minus 1 $a_width $b_width)"
    assertEquals 1 "$(between_plus_minus 1 $c_width $d_width)"
    # Width of A + B is greater than E with 1 px. Because of the border.
    assertEquals 1 "$(( $(( $a_width + $b_width + 1 )) == $e_width))"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==3')
    d_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==4')
    e_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==5')
    echo "A:$a_height B:$b_height C:$c_height D:$d_height E:$e_height"
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(( $c_height == $d_height ))"
    assertEquals 1 "$(between_plus_minus 1 $a_height $c_height)"
    assertEquals 1 "$(between_plus_minus 1 $b_height $d_height)"
    # On author's machine, following two tests does not pass with 1 ... somehow.
    assertEquals 1 "$(between_plus_minus 2 $a_height $e_height)"
    assertEquals 1 "$(between_plus_minus 2 $c_height $e_height)"
}

divide_two_panes_ev_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "$_socket_file" "2")

    # Window should be divided like this.
    # +-------+
    # |   A   |
    # +-------+
    # |   B   |
    # +-------+

    echo "Check number of panes"
    assertEquals 2 "$(tmux -S $_socket_file list-panes -t "$_window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==2')
    echo "A:$a_width B:$b_width"
    # true:1, false:0
    # In this case, height must be same.
    assertEquals 1 "$(( $a_width == $b_width ))"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    echo "A:$a_height B:$b_height"
    # a_height +- 1 is b_height
    assertEquals 1 "$(between_plus_minus 1 $a_height $b_height)"
}

divide_two_panes_eh_impl() {
    divide_two_panes_impl "$1"
}

divide_three_panes_ev_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "$_socket_file" "3")

    # Window should be divided like this.
    # +-------+
    # |   A   |
    # +-------+
    # |   B   |
    # +-------+
    # |   C   |
    # +-------+

    echo "Check number of panes"
    assertEquals 3 "$(tmux -S $_socket_file list-panes -t "$_window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==3')
    echo "A:$a_width B:$b_width C:$c_width"
    # true:1, false:0
    # In this case, height must be same.
    assertEquals 1 "$(( $a_width == $b_width ))"
    assertEquals 1 "$(( $b_width == $c_width ))"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==3')
    echo "A:$a_height B:$b_height C:$c_height"

    assertEquals 1 "$(between_plus_minus 1 $a_height $b_height)"
    assertEquals 1 "$(between_plus_minus 2 $b_height $c_height)"
}

divide_three_panes_eh_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "$_socket_file" "3")

    # Window should be divided like this.
    # +---+---+---+
    # | A | B | C |
    # +---+---+---+

    echo "Check number of panes"
    assertEquals 3 "$(tmux -S $_socket_file list-panes -t "$_window_name" | grep -c .)"

    echo "Check width"
    a_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_width}' | awk 'NR==3')
    echo "A:$a_width B:$b_width C:$c_width"
    # true:1, false:0
    # In this case, height must be same.
    assertEquals 1 "$(between_plus_minus 1 $a_width $b_width)"
    assertEquals 1 "$(between_plus_minus 2 $b_width $c_width)"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==3')
    echo "A:$a_height B:$b_height C:$c_height"

    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(( $b_height == $c_height ))"
}

setUp(){
    cd ${BIN_DIR}
    mkdir -p $TEST_TMP
    echo ">>>>>>>>>>" >&2
}

tearDown(){
    rm -rf $TEST_TMP
    echo "<<<<<<<<<<" >&2
    echo >&2
}

###################### START TESTING ######################

test_invalid_layout() {
    # Option and arguments are continuous.
    ${EXEC} -lmem 1 2 3
    assertEquals "6" "$?"

    # Option and arguments are separated.
    ${EXEC} -l mem 1 2 3
    assertEquals "6" "$?"
}

test_invalid_layout_pipe() {
    # Option and arguments are continuous.
    echo 1 2 3 | ${EXEC} -lmem
    assertEquals "6" "$?"

    # Option and arguments are separated.
    echo 1 2 3 | ${EXEC} -lmem
    assertEquals "6" "$?"
}

# divide window into two panes even-vertically
test_divide_two_panes_ev() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    # Run with normal mode
    _cmd="${EXEC} -l ev -S $_socket_file --no-attach AAAA BBBB"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    # Run with pipe mode
    _cmd="echo AAAA BBBB | xargs -n 1 | ${EXEC} -l ev -S $_socket_file --no-attach"
    printf "\n $ $_cmd\n"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file -lev AAAA BBBB"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_ev_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="echo  AAAA BBBB | xargs -n 1 | ${EXEC} -S $_socket_file -lev"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_ev_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_two_panes_eh() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    # Run with normal mode
    _cmd="${EXEC} -l eh -S $_socket_file --no-attach AAAA BBBB"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_eh_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    # Run with pipe mode
    _cmd="echo AAAA BBBB | xargs -n 1 | ${EXEC} -l eh -S $_socket_file --no-attach"
    printf "\n $ $_cmd\n"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_eh_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file -leh AAAA BBBB"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_eh_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="echo AAAA BBBB | xargs -n 1 | ${EXEC} -S $_socket_file -leh"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_eh_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_three_panes_ev() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -l ev -S $_socket_file --no-attach AAAA BBBB CCCC"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    _cmd="echo AAAA BBBB CCCC | xargs -n 1 | ${EXEC} -l ev -S $_socket_file --no-attach"
    printf "\n $ $_cmd\n"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file -lev AAAA BBBB CCCC"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_ev_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="echo AAAA BBBB CCCC | xargs -n 1 | ${EXEC} -S $_socket_file -lev"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_ev_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_three_panes_eh() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -l eh -S $_socket_file --no-attach AAAA BBBB CCCC"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_eh_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    _cmd="echo AAAA BBBB CCCC | xargs -n 1 | ${EXEC} -l eh -S $_socket_file --no-attach"
    printf "\n $ $_cmd\n"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_eh_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {

        _cmd="${EXEC} -S $_socket_file -leh AAAA BBBB CCCC"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_eh_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="echo AAAA BBBB CCCC | xargs -n 1 | ${EXEC} -S $_socket_file -leh"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_eh_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_append_arg_to_utility_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    rm -rf $TEST_TMP/tmp{1,2,3,4}
    mkdir $TEST_TMP/tmp{1,2,3,4}

    _cmd="printf '$TEST_TMP/tmp1 $TEST_TMP/tmp2\n$TEST_TMP/tmp3 $TEST_TMP/tmp4\n' | ${EXEC} -S $_socket_file mv"
    echo
    echo "$ $_cmd"
    echo
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "$TEST_TMP" "2"
    divide_two_panes_impl "$_socket_file"

    find $TEST_TMP
    [ -e $TEST_TMP/tmp2/tmp1 ]
    assertEquals "0" "$?"

    [ -e $TEST_TMP/tmp4/tmp3 ]
    assertEquals "0" "$?"

    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        rm -rf $TEST_TMP/tmp{1,2,3,4}
        mkdir $TEST_TMP/tmp{1,2,3,4}
        _cmd="printf '$TEST_TMP/tmp1 $TEST_TMP/tmp2\n$TEST_TMP/tmp3 $TEST_TMP/tmp4\n' | ${EXEC} mv"
        echo
        echo " $ TMUX($_cmd)"
        echo
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "$TEST_TMP" "2"
        divide_two_panes_impl "$_socket_file"

        find $TEST_TMP
        [ -e $TEST_TMP/tmp2/tmp1 ]
        assertEquals "0" "$?"

        [ -e $TEST_TMP/tmp4/tmp3 ]
        assertEquals "0" "$?"

        close_tmux_session "$_socket_file"
    }
}

test_execute_option() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} --no-attach -e -S $_socket_file 'seq 5 15 > $TEST_TMP/1' 'echo Testing > $TEST_TMP/2'"
    echo
    echo "$ $_cmd"
    echo
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "seq" "2"
    divide_two_panes_impl "$_socket_file"
    assertEquals "$(seq 5 15)" "$(cat $TEST_TMP/1)"
    assertEquals "$(echo Testing)" "$(cat $TEST_TMP/2)"
    close_tmux_session "$_socket_file"

    rm $TEST_TMP/{1,2}
    # Use continuous option -eS.
    _cmd="${EXEC} --no-attach -eS $_socket_file 'seq 5 15 > $TEST_TMP/1' 'echo Testing > $TEST_TMP/2'"
    echo
    echo "$ $_cmd"
    echo
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "seq" "2"
    divide_two_panes_impl "$_socket_file"
    assertEquals "$(seq 5 15)" "$(cat $TEST_TMP/1)"
    assertEquals "$(echo Testing)" "$(cat $TEST_TMP/2)"
    close_tmux_session "$_socket_file"


    : "In TMUX session" && {
        _cmd="${EXEC} -e 'seq 5 15 > $TEST_TMP/3' 'echo Testing > $TEST_TMP/4'"
        echo
        echo " $ TMUX($_cmd)"
        echo
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "seq" "2"
        divide_two_panes_impl "$_socket_file"
        assertEquals "$(seq 5 15)" "$(cat $TEST_TMP/3)"
        assertEquals "$(echo Testing)" "$(cat $TEST_TMP/4)"
        close_tmux_session "$_socket_file"
    }
}

test_execute_option_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="printf '%s\n%s\n%s\n' 'seq 5 15 > $TEST_TMP/1' 'echo Testing > $TEST_TMP/2' 'yes | head -n 3 > $TEST_TMP/3' | ${EXEC} -e -S $_socket_file"
    echo
    echo "$ $_cmd"
    echo
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "seq" "3"
    divide_three_panes_impl "$_socket_file"
    assertEquals "$(seq 5 15)" "$(cat $TEST_TMP/1)"
    assertEquals "$(echo Testing)" "$(cat $TEST_TMP/2)"
    assertEquals "$(yes | head -n 3)" "$(cat $TEST_TMP/3)"
    close_tmux_session "$_socket_file"

    rm $TEST_TMP/{1,2,3}
    # Use continuous option -eS
    _cmd="printf '%s\n%s\n%s\n' 'seq 5 15 > $TEST_TMP/1' 'echo Testing > $TEST_TMP/2' 'yes | head -n 3 > $TEST_TMP/3' | ${EXEC} -eS $_socket_file"
    echo
    echo "$ $_cmd"
    echo
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "seq" "3"
    divide_three_panes_impl "$_socket_file"
    assertEquals "$(seq 5 15)" "$(cat $TEST_TMP/1)"
    assertEquals "$(echo Testing)" "$(cat $TEST_TMP/2)"
    assertEquals "$(yes | head -n 3)" "$(cat $TEST_TMP/3)"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="printf '%s\n%s\n%s\n' 'seq 5 15 > $TEST_TMP/4' 'echo Testing > $TEST_TMP/5' 'yes | head -n 3 > $TEST_TMP/6' | ${EXEC} -e"
        echo
        echo " $ TMUX($_cmd)"
        echo
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "seq" "3"
        divide_three_panes_impl "$_socket_file"
        assertEquals "$(seq 5 15)" "$(cat $TEST_TMP/4)"
        assertEquals "$(echo Testing)" "$(cat $TEST_TMP/5)"
        assertEquals "$(yes | head -n 3)" "$(cat $TEST_TMP/6)"
        close_tmux_session "$_socket_file"
    }
}

test_argument_and_utility_pipe() {
    echo 10 | ${EXEC} -c 'seq {}' factor {}
    assertEquals "4" "$?"
}

test_unsupported_version() {
    _XP_CURRENT_TMUX_VERSION="1.1" ${EXEC} --dry-run A 2>&1 | grep "out of support."
    assertEquals "0" "$?"
}

test_invalid_args() {
    local _cmd="${EXEC} -Z"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

test_valid_and_invalid_args() {
    local _cmd="${EXEC} -Zc @@@"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

test_invalid_long_args() {
    local _cmd="${EXEC} --hogehoge"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}


test_no_args() {
    local _cmd="${EXEC}"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

test_hyphen_only() {
    local _cmd="${EXEC} --"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

test_pipe_without_repstr() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    : "In TMUX session" && {
        _cmd="seq 5 10 | xargs -n 2 | ${EXEC} -S $_socket_file seq"
        # this executes following commands on panes.
        #   $ seq 5 6
        #   $ seq 7 8
        #   $ seq 9 10
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "5" "3"
        # check number of divided panes
        divide_three_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_hyphen_and_option1() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I@ -S $_socket_file -c \"cat <<<@ > ${_tmpdir}/@.result\" --no-attach -- -l -V -h -Z"
    printf "\n $ $_cmd\n"
    ${EXEC} -I@ -S $_socket_file -c "cat <<<@ > ${_tmpdir}/@.result" --no-attach -- -l -V -h -Z
    # hyphen "-" in the window name will be replacet with "_".
    wait_panes_separation "$_socket_file" "_l" "4"
    wait_all_files_creation ${_tmpdir}/{-l,-V,-h,-Z}.result
    diff "${_tmpdir}/-l.result" <(cat <<<-l)
    assertEquals 0 $?
    diff "${_tmpdir}/-V.result" <(cat <<<-V)
    assertEquals 0 $?
    diff "${_tmpdir}/-h.result" <(cat <<<-h)
    assertEquals 0 $?
    diff "${_tmpdir}/-Z.result" <(cat <<<-Z)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f ${_tmpdir}/*.result

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "_l" "4"
        wait_all_files_creation ${_tmpdir}/{-l,-V,-h,-Z}.result
        diff "${_tmpdir}/-l.result" <(cat <<<-l)
        assertEquals 0 $?
        diff "${_tmpdir}/-V.result" <(cat <<<-V)
        assertEquals 0 $?
        diff "${_tmpdir}/-h.result" <(cat <<<-h)
        assertEquals 0 $?
        diff "${_tmpdir}/-Z.result" <(cat <<<-Z)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f ${_tmpdir}/*.result
    }
}

test_hyphen_and_option2() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I@ -S $_socket_file -c \"cat <<<@ > ${_tmpdir}/@.result\" --no-attach -- -- AA --Z BB"
    printf "\n $ $_cmd\n"
    ${EXEC} -I@ -S $_socket_file -c "cat <<<@ > ${_tmpdir}/@.result" --no-attach -- -- AA --Z BB
    # hyphen "-" in the window name will be replacet with "_".
    wait_panes_separation "$_socket_file" "__" "4"
    wait_all_files_creation ${_tmpdir}/{--,AA,--Z,BB}.result
    diff "${_tmpdir}/--.result" <(cat <<<--)
    assertEquals 0 $?
    diff "${_tmpdir}/AA.result" <(cat <<<AA)
    assertEquals 0 $?
    diff "${_tmpdir}/--Z.result" <(cat <<<--Z)
    assertEquals 0 $?
    diff "${_tmpdir}/BB.result" <(cat <<<BB)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f ${_tmpdir}/*.result

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "__" "4"
        wait_all_files_creation ${_tmpdir}/{--,AA,--Z,BB}.result
        diff "${_tmpdir}/--.result" <(cat <<<--)
        assertEquals 0 $?
        diff "${_tmpdir}/AA.result" <(cat <<<AA)
        assertEquals 0 $?
        diff "${_tmpdir}/--Z.result" <(cat <<<--Z)
        assertEquals 0 $?
        diff "${_tmpdir}/BB.result" <(cat <<<BB)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f ${_tmpdir}/*.result
    }
}

test_desync_option_1() {
    # If tmux version is less than 1.9, skip this test.
    if (is_less_than "1.9");then
        echo "Skip this test for $(tmux_version_number)." >&2
        echo 'Because there is no way to check whether the window has synchronize-panes or not.' >&2
        echo '"#{pane_synchronnized}" is not yet implemented.' >&2
        echo 'Ref (format.c): https://github.com/tmux/tmux/compare/1.8...1.9#diff-3acde89642f1d5cccab8319fac95e43fR557' >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    # synchronize-panes on
    _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
    printf "\n $ $_cmd\n"
    eval "$_cmd"
    # ${EXEC} -I@ -S $_socket_file -c "echo @" --no-attach -- AA BB CC DD
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Match
    assertEquals 0 $?
    close_tmux_session "$_socket_file"

    # synchronize-panes off
    _cmd="${EXEC} -d -I@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
    printf "\n $ $_cmd\n"
    eval "$_cmd"
    # ${EXEC} -d -I@ -S $_socket_file -c "echo @" --no-attach -- AA BB CC DD
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Unmach
    assertEquals 1 $?
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        # synchronize-panes on
        _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        # Match
        assertEquals 0 $?
        close_tmux_session "$_socket_file"

        # synchronize-panes off
        _cmd="${EXEC} -d -I@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        # Unmach
        assertEquals 1 $?
        close_tmux_session "$_socket_file"
    }
}

# This test uses continuous options like '-dI@'
test_desync_option_2() {
    # If tmux version is less than 1.9, skip this test.
    if (is_less_than "1.9");then
        echo "Skip this test for $(tmux_version_number)." >&2
        echo 'Because there is no way to check whether the window has synchronize-panes or not.' >&2
        echo '"#{pane_synchronnized}" is not yet implemented.' >&2
        echo 'Ref (format.c): https://github.com/tmux/tmux/compare/1.8...1.9#diff-3acde89642f1d5cccab8319fac95e43fR557' >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    # synchronize-panes on
    _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
    printf "\n $ $_cmd\n"
    # ${EXEC} -I@ -S $_socket_file -c "echo @" --no-attach -- AA BB CC DD
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Match
    assertEquals 0 $?
    close_tmux_session "$_socket_file"

    # synchronize-panes off
    _cmd="${EXEC} -I@ -S $_socket_file -dc \"echo @\" --no-attach -- AA BB CC DD"
    printf "\n $ $_cmd\n"
    # ${EXEC} -I@ -S $_socket_file -dc "echo @" --no-attach -- AA BB CC DD
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Unmach
    assertEquals 1 $?
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        # synchronize-panes on
        _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        # Match
        assertEquals 0 $?
        close_tmux_session "$_socket_file"

        # synchronize-panes off
        _cmd="${EXEC} -dI@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        # Unmach
        assertEquals 1 $?
        close_tmux_session "$_socket_file"
    }
}

test_failed_creat_directory() {
    local _log_dir="${SHUNIT_TMPDIR}/dirA/dirB"
    local _cmd="${EXEC} --log=$_log_dir 1 2 3"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "20" "$?"
}

test_non_writable_directory() {
    local _user=${USER:-$(whoami)}
    echo "USER:$_user"
    if [ "$_user" = "root" ]; then
        echo 'This test cannot be done by root. Skip.' 1>&2
        return 0
    fi
    local _log_dir="${SHUNIT_TMPDIR}/log_dir"
    mkdir $_log_dir
    chmod 400 $_log_dir
    local _cmd="${EXEC} --log=$_log_dir 1 2 3"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "21" "$?"
}

test_insufficient_cmd() {
    _XP_DEPENDENCIES="hogehoge123 cat" ${EXEC} 1 2 3
    assertEquals "127" "$?"
}

test_version() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -V";
    printf "\n $ $_cmd\n"
    $_cmd | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    _cmd="${EXEC} --version";
    printf "\n $ $_cmd\n"
    $_cmd | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
    assertEquals "0" "$?"

    : "In TMUX session" && {
        _cmd="${EXEC} -V";
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "$_cmd"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
        assertEquals "0" "$?"
        close_tmux_session $_socket_file

        _cmd="${EXEC} --version";
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "$_cmd"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} [0-9]+\.[0-9]+\.[0-9]+"
        assertEquals "0" "$?"
        close_tmux_session $_socket_file
    }
}

test_help() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -h";
    printf "\n $ $_cmd\n"
    ${_cmd} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    _cmd="${EXEC} --help";
    printf "\n $ $_cmd\n"
    ${_cmd} | grep -q "${BIN_NAME} \[OPTIONS\] .*"
    assertEquals "0" "$?"

    : "In TMUX session" && {
        # "| head " is added to prevent that the result exceeds the buffer limit of TMUX.
        _cmd="${EXEC} -h | head"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "${_cmd}"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} \[OPTIONS\] .*"
        assertEquals "0" "$?"
        close_tmux_session $_socket_file

        _cmd="${EXEC} --help | head"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "${_cmd}"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} \[OPTIONS\] .*"
        assertEquals "0" "$?"
        close_tmux_session $_socket_file
    }
}

test_start_separation() {
    local _window_name=""
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    # Run this test if the version is more than 1.7.
    if is_less_than "1.8" ;then
        echo "Skip this test for $(tmux -V)." >&2
        echo "Because tmux 1.6 and 1.7 does not work properly without attached tmux session." >&2
    else
        # It is required to attach and detach after that.
        _cmd="${EXEC} -S $_socket_file -I@ -c 'echo @ && tmux detach-client' AAAA BBBB"
        printf "\n $ $_cmd\n"
        ${EXEC} -S $_socket_file -I@ -c 'echo @ && tmux detach-client' AAAA BBBB

        wait_panes_separation "$_socket_file" "AAAA" "2"
        # Number of window is 1
        assertEquals "1" "$(tmux -S $_socket_file list-windows -F '#{window_name}' | grep -c .)"
        close_tmux_session "$_socket_file"
    fi

    # This case works on 1.6 and 1.7.
    # Because even --no-attach option exists, parent's tmux session is attached.
    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        tmux -S $_socket_file list-windows
        # There must be 2 windows -- default window & new window.
        assertEquals "2" "$(tmux -S $_socket_file list-windows | grep -c .)"
        close_tmux_session "$_socket_file"
    }
}

test_divide_two_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_three_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB CCCC"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_three_panes_tiled() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file -lt --no-attach AAAA BBBB CCCC"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file -l t --no-attach AAAA BBBB CCCC"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_four_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB CCCC DDDD"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "4"
    divide_four_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        divide_four_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_four_panes_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="echo  AAAA BBBB CCCC DDDD | xargs -n 1 | ${EXEC} -S $_socket_file"
    printf "\n $ $_cmd\n"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "4"
    divide_four_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="echo  AAAA BBBB CCCC DDDD | xargs -n 1 | ${EXEC}"
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        divide_four_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_five_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB CCCC DDDD EEEE"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "5"
    divide_five_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "5"
        divide_five_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_divide_five_panes_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="echo AAAA BBBB CCCC DDDD EEEE | xargs -n 1 | ${EXEC} -S $_socket_file"
    printf "\n $ $_cmd\n"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "5"
    divide_five_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        _cmd="echo AAAA BBBB CCCC DDDD EEEE | xargs -n 1 | ${EXEC}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "5"
        divide_five_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

test_command_option() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -S $_socket_file -c 'seq {} > ${_tmpdir}/{}.result' --no-attach 3 4 5"
    printf "\n $ $_cmd\n"
    ${EXEC} -S $_socket_file -c "seq {} > ${_tmpdir}/{}.result" --no-attach 3 4 5
    wait_panes_separation "$_socket_file" "3" "3"
    wait_all_files_creation ${_tmpdir}/{3,4,5}.result
    diff "${_tmpdir}/3.result" <(seq 3)
    assertEquals 0 $?
    diff "${_tmpdir}/4.result" <(seq 4)
    assertEquals 0 $?
    diff "${_tmpdir}/5.result" <(seq 5)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f ${_tmpdir}/*.result

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "3" "3"
        wait_all_files_creation ${_tmpdir}/{3,4,5}.result
        diff "${_tmpdir}/3.result" <(seq 3)
        assertEquals 0 $?
        diff "${_tmpdir}/4.result" <(seq 4)
        assertEquals 0 $?
        diff "${_tmpdir}/5.result" <(seq 5)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f ${_tmpdir}/*.result
    }
}

test_repstr_command_option() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I@ -S $_socket_file -c \"seq @ > ${_tmpdir}/@.result\" --no-attach 3 4 5 6"
    printf "\n $ $_cmd\n"
    ${EXEC} -I@ -S $_socket_file -c "seq @ > ${_tmpdir}/@.result" --no-attach 3 4 5 6
    wait_panes_separation "$_socket_file" "3" "4"
    wait_all_files_creation ${_tmpdir}/{3,4,5,6}.result
    diff "${_tmpdir}/3.result" <(seq 3)
    assertEquals 0 $?
    diff "${_tmpdir}/4.result" <(seq 4)
    assertEquals 0 $?
    diff "${_tmpdir}/5.result" <(seq 5)
    assertEquals 0 $?
    diff "${_tmpdir}/6.result" <(seq 6)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f ${_tmpdir}/*.result

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "3" "4"
        wait_all_files_creation ${_tmpdir}/{3,4,5,6}.result
        diff "${_tmpdir}/3.result" <(seq 3)
        assertEquals 0 $?
        diff "${_tmpdir}/4.result" <(seq 4)
        assertEquals 0 $?
        diff "${_tmpdir}/5.result" <(seq 5)
        assertEquals 0 $?
        diff "${_tmpdir}/6.result" <(seq 6)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f ${_tmpdir}/*.result
    }
}

test_repstr_command_option_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I GE -S $_socket_file -c\"seq GE 10 | tail > ${_tmpdir}/GE.result\" --no-attach 3 4 5"
    printf "\n $ $_cmd\n"
    ${EXEC} -I GE -S $_socket_file -c"seq GE 10 | tail > ${_tmpdir}/GE.result" --no-attach 3 4 5
    wait_panes_separation "$_socket_file" "3" "3"
    wait_all_files_creation ${_tmpdir}/{3,4,5}.result
    diff "${_tmpdir}/3.result" <(seq 3 10 | tail)
    assertEquals 0 $?
    diff "${_tmpdir}/4.result" <(seq 4 10 | tail)
    assertEquals 0 $?
    diff "${_tmpdir}/5.result" <(seq 5 10 | tail)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f ${_tmpdir}/*.result

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "3" "3"
        wait_all_files_creation ${_tmpdir}/{3,4,5}.result
        diff "${_tmpdir}/3.result" <(seq 3 10 | tail)
        assertEquals 0 $?
        diff "${_tmpdir}/4.result" <(seq 4 10 | tail)
        assertEquals 0 $?
        diff "${_tmpdir}/5.result" <(seq 5 10 | tail)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f ${_tmpdir}/*.result
    }
}

test_log_option() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(tmux -V)." >&2
        echo "Because of following reasons." >&2
        echo "1. Logging feature does not work when tmux version 1.8 and tmux session is NOT attached. " >&2
        echo "2. If standard input is NOT a terminal, tmux session is NOT attached." >&2
        echo "3. As of March 2017, macOS machines on Travis CI does not have a terminal." >&2
        return 0
    fi
    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(tmux -V)." >&2
        echo "Because of the bug (https://github.com/tmux/tmux/issues/594)." >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _log_file=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    mkdir -p "${_tmpdir}/fin"

    _cmd="_XP_LOG_DIR=${_tmpdir}/logs ${EXEC} --log -I@ -S $_socket_file -c\"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" AAAA AAAA BBBB"
    printf "\n $ $_cmd\n"
    # Execute command (slightly different)
    _XP_LOG_DIR=${_tmpdir}/logs ${EXEC} --log -I@ -S $_socket_file -c"echo HOGE_@_ | sed s/HOGE/GEGE/ &&touch ${_tmpdir}/fin/@ && tmux detach-client" AAAA AAAA BBBB
    wait_panes_separation "$_socket_file" "AAAA" "3"
    wait_existing_file_number "${_tmpdir}/fin" "2"

    # Wait several seconds just in case.
    sleep 3
    ls ${_tmpdir}/logs | grep -E '^AAAA-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(ls ${_tmpdir}/logs | grep -E '^AAAA-1\.log\..*$')
    assertEquals 1 $(cat ${_tmpdir}/logs/$_log_file | grep -ac 'GEGE_AAAA_')

    ls ${_tmpdir}/logs | grep -E '^AAAA-2\.log\..*$'
    assertEquals 0 $?
    _log_file=$(ls ${_tmpdir}/logs | grep -E '^AAAA-2\.log\..*$')
    assertEquals 1 $(cat ${_tmpdir}/logs/$_log_file | grep -ac 'GEGE_AAAA_')

    ls ${_tmpdir}/logs | grep -E '^BBBB-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(ls ${_tmpdir}/logs | grep -E '^BBBB-1\.log\..*$')
    assertEquals 1 $(cat ${_tmpdir}/logs/$_log_file | grep -ac 'GEGE_BBBB_')

    close_tmux_session "$_socket_file"
    rm -f ${_tmpdir}/logs/*
    rmdir ${_tmpdir}/logs
    rm -f ${_tmpdir}/fin/*
    rmdir ${_tmpdir}/fin

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        wait_existing_file_number "${_tmpdir}/fin" "2"

        # Wait several seconds just in case.
        sleep 3
        ls ${_tmpdir}/logs | grep -E '^AAAA-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(ls ${_tmpdir}/logs | grep -E '^AAAA-1\.log\..*$')
        assertEquals 1 $(cat ${_tmpdir}/logs/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_tmpdir}/logs | grep -E '^AAAA-2\.log\..*$'
        assertEquals 0 $?
        _log_file=$(ls ${_tmpdir}/logs | grep -E '^AAAA-2\.log\..*$')
        assertEquals 1 $(cat ${_tmpdir}/logs/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_tmpdir}/logs | grep -E '^BBBB-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(ls ${_tmpdir}/logs | grep -E '^BBBB-1\.log\..*$')
        assertEquals 1 $(cat ${_tmpdir}/logs/$_log_file | grep -ac 'GEGE_BBBB_')

        close_tmux_session "$_socket_file"

        rm -f ${_tmpdir}/logs/*
        rmdir ${_tmpdir}/logs
        rm -f ${_tmpdir}/fin/*
        rmdir ${_tmpdir}/fin
    }
}

test_log_format_option() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(tmux -V)." >&2
        echo "Because of following reasons." >&2
        echo "1. Logging feature does not work when tmux version 1.8 and tmux session is NOT attached. " >&2
        echo "2. If standard input is NOT a terminal, tmux session is NOT attached." >&2
        echo "3. As of March 2017, macOS machines on Travis CI does not have a terminal." >&2
        return 0
    fi
    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(tmux_version_number)." >&2
        echo "Because of the bug (https://github.com/tmux/tmux/issues/594)." >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _log_file=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _logdir="${_tmpdir}/hoge"
    local _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    _cmd="${EXEC} --log=${_logdir} --log-format='[:ARG:]_%Y_[:ARG:]' -I@ -S $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" AAAA AAAA BBBB CCCC"
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    ${EXEC} --log=${_logdir} --log-format='[:ARG:]_%Y_[:ARG:]' -I@ -S $_socket_file -c "echo HOGE_@_ | sed s/HOGE/GEGE/&& touch ${_tmpdir}/fin/@ && tmux detach-client" AAAA AAAA BBBB CCCC
    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

    # Wait several seconds just in case.
    sleep 3
    ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

    ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

    ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_BBBB_')

    ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_CCCC_')

    close_tmux_session "$_socket_file"
    rm -f ${_logdir}/*
    rmdir ${_logdir}
    rm -f ${_tmpdir}/fin/*
    rmdir ${_tmpdir}/fin

    : "In TMUX session" && {
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

        # Wait several seconds just in case.
        sleep 3
        ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_BBBB_')

        ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_CCCC_')

        close_tmux_session "$_socket_file"
        rm -f ${_logdir}/*
        rmdir ${_logdir}
        rm -f ${_tmpdir}/fin/*
        rmdir ${_tmpdir}/fin
    }
}

test_log_format_option2() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(tmux -V)." >&2
        echo "Because of following reasons." >&2
        echo "1. Logging feature does not work when tmux version 1.8 and tmux session is NOT attached. " >&2
        echo "2. If standard input is NOT a terminal, tmux session is NOT attached." >&2
        echo "3. As of March 2017, macOS machines on Travis CI does not have a terminal." >&2
        return 0
    fi
    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(tmux_version_number)." >&2
        echo "Because of the bug (https://github.com/tmux/tmux/issues/594)." >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _log_file=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _logdir="${_tmpdir}/hoge"
    local _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    # Remove single quotation for --log-format.
    _cmd="_XP_LOG_DIR=${_logdir} ${EXEC} --log --log-format=[:ARG:]_%Y_[:ARG:] -I@ -S $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" AAAA AAAA BBBB CCCC"
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    _XP_LOG_DIR=${_logdir} ${EXEC} --log --log-format=[:ARG:]_%Y_[:ARG:] -I@ -S $_socket_file -c "echo HOGE_@_ | sed s/HOGE/GEGE/&& touch ${_tmpdir}/fin/@ && tmux detach-client" AAAA AAAA BBBB CCCC
    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

    # Wait several seconds just in case.
    sleep 3
    ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

    ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

    ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_BBBB_')

    ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_CCCC_')

    close_tmux_session "$_socket_file"
    rm -f ${_logdir}/*
    rmdir ${_logdir}
    rm -f ${_tmpdir}/fin/*
    rmdir ${_tmpdir}/fin

    : "In TMUX session" && {
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

        # Wait several seconds just in case.
        sleep 3
        ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_BBBB_')

        ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_CCCC_')

        close_tmux_session "$_socket_file"
        rm -f ${_logdir}/*
        rmdir ${_logdir}
        rm -f ${_tmpdir}/fin/*
        rmdir ${_tmpdir}/fin
    }
}

test_log_format_and_desync_option() {
    if (is_less_than "1.9");then
        echo "Skip this test for $(tmux_version_number)." >&2
        echo 'Because there is no way to check whether the window has synchronize-panes or not.' >&2
        echo '"#{pane_synchronnized}" is not yet implemented.' >&2
        echo 'Ref (format.c): https://github.com/tmux/tmux/compare/1.8...1.9#diff-3acde89642f1d5cccab8319fac95e43fR557' >&2
        return 0
    fi

    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(tmux_version_number)." >&2
        echo "Because of the bug (https://github.com/tmux/tmux/issues/594)." >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _log_file=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _logdir="${_tmpdir}/hoge"
    local _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    # Remove single quotation for --log-format.
    _cmd="_XP_LOG_DIR=${_logdir} ${EXEC} --log-format=[:ARG:]_%Y_[:ARG:] -I@ -dS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" AAAA AAAA BBBB CCCC"
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    _XP_LOG_DIR=${_logdir} ${EXEC} --log-format=[:ARG:]_%Y_[:ARG:] -I@ -dS $_socket_file -c "echo HOGE_@_ | sed s/HOGE/GEGE/&& touch ${_tmpdir}/fin/@ && tmux detach-client" AAAA AAAA BBBB CCCC
    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

    # Wait several seconds just in case.
    sleep 3
    ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

    ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

    ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_BBBB_')

    ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$"
    assertEquals 0 $?
    _log_file=$(ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$")
    assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_CCCC_')

    # Check synchronized or not
    echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    assertEquals 1 $?

    close_tmux_session "$_socket_file"
    rm -f ${_logdir}/*
    rmdir ${_logdir}
    rm -f ${_tmpdir}/fin/*
    rmdir ${_tmpdir}/fin

    : "In TMUX session" && {
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

        # Wait several seconds just in case.
        sleep 3
        ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_BBBB_')

        ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_CCCC_')

        # Check synchronized or not
        echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        assertEquals 1 $?

        close_tmux_session "$_socket_file"
        rm -f ${_logdir}/*
        rmdir ${_logdir}
        rm -f ${_tmpdir}/fin/*
        rmdir ${_tmpdir}/fin
    }
}

test_log_format_and_desync_option_pipe() {
    if (is_less_than "1.9");then
        echo "Skip this test for $(tmux_version_number)." >&2
        echo 'Because there is no way to check whether the window has synchronize-panes or not.' >&2
        echo '"#{pane_synchronnized}" is not yet implemented.' >&2
        echo 'Ref (format.c): https://github.com/tmux/tmux/compare/1.8...1.9#diff-3acde89642f1d5cccab8319fac95e43fR557' >&2
        return 0
    fi

    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(tmux_version_number)." >&2
        echo "Because of the bug (https://github.com/tmux/tmux/issues/594)." >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _log_file=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _logdir="${_tmpdir}/hoge"
    local _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    # Remove single quotation for --log-format.
    _cmd="echo AAAA AAAA BBBB CCCC | xargs -n 1 | _XP_LOG_DIR=${_logdir} ${EXEC} --log-format=[:ARG:]_%Y_[:ARG:] --log -I@ -dS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\""
    echo $'\n'" $ $_cmd"$'\n'

    # pipe mode only works in the tmux session
    : "In TMUX session" && {
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

        # Wait several seconds just in case.
        sleep 3
        ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_AAAA_')

        ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_BBBB_')

        ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(ls ${_logdir} | grep -E "^CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 $(cat ${_logdir}/$_log_file | grep -ac 'GEGE_CCCC_')

        # Check synchronized or not
        echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        assertEquals 1 $?

        close_tmux_session "$_socket_file"
        rm -f ${_logdir}/*
        rmdir ${_logdir}
        rm -f ${_tmpdir}/fin/*
        rmdir ${_tmpdir}/fin
    }
}

. ${THIS_DIR}/shunit2/source/2.1/src/shunit2
