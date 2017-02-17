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
readonly TEST_TMP="$THIS_DIR/test_tmp"

BIN_DIR="${THIS_DIR}/../bin/"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="./${BIN_NAME}"

tmux_version_number() {
    tmux -V | perl -anle 'print $F[1]'
}

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
    echo "send-keys: cd ${BIN_DIR} && $* && touch ${TMPDIR}/done" >&2
    # Same reason as the comments near "create_tmux_session".
    tmux -S $_socket_file send-keys "cd ${BIN_DIR} && $* && touch ${TMPDIR}/done && sleep 1 && tmux detach-client" C-m
    tmux -S $_socket_file attach-session
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

between_plus_minus_1() {
    echo "$(( ( $1 + 1 ) == $2 || $1 == $2 || ( $1 - 1 ) == $2 ))"
}

setUp(){
    cd ${BIN_DIR}
    mkdir -p $THIS_DIR/test_tmp
    echo ">>>>>>>>>>" >&2
}

tearDown(){
    rm -rf $THIS_DIR/test_tmp
    echo "<<<<<<<<<<" >&2
    echo >&2
}

###################### START TESTING ######################


test_invalid_args() {
    local _cmd="${EXEC} -Z"
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
    assertEquals "5" "$?"
}

test_hyphen_only() {
    local _cmd="${EXEC} --"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "5" "$?"
}

test_hyphen_and_option() {
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

test_desync_option() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    # synchronize-panes on
    _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
    printf "\n $ $_cmd\n"
    ${EXEC} -I@ -S $_socket_file -c "echo @" --no-attach -- AA BB CC DD
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    tmux -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Match
    assertEquals 0 $?
    close_tmux_session "$_socket_file"

    # synchronize-panes off
    _cmd="${EXEC} -d -I@ -S $_socket_file -c \"echo @\" --no-attach -- AA BB CC DD"
    printf "\n $ $_cmd\n"
    ${EXEC} -d -I@ -S $_socket_file -c "echo @" --no-attach -- AA BB CC DD
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

test_failed_creat_directory() {
    local _log_dir="${SHUNIT_TMPDIR}/dirA/dirB"
    local _cmd="${EXEC} --log=$_log_dir 1 2 3"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "20" "$?"
}

test_use_file_insteadof_directory() {
    local _log_dir="${SHUNIT_TMPDIR}/file"
    echo "dummy" > $_log_dir
    local _cmd="${EXEC} --log=$_log_dir 1 2 3"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "21" "$?"
}

test_non_writable_directory() {
    local _log_dir="${SHUNIT_TMPDIR}/log_dir"
    mkdir $_log_dir
    chmod -w $_log_dir
    local _cmd="${EXEC} --log=$_log_dir 1 2 3"
    printf "\n $ $_cmd\n"
    # execute
    $_cmd > /dev/null
    assertEquals "22" "$?"
}

test_insufficient_cmd() {
    XPANES_DEPENDENCIES="hogehoge123 cat" ${EXEC} 1 2 3
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

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "2"
    # Number of window is 1
    assertEquals "1" "$(tmux -S $_socket_file list-windows -F '#{window_name}' | grep -c .)"
    close_tmux_session "$_socket_file"

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

devide_two_panes_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(tmux -S $_socket_file list-windows -F '#{window_name}' | grep '^AAAA' | head -n 1)

    # Window should be devided like this.
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
    assertEquals 1 "$(between_plus_minus_1 $a_width $b_width)"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    echo "A:$a_height B:$b_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
}

test_devide_two_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "2"
    devide_two_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        devide_two_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

devide_three_panes_impl() {
    local _window_name=""
    _window_name="$(tmux -S $_socket_file list-windows -F '#{window_name}' | grep '^AAAA' | head -n 1)"

    # Window should be devided like this.
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
    assertEquals 1 "$(between_plus_minus_1 $a_width $b_width)"
    assertEquals 1 "$(( $(( $a_width + $b_width + 1 )) == $c_width ))"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==3')
    echo "A:$a_height B:$b_height C:$c_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(between_plus_minus_1 $c_height $a_height)"
}

test_devide_three_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB CCCC"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "3"
    devide_three_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        devide_three_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

devide_four_panes_impl() {
    local _window_name=""
    _window_name=$(tmux -S $_socket_file list-windows -F '#{window_name}' | grep '^AAAA' | head -n 1)

    # Window should be devided like this.
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
    assertEquals 1 "$(between_plus_minus_1 $a_width $b_width)"
    assertEquals 1 "$(between_plus_minus_1 $c_width $d_width)"

    echo "Check height"
    a_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==3')
    d_height=$(tmux -S $_socket_file list-panes -t "$_window_name" -F '#{pane_height}' | awk 'NR==4')
    echo "A:$a_height B:$b_height C:$c_height D:$d_height"
    # In this case, height must be same.
    assertEquals 1 "$(( $a_height == $b_height ))"
    assertEquals 1 "$(( $c_height == $d_height ))"
    assertEquals 1 "$(between_plus_minus_1 $a_height $c_height)"
    assertEquals 1 "$(between_plus_minus_1 $b_height $d_height)"
}

test_devide_four_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB CCCC DDDD"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "4"
    devide_four_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        devide_four_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

devide_five_panes_impl() {
    local _window_name=""
    _window_name=$(tmux -S $_socket_file list-windows -F '#{window_name}' | grep '^AAAA' | head -n 1)

    # Window should be devided like this.
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
    assertEquals 1 "$(between_plus_minus_1 $a_width $b_width)"
    assertEquals 1 "$(between_plus_minus_1 $c_width $d_width)"
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
    assertEquals 1 "$(between_plus_minus_1 $a_height $c_height)"
    assertEquals 1 "$(between_plus_minus_1 $b_height $d_height)"
    assertEquals 1 "$(between_plus_minus_1 $a_height $e_height)"
    assertEquals 1 "$(between_plus_minus_1 $c_height $e_height)"
}

test_devide_five_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --no-attach AAAA BBBB CCCC DDDD EEEE"
    printf "\n $ $_cmd\n"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "5"
    devide_five_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\n $ TMUX($_cmd)\n"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "5"
        devide_five_panes_impl "$_socket_file"
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

    _cmd="LOG_DIR=${_tmpdir}/logs ${EXEC} -l -I@ -S $_socket_file -c\"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" AAAA AAAA BBBB"
    printf "\n $ $_cmd\n"
    # Execute command (slightly different)
    LOG_DIR=${_tmpdir}/logs ${EXEC} -l -I@ -S $_socket_file -c"echo HOGE_@_ | sed s/HOGE/GEGE/ &&touch ${_tmpdir}/fin/@ && tmux detach-client" AAAA AAAA BBBB
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
    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(tmux -V)." >&2
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

. ${THIS_DIR}/shunit2/source/2.1/src/shunit2
