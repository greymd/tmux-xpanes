#!/bin/bash

# Directory name of this file
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")" && pwd)"
readonly TEST_TMP="${THIS_DIR}/test_tmp"
readonly OLD_PATH="${PATH}"

# func 0 -- Restore old PATH.
# func 1 -- make PATH include tmux.
switch_tmux_path () {
  local _flag="${1:-0}"
  local _tmux_path="${2:-${TRAVIS_BUILD_DIR}/tmp/bin}"

  # --------------------
  # Testing for TravisCI
  # --------------------
  if [[ "${_flag}" -eq 0 ]]; then
    # Remove tmux from the PATH
    export PATH="${OLD_PATH}"
  elif [[ "${_flag}" -eq 1 ]]; then
    if type tmux &> /dev/null;then
      return 0
    fi
    # Make PATH include tmux
    export PATH="${_tmux_path}:${PATH}"
  fi
  return 0
}

tmux_version_number() {
    local _tmux_version=""
    if ! ${TMUX_EXEC} -V &> /dev/null; then
        # From tmux 0.9 to 1.3, there is no -V option.
        # Adjust all to 0.9
        _tmux_version="tmux 0.9"
    else
        _tmux_version="$(${TMUX_EXEC} -V)"
    fi
    echo "${_tmux_version}" | perl -anle 'printf $F[1]'
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
    if [[ "$( (tmux_version_number; echo; echo "$1") | sort -n | head -n 1)" != "$1" ]];then
        return 0
    else
        return 1
    fi
}

# !!Run this function at first!!
check_version() {
    switch_tmux_path 1
    local _exec="${BIN_DIR}${EXEC}"
    ${_exec} --dry-run A
    # If tmux version is less than 1.8, skip rest of the tests.
    if is_less_than "1.8" ;then
        echo "Skip rest of the tests." >&2
        echo "Because this version is out of support." >&2
        exit 0
    fi
    switch_tmux_path 0
}

create_tmux_session() {
    local _socket_file="$1"
    ${TMUX_EXEC} -S "${_socket_file}" new-session -d
    # Once attach tmux session and detach it.
    # Because, pipe-pane feature does not work with tmux 1.8 (it might be bug).
    # To run pipe-pane, it is necessary to attach the session.
    ${TMUX_EXEC} -S "${_socket_file}" send-keys "sleep 1 && ${TMUX_EXEC} detach-client" C-m
    ${TMUX_EXEC} -S "${_socket_file}" attach-session
}

is_allow_rename_value_on() {
  local _socket_file="${THIS_DIR}/.xpanes-shunit"
  local _value_allow_rename
  local _value_automatic_rename
  create_tmux_session "${_socket_file}"
  _value_allow_rename="$(${TMUX_EXEC} -S "${_socket_file}" show-window-options -g | awk '$1=="allow-rename"{print $2}')"
  _value_automatic_rename="$(${TMUX_EXEC} -S "${_socket_file}" show-window-options -g | awk '$1=="automatic-rename"{print $2}')"
  close_tmux_session "${_socket_file}"
  if [ "${_value_allow_rename}" = "on" ] ;then
    return 0
  fi
  if [ "${_value_automatic_rename}" = "on" ] ;then
    return 0
  fi
  return 1
}

exec_tmux_session() {
    local _socket_file="$1" ;shift
    # local _tmpdir=${SHUNIT_TMPDIR:-/tmp}
    # echo "send-keys: cd ${BIN_DIR} && $* && touch ${SHUNIT_TMPDIR}/done" >&2
    # Same reason as the comments near "create_tmux_session".
    ${TMUX_EXEC} -S "${_socket_file}" send-keys "cd ${BIN_DIR} && $* && touch ${SHUNIT_TMPDIR}/done && sleep 1 && ${TMUX_EXEC} detach-client" C-m
    ${TMUX_EXEC} -S "${_socket_file}" attach-session
    # Wait until tmux session is completely established.
    for i in $(seq 30) ;do
        # echo "exec_tmux_session: wait ${i} sec..."
        sleep 1
        if [ -e "${SHUNIT_TMPDIR}/done" ]; then
            rm -f "${SHUNIT_TMPDIR}/done"
            break
        fi
        # Tmux session does not work.
        if [ "${i}" -eq 30 ]; then
            echo "Tmux session timeout" >&2
            return 1
        fi
    done
}

capture_tmux_session() {
    local _socket_file="$1"
    ${TMUX_EXEC} -S "${_socket_file}" capture-pane
    ${TMUX_EXEC} -S "${_socket_file}" show-buffer
}

close_tmux_session() {
    local _socket_file="$1"
    ${TMUX_EXEC} -S "${_socket_file}" kill-session
    rm "${_socket_file}"
}

wait_panes_separation() {
    local _socket_file="$1"
    local _window_name_prefix="$2"
    local _expected_pane_num="$3"
    local _window_id=""
    local _pane_num=""
    local _wait_seconds=30
    # Wait until pane separation is completed
    for i in $(seq "${_wait_seconds}") ;do
        sleep 1
        ## tmux bug: tmux does not handle the window_name which has dot(.) at the begining of the name. Use window_id instead.
        _window_id=$(${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{window_name} #{window_id}' \
          | grep "^${_window_name_prefix}" \
          | head -n 1 \
          | perl -anle 'print $F[$#F]')
        printf "%s\\n" "wait_panes_separation: ${i} sec..." >&2
        ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{window_name} #{window_id}' >&2
        printf "_window_id:[%s]\\n" "${_window_id}"
        if [ -n "${_window_id}" ]; then
            # ${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_id}"
            _pane_num="$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_id}" | grep -c .)"
            # tmux -S "${_socket_file}" list-panes -t "${_window_name}"
            if [ "${_pane_num}" = "${_expected_pane_num}" ]; then
                ${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_id}" >&2
                # Wait several seconds to ensure the completion.
                # Even the number of panes equals to expected number,
                # the separation is not complated sometimes.
                sleep 3
                break
            fi
        fi
        # Still not separated.
        if [ "${i}" -eq "${_wait_seconds}" ]; then
            fail "wait_panes_separation: Too long time for window separation. Aborted." >&2
            return 1
        fi
    done
    return 0
}

wait_all_files_creation(){
    local _wait_seconds=30
    local _break=1
    # Wait until specific files are created.
    for i in $(seq "${_wait_seconds}") ;do
        sleep 1
        _break=1
        for f in "$@" ;do
            if ! [ -e "${f}" ]; then
                # echo "${f}:does not exist." >&2
                _break=0
            fi
        done
        if [ "${_break}" -eq 1 ]; then
            break
        fi
        if [ "${i}" -eq "${_wait_seconds}" ]; then
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
    for i in $(seq "${_wait_seconds}") ;do
        sleep 1
        _num_of_files=$(printf "%s\\n" "${_target_dir}"/* | grep -c .)
        if [ "${_num_of_files}" = "${_expected_num}" ]; then
            break
        fi
        if [ "${i}" -eq "${_wait_seconds}" ]; then
            echo "wait_existing_file_number: Test failed" >&2
            return 1
        fi
    done
    return 0
}

between_plus_minus() {
    local _range="$1"
    shift
    echo "$(( ( $1 + _range ) >= $2 && $2 >= ( $1 - _range ) ))"
}

# Returns the index of the window and number of it's panes.
# The reason why it does not use #{window_panes} is, tmux 1.6 does not support the format.
get_window_having_panes() {
  local _socket_file="$1"
  local _pane_num="$2"
  while read -r idx;
  do
    echo -n "${idx} "; ${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${idx}" -F '#{pane_index}' | grep -c .
  done < <(${TMUX_EXEC}  -S "${_socket_file}" list-windows -F '#{window_index}') \
    | awk '$2==pane_num{print $1}' pane_num="${_pane_num}" | head -n 1
}

divide_two_panes_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "${_socket_file}" "2")

    # Window should be divided like this.
    # +---+---+
    # | A | B |
    # +---+---+

    echo "Check number of panes"
    assertEquals 2 "$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" | grep -c .)"

    echo "Check width"
    a_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==2')
    echo "A:${a_width} B:${b_width}"
    # true:1, false:0
    # a_width +- 1 is b_width
    assertEquals 1 "$(between_plus_minus 1 "${a_width}" "${b_width}")"

    echo "Check height"
    a_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==2')
    echo "A:${a_height} B:${b_height}"
    # In this case, height must be same.
    assertEquals 1 "$(( a_height == b_height ))"
}

divide_three_panes_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "${_socket_file}" "3")

    # Window should be divided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # |   C   |
    # +---+---+

    echo "Check number of panes"
    assertEquals 3 "$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" | grep -c .)"

    echo "Check width"
    a_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==3')
    echo "A:${a_width} B:${b_width} C:${c_width}"
    assertEquals 1 "$(between_plus_minus 1 "${a_width}" "${b_width}")"
    assertEquals 1 "$(( $(( a_width + b_width + 1 )) == c_width ))"

    echo "Check height"
    a_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==3')
    echo "A:${a_height} B:${b_height} C:${c_height}"
    # In this case, height must be same.
    assertEquals 1 "$(( a_height == b_height ))"
    assertEquals 1 "$(between_plus_minus 1 "${c_height}" "${a_height}")"
}

divide_four_panes_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "${_socket_file}" "4")

    # Window should be divided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # | C | D |
    # +---+---+

    echo "Check width"
    a_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==3')
    d_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==4')
    echo "A:${a_width} B:${b_width} C:${c_width} D:${d_width}"

    assertEquals 1 "$((a_width == c_width))"
    assertEquals 1 "$((b_width == d_width))"
    assertEquals 1 "$(between_plus_minus 1 "${a_width}" "${b_width}")"
    assertEquals 1 "$(between_plus_minus 1 "${c_width}" "${d_width}")"

    echo "Check height"
    a_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==3')
    d_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==4')
    echo "A:${a_height} B:${b_height} C:${c_height} D:${d_height}"
    # In this case, height must be same.
    assertEquals 1 "$(( a_height == b_height ))"
    assertEquals 1 "$(( c_height == d_height ))"
    assertEquals 1 "$(between_plus_minus 1 "${a_height}" "${c_height}")"
    assertEquals 1 "$(between_plus_minus 1 "${b_height}" "${d_height}")"
}

divide_five_panes_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "${_socket_file}" "5")

    # Window should be divided like this.
    # +---+---+
    # | A | B |
    # +---+---+
    # | C | D |
    # +---+---+
    # |   E   |
    # +---+---+

    echo "Check width"
    a_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==3')
    d_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==4')
    e_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==5')
    echo "A:${a_width} B:${b_width} C:${c_width} D:${d_width} E:${e_width}"
    assertEquals 1 "$((a_width == c_width))"
    assertEquals 1 "$((b_width == d_width))"
    assertEquals 1 "$(between_plus_minus 1 "${a_width}" "${b_width}")"
    assertEquals 1 "$(between_plus_minus 1 "${c_width}" "${d_width}")"
    # Width of A + B is greater than E with 1 px. Because of the border.
    assertEquals 1 "$(( $(( a_width + b_width + 1 )) == e_width))"

    echo "Check height"
    a_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==3')
    d_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==4')
    e_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==5')
    echo "A:${a_height} B:${b_height} C:${c_height} D:${d_height} E:${e_height}"
    assertEquals 1 "$(( a_height == b_height ))"
    assertEquals 1 "$(( c_height == d_height ))"
    assertEquals 1 "$(between_plus_minus 1 "${a_height}" "${c_height}")"
    assertEquals 1 "$(between_plus_minus 1 "${b_height}" "${d_height}")"
    # On author's machine, following two tests does not pass with 1 ... somehow.
    assertEquals 1 "$(between_plus_minus 2 "${a_height}" "${e_height}")"
    assertEquals 1 "$(between_plus_minus 2 "${c_height}" "${e_height}")"
}

divide_two_panes_ev_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "${_socket_file}" "2")

    # Window should be divided like this.
    # +-------+
    # |   A   |
    # +-------+
    # |   B   |
    # +-------+

    echo "Check number of panes"
    assertEquals 2 "$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" | grep -c .)"

    echo "Check width"
    a_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==2')
    echo "A:${a_width} B:${b_width}"
    # true:1, false:0
    # In this case, height must be same.
    assertEquals 1 "$(( a_width == b_width ))"

    echo "Check height"
    a_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==2')
    echo "A:${a_height} B:${b_height}"
    # a_height +- 1 is b_height
    assertEquals 1 "$(between_plus_minus 1 "${a_height}" "${b_height}")"
}

divide_two_panes_eh_impl() {
    divide_two_panes_impl "$1"
}

divide_three_panes_ev_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "${_socket_file}" "3")

    # Window should be divided like this.
    # +-------+
    # |   A   |
    # +-------+
    # |   B   |
    # +-------+
    # |   C   |
    # +-------+

    echo "Check number of panes"
    assertEquals 3 "$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" | grep -c .)"

    echo "Check width"
    a_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==3')
    echo "A:${a_width} B:${b_width} C:${c_width}"
    # true:1, false:0
    # In this case, height must be same.
    assertEquals 1 "$(( a_width == b_width ))"
    assertEquals 1 "$(( b_width == c_width ))"

    echo "Check height"
    a_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==3')
    echo "A:${a_height} B:${b_height} C:${c_height}"

    assertEquals 1 "$(between_plus_minus 1 "${a_height}" "${b_height}")"
    assertEquals 1 "$(between_plus_minus 2 "${b_height}" "${c_height}")"
}

divide_three_panes_eh_impl() {
    local _socket_file="$1"
    local _window_name=""
    _window_name=$(get_window_having_panes "${_socket_file}" "3")

    # Window should be divided like this.
    # +---+---+---+
    # | A | B | C |
    # +---+---+---+

    echo "Check number of panes"
    assertEquals 3 "$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" | grep -c .)"

    echo "Check width"
    a_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==1')
    b_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==2')
    c_width=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_width}' | awk 'NR==3')
    echo "A:${a_width} B:${b_width} C:${c_width}"
    # true:1, false:0
    # In this case, height must be same.
    assertEquals 1 "$(between_plus_minus 1 "${a_width}" "${b_width}")"
    assertEquals 1 "$(between_plus_minus 2 "${b_width}" "${c_width}")"

    echo "Check height"
    a_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==1')
    b_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==2')
    c_height=$(${TMUX_EXEC} -S "${_socket_file}" list-panes -t "${_window_name}" -F '#{pane_height}' | awk 'NR==3')
    echo "A:${a_height} B:${b_height} C:${c_height}"

    assertEquals 1 "$(( a_height == b_height ))"
    assertEquals 1 "$(( b_height == c_height ))"
}

get_tmux_full_path () {
  switch_tmux_path 1
  command -v tmux
  switch_tmux_path 0
}

set_tmux_exec_randomly () {
  local _num
  local _exec
  _num=$((RANDOM % 4));
  _exec="$(get_tmux_full_path)"

  if [[ ${_num} -eq 0 ]];then
    export TMUX_XPANES_EXEC="${_exec} -2"
    switch_tmux_path 0
  elif [[ ${_num} -eq 1 ]];then
    export TMUX_XPANES_EXEC="${_exec}"
    switch_tmux_path 0
  elif [[ ${_num} -eq 2 ]];then
    unset TMUX_XPANES_EXEC
    switch_tmux_path 1
  elif [[ ${_num} -eq 3 ]];then
    export TMUX_XPANES_EXEC="tmux -2"
    switch_tmux_path 1
  fi
}

setUp(){
    cd "${BIN_DIR}" || exit
    mkdir -p "${TEST_TMP}"
    set_tmux_exec_randomly
    echo ">>>>>>>>>>" >&2
    echo "TMUX_XPANES_EXEC ... '${TMUX_XPANES_EXEC}'" >&2
}

tearDown(){
    rm -rf "${TEST_TMP}"
    echo "<<<<<<<<<<" >&2
    echo >&2
}

###:-:-:START_TESTING:-:-:###

# @case: 1
# @skip:
test_tmux_path_invalid() {
  # Only for TravisCI
  if [ -n "${TRAVIS_BUILD_DIR}" ]; then
    switch_tmux_path 0
    TMUX_XPANES_EXEC="tmux" ${EXEC} 1 2 3
    assertEquals "127" "$?"
  else
    echo "Skip test"
  fi
}

# @case: 2
# @skip: 1.8,2.3
test_normalize_log_directory() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
        echo "Because of following reasons." >&2
        echo "1. Logging feature does not work when tmux version 1.8 and tmux session is NOT attached. " >&2
        echo "2. If standard input is NOT a terminal, tmux session is NOT attached." >&2
        echo "3. As of March 2017, macOS machines on Travis CI does not have a terminal." >&2
        return 0
    fi
    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
        echo "Because of the bug (https://github.com/tmux/tmux/issues/594)." >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _log_file=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _homebak="${HOME}"

    mkdir -p "${_tmpdir}/fin"
    _cmd="export HOME=${_tmpdir}; ${EXEC} --log=~/logs/ -I@ -S ${_socket_file} -c\"echo HOGE_@_ | sed s/HOGE/GEGE/ &&touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA AAAA BBBB"
    printf "\\n%s\\n" "$ ${_cmd}"
    eval "${_cmd}"
    # Restore home
    export HOME="${_homebak}"
    wait_panes_separation "${_socket_file}" "AAAA" "3"
    wait_existing_file_number "${_tmpdir}/fin" "2"

    # Wait several seconds just in case.
    sleep 3
    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-1\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-2\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-2\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BBBB-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BBBB-1\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

    close_tmux_session "${_socket_file}"
    rm -f "${_tmpdir}"/logs/*
    rmdir "${_tmpdir}"/logs
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        printf "\\n%s\\n" "$ TMUX(${_cmd})"
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "${_socket_file}"
        exec_tmux_session "${_socket_file}" "${_cmd}"
        wait_panes_separation "${_socket_file}" "AAAA" "3"
        wait_existing_file_number "${_tmpdir}/fin" "2"

        # Wait several seconds just in case.
        sleep 3
        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-1\.log\..*$')
        assertEquals 1 "$( grep -ac 'GEGE_AAAA_' < "${_log_file}" )"

        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-2\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-2\.log\..*$')
        assertEquals 1 "$( grep -ac 'GEGE_AAAA_' < "${_log_file}" )"

        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BBBB-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BBBB-1\.log\..*$')
        assertEquals 1 "$( grep -ac 'GEGE_BBBB_' < "${_log_file}" )"

        close_tmux_session "${_socket_file}"

        rm -f "${_tmpdir}"/logs/*
        rmdir "${_tmpdir}"/logs
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 3
# @skip:
test_maximum_window_name() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _window_name=""
    local _arg
    _arg="$(yes | head -n 300 | tr -d '\n')"
    _cmd="${EXEC} -S \"${_socket_file}\" --stay \"${_arg}\""
    printf "\\n $ %s\\n" "$_cmd"
    eval "${_cmd}"
    wait_panes_separation "${_socket_file}" "y" '1'

    # Maximum window name is 200 characters + "-{PID}"
    ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{window_name}' | grep -qE '^y{200}-[0-9]+$'
    assertEquals "0" "$?"

    close_tmux_session "${_socket_file}"
}

# @case: 4
# @skip:
test_window_name_having_special_chars() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    local _expected_name='%.-&*_.co.jp'
    local _actual_name=""
    _cmd="${EXEC} -S $_socket_file --stay '$_expected_name'"
    printf "\\n $ %s\\n" "$_cmd"
    # ${TMUX_EXEC} -S "$_socket_file" set-window-option -g allow-rename off
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "%" '1'
    _actual_name=$(${TMUX_EXEC} -S "$_socket_file" list-windows -F '#{window_name}' | grep '%' | perl -pe 's/-[0-9]+$//g')
    close_tmux_session "$_socket_file"
    echo "Actual name:$_actual_name Expected name:$_expected_name"
    assertEquals "$_expected_name" "$_actual_name"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file '$_expected_name'"
        printf "\\n $ TMUX(%s)\\n" "$_cmd"
        create_tmux_session "$_socket_file"
        ${TMUX_EXEC} -S "$_socket_file" set-window-option -g allow-rename off
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "%" '1'
        _actual_name=$(${TMUX_EXEC} -S "$_socket_file" list-windows -F '#{window_name}' | grep '%' | perl -pe 's/-[0-9]+$//g')
        close_tmux_session "$_socket_file"
        echo "Actual name:$_actual_name Expected name:$_expected_name"
        assertEquals "$_expected_name" "$_actual_name"
    }
}

# @case: 5
# @skip:
test_divide_five_panes_special_chars() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --stay '%s' '%d' ':' '-' ''"
    printf "\\n $ %s\\n" "$_cmd"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" '%s' '5'
    divide_five_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    _cmd="${EXEC} -S $_socket_file --stay '.' '%' '' '' ';;'"
    printf "\\n $ %s\\n" "$_cmd"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" '\.' '5'
    divide_five_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file --stay '%s' '%d' ':' '-' ''"
        printf "\\n $ TMUX(%s)\\n" "$_cmd"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" '%s' '5'
        divide_five_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="${EXEC} -S $_socket_file --stay '.' '%' '' '' ';;'"
        printf "\\n $ TMUX(%s)\\n" "$_cmd"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" '\.' '5'
        divide_five_panes_impl "$_socket_file"
        # ${TMUX_EXEC} -S "$_socket_file" attach-session
        close_tmux_session "$_socket_file"
    }
}

# @case: 6
# @skip: 1.8,2.3
test_log_and_empty_arg() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
        echo "Because of following reasons." >&2
        echo "1. Logging feature does not work when tmux version 1.8 and tmux session is NOT attached. " >&2
        echo "2. If standard input is NOT a terminal, tmux session is NOT attached." >&2
        echo "3. As of March 2017, macOS machines on Travis CI does not have a terminal." >&2
        return 0
    fi
    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
        echo "Because of the bug (https://github.com/tmux/tmux/issues/594)." >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _log_file=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    mkdir -p "${_tmpdir}/fin"

    _cmd="XP_LOG_DIR=${_tmpdir}/logs ${EXEC} --log -I@ -S $_socket_file -c\"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" '' AA '' BB"
    printf "\\n $ %s\\n" "${_cmd}"
    # Execute command (slightly different)
    XP_LOG_DIR="${_tmpdir}"/logs ${EXEC} --log -I@ -S "$_socket_file" -c"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@  && ${TMUX_EXEC} detach-client" '' AA '' BB
    wait_panes_separation "$_socket_file" "EMPTY" "4"
    # AA and BB. Empty file is not created.
    wait_existing_file_number "${_tmpdir}/fin" "2"

    # Wait several seconds just in case.
    sleep 3
    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'EMPTY-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'EMPTY-1\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE__' < "${_log_file}")"

    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AA-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AA-1\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE_AA_' < "${_log_file}")"

    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'EMPTY-2\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'EMPTY-2\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE__' < "${_log_file}")"

    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BB-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BB-1\.log\..*$')
    assertEquals 1 "$( grep -ac 'GEGE_BB_' < "${_log_file}" )"

    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir}"/logs/*
    rmdir "${_tmpdir}"/logs
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        printf "\\n%s\\n" "$ TMUX(${_cmd})"
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "EMPTY" "4"
        # AA and BB. Empty file is not created.
        wait_existing_file_number "${_tmpdir}/fin" "2"

        # Wait several seconds just in case.
        sleep 3
        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'EMPTY-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'EMPTY-1\.log\..*$')
        assertEquals 1 "$(grep -ac 'GEGE__' < "${_log_file}")"

        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AA-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AA-1\.log\..*$')
        assertEquals 1 "$(grep -ac 'GEGE_AA_' < "${_log_file}")"

        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'EMPTY-2\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'EMPTY-2\.log\..*$')
        assertEquals 1 "$(grep -ac 'GEGE__' < "${_log_file}")"

        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BB-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BB-1\.log\..*$')
        assertEquals 1 "$(grep -ac 'GEGE_BB_' < "${_log_file}")"

        close_tmux_session "$_socket_file"

        rm -f "${_tmpdir}"/logs/*
        rmdir "${_tmpdir}"/logs
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 7
# @skip:
test_n_option() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --stay -n 2 -c 'seq {} > $TEST_TMP/\$(echo {} | tr -dc 0-9)' 2 4 6 8"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "2" "2"
    divide_two_panes_impl "$_socket_file"
    assertEquals "$(seq 2 4)" "$(cat "${TEST_TMP}"/24)"
    assertEquals "$(seq 6 8)" "$(cat "${TEST_TMP}"/68)"
    close_tmux_session "$_socket_file"
    rm -rf "${TEST_TMP:?}"/*

    # Run with empty arguments
    _cmd="${EXEC} -S $_socket_file --stay -c 'seq {} > $TEST_TMP/\$(echo {} | tr -dc 0-9)' -n 2 2 '' 4 '' 6 8 10"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "2" "4"
    divide_four_panes_impl "$_socket_file"
    assertEquals "$(seq 2)" "$(cat "${TEST_TMP}"/2)"
    assertEquals "$(seq 4)" "$(cat "${TEST_TMP}"/4)"
    assertEquals "$(seq 6 8)" "$(cat "${TEST_TMP}"/68)"
    assertEquals "$(seq 10)" "$(cat "${TEST_TMP}"/10)"
    close_tmux_session "$_socket_file"
    rm -rf "${TEST_TMP:?}"/*

    : "In TMUX session" && {
        _cmd="${EXEC} -n 2 -c 'seq {} > ${TEST_TMP}/\$(echo {} | tr -dc 0-9)' 2 4 6 8"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "2" "2"
        divide_two_panes_impl "$_socket_file"
        assertEquals "$(seq 2 4)" "$(cat "${TEST_TMP}"/24)"
        assertEquals "$(seq 6 8)" "$(cat "${TEST_TMP}"/68)"
        close_tmux_session "$_socket_file"

        _cmd="${EXEC} -c 'seq {} > ${TEST_TMP}/\$(echo {} | tr -dc 0-9)' -n 2 2 '' 4 '' 6 8 10"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "2" "4"
        divide_four_panes_impl "$_socket_file"
        assertEquals "$(seq 2)" "$(cat "${TEST_TMP}"/2)"
        assertEquals "$(seq 4)" "$(cat "${TEST_TMP}"/4)"
        assertEquals "$(seq 6 8)" "$(cat "${TEST_TMP}"/68)"
        assertEquals "$(seq 10)" "$(cat "${TEST_TMP}"/10)"
        close_tmux_session "$_socket_file"
    }
}

# @case: 8
# @skip:
test_n_option_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="echo 2 4 6 8 | ${EXEC} -S $_socket_file --stay -n 2 -c 'seq {} > ${TEST_TMP}/\$(echo {} | tr -dc 0-9)' "
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "2" "2"
    divide_two_panes_impl "$_socket_file"
    assertEquals "$(seq 2 4)" "$(cat "${TEST_TMP}"/24)"
    assertEquals "$(seq 6 8)" "$(cat "${TEST_TMP}"/68)"
    close_tmux_session "$_socket_file"
    rm -rf "${TEST_TMP:?}"/*

    # Run with empty lines
    _cmd=" echo -ne '2\\n\\n4\\n\\n6\\n \\n8 10' | ${EXEC} -S $_socket_file --stay -c 'seq {} > $TEST_TMP/\$(echo {} | tr -dc 0-9)' -n 2"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "2" "3"
    divide_three_panes_impl "$_socket_file"
    assertEquals "$(seq 2 4)" "$(cat "${TEST_TMP}"/24)"
    assertEquals "$(seq 6 8)" "$(cat "${TEST_TMP}"/68)"
    assertEquals "$(seq 10)" "$(cat "${TEST_TMP}"/10)"
    close_tmux_session "$_socket_file"
    rm -rf "${TEST_TMP:?}"/*

    : "In TMUX session" && {
        _cmd="${EXEC} -n 2 -c 'seq {} > $TEST_TMP/\$(echo {} | tr -dc 0-9)' 2 4 6 8"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "2" "2"
        divide_two_panes_impl "$_socket_file"
        assertEquals "$(seq 2 4)" "$(cat "${TEST_TMP}"/24)"
        assertEquals "$(seq 6 8)" "$(cat "${TEST_TMP}"/68)"
        close_tmux_session "$_socket_file"

        _cmd=" echo -ne '2\\n\\n4\\n\\n6\\n \\n8\\n\\t10' | ${EXEC} -n 2 -c 'seq {} > ${TEST_TMP}/\$(echo {} | tr -dc 0-9)'"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "2" "3"
        divide_three_panes_impl "$_socket_file"
        assertEquals "$(seq 2 4)" "$(cat "${TEST_TMP}"/24)"
        assertEquals "$(seq 6 8)" "$(cat "${TEST_TMP}"/68)"
        assertEquals "$(seq 10)" "$(cat "${TEST_TMP}"/10)"
        close_tmux_session "$_socket_file"
    }
}

# @case: 9
# @skip:
test_no_args_option() {
  local _cmd=""
  # Option which requires argument without any arguments
  _cmd="${EXEC} -n"
  printf "%s" "$_cmd"
  eval "${EXEC}" > /dev/null
  assertEquals "4" "$?"

  _cmd="echo a b c d e | ${EXEC} -n"
  printf "%s" "$_cmd"
  eval "${EXEC}" > /dev/null
  assertEquals "4" "$?"

  _cmd="${EXEC} -S"
  printf "%s" "$_cmd"
  eval "${EXEC}" > /dev/null
  assertEquals "4" "$?"

  _cmd="${EXEC} -l -c '{}'"
  printf "%s" "$_cmd"
  eval "${EXEC}" > /dev/null
  assertEquals "4" "$?"

  _cmd="seq 10 | ${EXEC} -l -c '{}'"
  printf "%s" "$_cmd"
  eval "${EXEC}" > /dev/null
  assertEquals "4" "$?"

  _cmd="${EXEC} -c"
  printf "%s" "$_cmd"
  eval "${EXEC}" > /dev/null
  assertEquals "4" "$?"
}

# @case: 10
# @skip:
test_keep_allow_rename_opt() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _allow_rename_status=""

    _cmd="${EXEC} -S $_socket_file AA BB CC DD EE"
    : "In TMUX session" && {

        # allow-rename on
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        ${TMUX_EXEC} -S "$_socket_file" set-window-option -g allow-rename on
        echo "allow-rename(before): on"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "5"
        _allow_rename_status="$(${TMUX_EXEC} -S "$_socket_file" show-window-options -g | awk '$1=="allow-rename"{print $2}')"
        echo "allow-rename(after): $_allow_rename_status"
        assertEquals "on" "$_allow_rename_status"
        close_tmux_session "$_socket_file"

        # allow-rename off
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        ${TMUX_EXEC} -S "$_socket_file" set-window-option -g allow-rename off
        echo "allow-rename(before): off"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "5"
        _allow_rename_status="$(${TMUX_EXEC} -S "$_socket_file" show-window-options -g | awk '$1=="allow-rename"{print $2}')"
        echo "allow-rename(after): $_allow_rename_status"
        assertEquals "off" "$_allow_rename_status"
        close_tmux_session "$_socket_file"
    }
}

# @case: 11
# @skip:
test_no_more_options() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I@ -S $_socket_file -c \"cat <<<@ > ${_tmpdir}/@.result\" --stay AA -l ev --help"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "${_cmd}"

    wait_panes_separation "$_socket_file" "AA" "4"
    wait_all_files_creation "${_tmpdir}"/{AA,-l,ev,--help}.result
    diff "${_tmpdir}/AA.result" <(cat <<<AA)
    assertEquals 0 $?
    diff "${_tmpdir}/-l.result" <(cat <<<-l)
    assertEquals 0 $?
    diff "${_tmpdir}/ev.result" <(cat <<<ev)
    assertEquals 0 $?
    diff "${_tmpdir}/--help.result" <(cat <<<--help)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir:?}"/*.result

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        wait_all_files_creation "${_tmpdir}"/{AA,-l,ev,--help}.result
        diff "${_tmpdir}/AA.result" <(cat <<<AA)
        assertEquals 0 $?
        diff "${_tmpdir}/-l.result" <(cat <<<-l)
        assertEquals 0 $?
        diff "${_tmpdir}/ev.result" <(cat <<<ev)
        assertEquals 0 $?
        diff "${_tmpdir}/--help.result" <(cat <<<--help)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir:?}"/*.result
    }
}

# @case: 12
# @skip:
test_invalid_layout() {
    # Option and arguments are continuous.
    ${EXEC} -lmem 1 2 3
    assertEquals "6" "$?"

    # Option and arguments are separated.
    ${EXEC} -l mem 1 2 3
    assertEquals "6" "$?"
}

# @case: 13
# @skip:
test_invalid_layout_pipe() {
    # Option and arguments are continuous.
    echo 1 2 3 | ${EXEC} -lmem
    assertEquals "6" "$?"

    # Option and arguments are separated.
    echo 1 2 3 | ${EXEC} -lmem
    assertEquals "6" "$?"
}


# @case: 14
# @skip:
test_divide_two_panes_ev() {
    # divide window into two panes even-vertically
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd

    # Run with normal mode
    _cmd="${EXEC} -l ev -S $_socket_file --stay AAAA BBBB"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "${_cmd}"
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    # Run with pipe mode
    _cmd="echo AAAA BBBB | xargs -n 1 | ${EXEC} -l ev -S $_socket_file --stay"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "${_cmd}"
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file -lev AAAA BBBB"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_ev_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="echo  AAAA BBBB | xargs -n 1 | ${EXEC} -S $_socket_file -lev"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_ev_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 15
# @skip:
test_divide_two_panes_eh() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    # Run with normal mode
    _cmd="${EXEC} -l eh -S $_socket_file --stay AAAA BBBB"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "${_cmd}"
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_eh_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    # Run with pipe mode
    _cmd="echo AAAA BBBB | xargs -n 1 | ${EXEC} -l eh -S $_socket_file --stay"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "${_cmd}"
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_eh_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file -leh AAAA BBBB"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_eh_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="echo AAAA BBBB | xargs -n 1 | ${EXEC} -S $_socket_file -leh"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_eh_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 16
# @skip:
test_divide_three_panes_ev() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -l ev -S $_socket_file --stay AAAA BBBB CCCC"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "${_cmd}"
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    _cmd="echo AAAA BBBB CCCC | xargs -n 1 | ${EXEC} -l ev -S $_socket_file --stay"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "${_cmd}"
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file -lev AAAA BBBB CCCC"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_ev_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="echo AAAA BBBB CCCC | xargs -n 1 | ${EXEC} -S $_socket_file -lev"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_ev_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 17
# @skip:
test_divide_three_panes_eh() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -l eh -S $_socket_file --stay AAAA BBBB CCCC"
    printf "\\n$ %s\\n" "${_cmd}"
    $_cmd
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_eh_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    _cmd="echo AAAA BBBB CCCC | xargs -n 1 | ${EXEC} -l eh -S $_socket_file --stay"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_eh_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {

        _cmd="${EXEC} -S $_socket_file -leh AAAA BBBB CCCC"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_eh_impl "$_socket_file"
        close_tmux_session "$_socket_file"

        _cmd="echo AAAA BBBB CCCC | xargs -n 1 | ${EXEC} -S $_socket_file -leh"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_eh_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 18
# @skip:
test_append_arg_to_utility_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    rm -rf "${TEST_TMP:?}"/tmp{1,2,3,4}
    mkdir "${TEST_TMP}"/tmp{1,2,3,4}

    _cmd="printf '$TEST_TMP/tmp1 $TEST_TMP/tmp2\\n$TEST_TMP/tmp3 $TEST_TMP/tmp4\\n' | ${EXEC} -S $_socket_file mv"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "$TEST_TMP" "2"
    divide_two_panes_impl "$_socket_file"

    find "${TEST_TMP}"
    [ -e "${TEST_TMP}"/tmp2/tmp1 ]
    assertEquals "0" "$?"

    [ -e "${TEST_TMP}"/tmp4/tmp3 ]
    assertEquals "0" "$?"

    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        rm -rf "${TEST_TMP:?}"/tmp{1,2,3,4}
        mkdir "${TEST_TMP}"/tmp{1,2,3,4}
        _cmd="printf '$TEST_TMP/tmp1 $TEST_TMP/tmp2\\n$TEST_TMP/tmp3 $TEST_TMP/tmp4\\n' | ${EXEC} mv"
        printf "\\n$ TMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "$TEST_TMP" "2"
        divide_two_panes_impl "$_socket_file"

        find "${TEST_TMP}"
        [ -e "${TEST_TMP}"/tmp2/tmp1 ]
        assertEquals "0" "$?"

        [ -e "${TEST_TMP}"/tmp4/tmp3 ]
        assertEquals "0" "$?"

        close_tmux_session "$_socket_file"
    }
}

# @case: 19
# @skip:
test_execute_option() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} --stay -e -S $_socket_file 'seq 5 15 > $TEST_TMP/1' 'echo Testing > $TEST_TMP/2'"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "seq" "2"
    divide_two_panes_impl "$_socket_file"
    assertEquals "$(seq 5 15)" "$(cat "${TEST_TMP}"/1)"
    assertEquals "$(printf "%s\\n" Testing)" "$(cat "${TEST_TMP}"/2)"
    close_tmux_session "$_socket_file"

    rm "${TEST_TMP:?}"/{1,2}
    # Use continuous option -eS.
    _cmd="${EXEC} --stay -eS $_socket_file 'seq 5 15 > $TEST_TMP/1' 'echo Testing > $TEST_TMP/2'"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "seq" "2"
    divide_two_panes_impl "$_socket_file"
    assertEquals "$(seq 5 15)" "$(cat "${TEST_TMP}"/1)"
    assertEquals "$(printf "%s\\n" Testing)" "$(cat "${TEST_TMP}"/2)"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -e 'seq 5 15 > $TEST_TMP/3' 'echo Testing > $TEST_TMP/4'"
        printf "\\n$ TMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "seq" "2"
        divide_two_panes_impl "$_socket_file"
        assertEquals "$(seq 5 15)" "$(cat "${TEST_TMP}"/3)"
        assertEquals "$(printf "%s\\n" Testing)" "$(cat "${TEST_TMP}"/4)"
        close_tmux_session "$_socket_file"
    }
}

# @case: 20
# @skip:
test_execute_option_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="printf '%s\\n%s\\n%s\\n' 'seq 5 15 > $TEST_TMP/1' 'echo Testing > $TEST_TMP/2' 'yes | head -n 3 > $TEST_TMP/3' | ${EXEC} -e -S $_socket_file"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "seq" "3"
    divide_three_panes_impl "$_socket_file"
    assertEquals "$(seq 5 15)" "$(cat "${TEST_TMP}"/1)"
    assertEquals "$(printf "%s\\n" Testing)" "$(cat "${TEST_TMP}"/2)"
    assertEquals "$(yes | head -n 3)" "$(cat "${TEST_TMP}"/3)"
    close_tmux_session "$_socket_file"

    rm "${TEST_TMP}"/{1,2,3}
    # Use continuous option -eS
    _cmd="printf '%s\\n%s\\n%s\\n' 'seq 5 15 > $TEST_TMP/1' 'echo Testing > $TEST_TMP/2' 'yes | head -n 3 > $TEST_TMP/3' | ${EXEC} -eS $_socket_file"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "seq" "3"
    divide_three_panes_impl "$_socket_file"
    assertEquals "$(seq 5 15)" "$(cat "${TEST_TMP}"/1)"
    assertEquals "$(printf "%s\\n" Testing)" "$(cat "${TEST_TMP}"/2)"
    assertEquals "$(yes | head -n 3)" "$(cat "${TEST_TMP}"/3)"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="printf '%s\\n%s\\n%s\\n' 'seq 5 15 > $TEST_TMP/4' 'echo Testing > $TEST_TMP/5' 'yes | head -n 3 > $TEST_TMP/6' | ${EXEC} -e"
        printf "\\n$ TMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "seq" "3"
        divide_three_panes_impl "$_socket_file"
        assertEquals "$(seq 5 15)" "$(cat "${TEST_TMP}"/4)"
        assertEquals "$(printf "%s\\n" Testing)" "$(cat "${TEST_TMP}"/5)"
        assertEquals "$(yes | head -n 3)" "$(cat "${TEST_TMP}"/6)"
        close_tmux_session "$_socket_file"
    }
}

# @case: 21
# @skip:
test_argument_and_utility_pipe() {
    echo 10 | ${EXEC} -c 'seq {}' factor {}
    assertEquals "4" "$?"
}

# @case: 22
# @skip:
test_unsupported_version() {
    XP_HOST_TMUX_VERSION="1.1" ${EXEC} --dry-run A 2>&1 | grep "officially supported"
    assertEquals "0" "$?"
}

# @case: 23
# @skip:
test_invalid_args() {
    local _cmd="${EXEC} -Z"
    printf "\\n$ %s\\n" "${_cmd}"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"

    # -n option only accepts numbers.
    _cmd="${EXEC} -n A"
    printf "\\n$ %s\\n" "${_cmd}"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

# @case: 24
# @skip:
test_valid_and_invalid_args() {
    local _cmd="${EXEC} -Zc @@@"
    printf "\\n$ %s\\n" "${_cmd}"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

# @case: 25
# @skip:
test_invalid_long_args() {
    local _cmd="${EXEC} --hogehoge"
    printf "\\n$ %s\\n" "${_cmd}"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

# @case: 26
# @skip:
test_no_args() {
    local _cmd="${EXEC}"
    printf "\\n$ %s\\n" "${_cmd}"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

# @case: 27
# @skip:
test_hyphen_only() {
    local _cmd="${EXEC} --"
    printf "\\n$ %s\\n" "${_cmd}"
    # execute
    $_cmd > /dev/null
    assertEquals "4" "$?"
}

# @case: 28
# @skip:
test_pipe_without_repstr() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd
    : "In TMUX session" && {
        _cmd="seq 5 10 | xargs -n 2 | ${EXEC} -S $_socket_file seq"
        # this executes following commands on panes.
        #   $ seq 5 6
        #   $ seq 7 8
        #   $ seq 9 10
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "5" "3"
        # check number of divided panes
        divide_three_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 29
# @skip:
test_hyphen_and_option1() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I@ -S $_socket_file -c \"cat <<<@ > ${_tmpdir}/@.result\" --stay -- -l -V -h -Z"
    printf "\\n$ %s\\n" "${_cmd}"
    ${EXEC} -I@ -S "${_socket_file}" -c "cat <<<@ > ${_tmpdir}/@.result" --stay -- -l -V -h -Z
    wait_panes_separation "$_socket_file" "-l" "4"
    wait_all_files_creation "${_tmpdir}"/{-l,-V,-h,-Z}.result
    diff "${_tmpdir}/-l.result" <(cat <<<-l)
    assertEquals 0 $?
    diff "${_tmpdir}/-V.result" <(cat <<<-V)
    assertEquals 0 $?
    diff "${_tmpdir}/-h.result" <(cat <<<-h)
    assertEquals 0 $?
    diff "${_tmpdir}/-Z.result" <(cat <<<-Z)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir:?}"/*.result

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "-l" "4"
        wait_all_files_creation "${_tmpdir}"/{-l,-V,-h,-Z}.result
        diff "${_tmpdir}/-l.result" <(cat <<<-l)
        assertEquals 0 $?
        diff "${_tmpdir}/-V.result" <(cat <<<-V)
        assertEquals 0 $?
        diff "${_tmpdir}/-h.result" <(cat <<<-h)
        assertEquals 0 $?
        diff "${_tmpdir}/-Z.result" <(cat <<<-Z)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir:?}"/*.result
    }
}

# @case: 30
# @skip:
test_hyphen_and_option2() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I@ -S $_socket_file -c \"cat <<<@ > ${_tmpdir}/@.result\" --stay -- -- AA --Z BB"
    printf "\\n$ %s\\n" "${_cmd}"
    ${EXEC} -I@ -S "${_socket_file}" -c "cat <<<@ > ${_tmpdir}/@.result" --stay -- -- AA --Z BB
    wait_panes_separation "$_socket_file" "--" "4"
    wait_all_files_creation "${_tmpdir}"/{--,AA,--Z,BB}.result
    diff "${_tmpdir}/--.result" <(cat <<<--)
    assertEquals 0 $?
    diff "${_tmpdir}/AA.result" <(cat <<<AA)
    assertEquals 0 $?
    diff "${_tmpdir}/--Z.result" <(cat <<<--Z)
    assertEquals 0 $?
    diff "${_tmpdir}/BB.result" <(cat <<<BB)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir:?}"/*.result

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "--" "4"
        wait_all_files_creation "${_tmpdir}"/{--,AA,--Z,BB}.result
        diff "${_tmpdir}/--.result" <(cat <<<--)
        assertEquals 0 $?
        diff "${_tmpdir}/AA.result" <(cat <<<AA)
        assertEquals 0 $?
        diff "${_tmpdir}/--Z.result" <(cat <<<--Z)
        assertEquals 0 $?
        diff "${_tmpdir}/BB.result" <(cat <<<BB)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir:?}"/*.result
    }
}

# @case: 31
# @skip: 1.8
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
    _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --stay -- AA BB CC DD"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    # ${EXEC} -I@ -S $_socket_file -c "echo @" --stay -- AA BB CC DD
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Match
    assertEquals 0 $?
    close_tmux_session "$_socket_file"

    # synchronize-panes off
    _cmd="${EXEC} -d -I@ -S $_socket_file -c \"echo @\" --stay -- AA BB CC DD"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    # ${EXEC} -d -I@ -S $_socket_file -c "echo @" --stay -- AA BB CC DD
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Unmach
    assertEquals 1 $?
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        # synchronize-panes on
        _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --stay -- AA BB CC DD"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        # Match
        assertEquals 0 $?
        close_tmux_session "$_socket_file"

        # synchronize-panes off
        _cmd="${EXEC} -d -I@ -S $_socket_file -c \"echo @\" --stay -- AA BB CC DD"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        # Unmach
        assertEquals 1 $?
        close_tmux_session "$_socket_file"
    }
}


# @case: 32
# @skip: 1.8
test_desync_option_2() {
    # This test uses continuous options like '-dI@'
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
    _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --stay -- AA BB CC DD"
    printf "\\n$ %s\\n" "${_cmd}"
    # ${EXEC} -I@ -S $_socket_file -c "echo @" --stay -- AA BB CC DD
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Match
    assertEquals 0 $?
    close_tmux_session "$_socket_file"

    # synchronize-panes off
    _cmd="${EXEC} -I@ -S $_socket_file -dc \"echo @\" --stay -- AA BB CC DD"
    printf "\\n$ %s\\n" "${_cmd}"
    # ${EXEC} -I@ -S $_socket_file -dc "echo @" --stay -- AA BB CC DD
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AA" "4"
    echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    # Unmach
    assertEquals 1 $?
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        # synchronize-panes on
        _cmd="${EXEC} -I@ -S $_socket_file -c \"echo @\" --stay -- AA BB CC DD"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        # Match
        assertEquals 0 $?
        close_tmux_session "$_socket_file"

        # synchronize-panes off
        _cmd="${EXEC} -dI@ -S $_socket_file -c \"echo @\" --stay -- AA BB CC DD"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AA" "4"
        echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        # Unmach
        assertEquals 1 $?
        close_tmux_session "$_socket_file"
    }
}

# @case: 33
# @skip:
test_failed_creat_directory() {
    local _log_dir="${SHUNIT_TMPDIR}/dirA/dirB"
    local _cmd="${EXEC} --log=$_log_dir 1 2 3"
    printf "\\n$ %s\\n" "${_cmd}"
    # execute
    $_cmd > /dev/null
    assertEquals "20" "$?"
}

# @case: 34
# @skip:
test_non_writable_directory() {
    local _user=${USER:-$(whoami)}
    echo "USER:$_user"
    if [ "$_user" = "root" ]; then
        echo 'This test cannot be done by root. Skip.' 1>&2
        return 0
    fi
    local _log_dir="${SHUNIT_TMPDIR}/log_dir"
    mkdir "${_log_dir}"
    chmod 400 "${_log_dir}"
    local _cmd="${EXEC} --log=${_log_dir} 1 2 3"
    printf "\\n$ %s\\n" "${_cmd}"
    # execute
    eval "${_cmd} > /dev/null"
    assertEquals "21" "$?"
}

# @case: 35
# @skip:
test_insufficient_cmd() {
    XP_DEPENDENCIES="hogehoge123 cat" ${EXEC} 1 2 3
    assertEquals "127" "$?"
}

# @case: 36
# @skip:
test_version() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -V";
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd" | grep -qE "${BIN_NAME} [0-9]+\\.[0-9]+\\.[0-9]+"
    assertEquals "0" "$?"

    _cmd="${EXEC} --version";
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd" | grep -qE "${BIN_NAME} [0-9]+\\.[0-9]+\\.[0-9]+"
    assertEquals "0" "$?"

    : "In TMUX session" && {
        _cmd="${EXEC} -V";
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "$_cmd"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} [0-9]+\\.[0-9]+\\.[0-9]+"
        assertEquals "0" "$?"
        close_tmux_session "${_socket_file}"

        _cmd="${EXEC} --version";
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "$_cmd"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} [0-9]+\\.[0-9]+\\.[0-9]+"
        assertEquals "0" "$?"
        close_tmux_session "${_socket_file}"
    }
}

# @case: 37
# @skip:
test_help() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -h";
    printf "\\n$ %s\\n" "${_cmd}"
    ${_cmd} | grep -q "${BIN_NAME} \\[OPTIONS\\] .*"
    assertEquals "0" "$?"

    _cmd="${EXEC} --help";
    printf "\\n$ %s\\n" "${_cmd}"
    ${_cmd} | grep -q "${BIN_NAME} \\[OPTIONS\\] .*"
    assertEquals "0" "$?"

    : "In TMUX session" && {
        # "| head " is added to prevent that the result exceeds the buffer limit of TMUX.
        _cmd="${EXEC} -h | head"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "${_cmd}"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} \\[OPTIONS\\] .*"
        assertEquals "0" "$?"
        close_tmux_session "${_socket_file}"

        _cmd="${EXEC} --help | head"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session  "$_socket_file" "${_cmd}"
        capture_tmux_session "$_socket_file" | grep -qE "${BIN_NAME} \\[OPTIONS\\] .*"
        assertEquals "0" "$?"
        close_tmux_session "${_socket_file}"
    }
}

# @case: 38
# @skip:
test_start_separation() {
    local _window_name=""
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    # Run this test if the version is more than 1.7.
    if is_less_than "1.8" ;then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
        echo "Because tmux 1.6 and 1.7 does not work properly without attached tmux session." >&2
    else
        # It is required to attach and detach after that.
        _cmd="${EXEC} -S \"$_socket_file\" -I@ -c 'echo @ && ${TMUX_EXEC} detach-client' AAAA BBBB"
        printf "\\n$ %s\\n" "${_cmd}"
        eval "$_cmd"

        wait_panes_separation "$_socket_file" "AAAA" "2"
        # Number of window is 1
        assertEquals "1" "$(${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{window_name}' | grep -c .)"
        close_tmux_session "$_socket_file"
    fi

    # This case works on 1.6 and 1.7.
    # Because even --stay option exists, parent's tmux session is attached.
    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file --stay AAAA BBBB"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        ${TMUX_EXEC} -S "${_socket_file}" list-windows
        # There must be 2 windows -- default window & new window.
        assertEquals "2" "$(${TMUX_EXEC} -S "${_socket_file}" list-windows | grep -c .)"
        close_tmux_session "$_socket_file"
    }
}

# @case: 39
# @skip:
test_divide_two_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --stay AAAA BBBB"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "2"
    divide_two_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        divide_two_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 40
# @skip:
test_divide_three_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --stay AAAA BBBB CCCC"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 41
# @skip:
test_divide_three_panes_tiled() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file -lt --stay AAAA BBBB CCCC"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "3"
    divide_three_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="${EXEC} -S $_socket_file -l t --stay AAAA BBBB CCCC"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        divide_three_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 42
# @skip:
test_divide_four_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --stay AAAA BBBB CCCC DDDD"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "4"
    divide_four_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        divide_four_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 43
# @skip:
test_divide_four_panes_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="echo  AAAA BBBB CCCC DDDD | xargs -n 1 | ${EXEC} -S $_socket_file"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "4"
    divide_four_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        _cmd="echo  AAAA BBBB CCCC DDDD | xargs -n 1 | ${EXEC}"
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        divide_four_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 44
# @skip:
test_divide_five_panes() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="${EXEC} -S $_socket_file --stay AAAA BBBB CCCC DDDD EEEE"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "5"
    divide_five_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "5"
        divide_five_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 45
# @skip:
test_divide_five_panes_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""

    _cmd="echo AAAA BBBB CCCC DDDD EEEE | xargs -n 1 | ${EXEC} -S $_socket_file"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "5"
    divide_five_panes_impl "$_socket_file"
    close_tmux_session "$_socket_file"

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        _cmd="echo AAAA BBBB CCCC DDDD EEEE | xargs -n 1 | ${EXEC}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "5"
        divide_five_panes_impl "$_socket_file"
        close_tmux_session "$_socket_file"
    }
}

# @case: 46
# @skip:
test_command_option() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -S \"$_socket_file\" -c 'seq {} > ${_tmpdir}/{}.result' --stay 3 4 5"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "3" "3"
    wait_all_files_creation "${_tmpdir}"/{3,4,5}.result
    diff "${_tmpdir}/3.result" <(seq 3)
    assertEquals 0 $?
    diff "${_tmpdir}/4.result" <(seq 4)
    assertEquals 0 $?
    diff "${_tmpdir}/5.result" <(seq 5)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir}"/*.result

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "3" "3"
        wait_all_files_creation "${_tmpdir}"/{3,4,5}.result
        diff "${_tmpdir}/3.result" <(seq 3)
        assertEquals 0 $?
        diff "${_tmpdir}/4.result" <(seq 4)
        assertEquals 0 $?
        diff "${_tmpdir}/5.result" <(seq 5)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir}"/*.result
    }
}

# @case: 47
# @skip:
test_repstr_command_option() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I@ -S \"$_socket_file\" -c \"seq @ > ${_tmpdir}/@.result\" --stay 3 4 5 6"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "3" "4"
    wait_all_files_creation "${_tmpdir}"/{3,4,5,6}.result
    diff "${_tmpdir}/3.result" <(seq 3)
    assertEquals 0 $?
    diff "${_tmpdir}/4.result" <(seq 4)
    assertEquals 0 $?
    diff "${_tmpdir}/5.result" <(seq 5)
    assertEquals 0 $?
    diff "${_tmpdir}/6.result" <(seq 6)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir}"/*.result

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "3" "4"
        wait_all_files_creation "${_tmpdir}"/{3,4,5,6}.result
        diff "${_tmpdir}/3.result" <(seq 3)
        assertEquals 0 $?
        diff "${_tmpdir}/4.result" <(seq 4)
        assertEquals 0 $?
        diff "${_tmpdir}/5.result" <(seq 5)
        assertEquals 0 $?
        diff "${_tmpdir}/6.result" <(seq 6)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir}"/*.result
    }
}

# @case: 48
# @skip:
test_repstr_command_option_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd
    local _tmpdir="${SHUNIT_TMPDIR}"

    _cmd="${EXEC} -I GE -S \"$_socket_file\" -c\"seq GE 10 | tail > ${_tmpdir}/GE.result\" --stay 3 4 5"
    printf "\\n$ %s\\n" "${_cmd}"
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "3" "3"
    wait_all_files_creation "${_tmpdir}"/{3,4,5}.result
    diff "${_tmpdir}/3.result" <(seq 3 10 | tail)
    assertEquals 0 $?
    diff "${_tmpdir}/4.result" <(seq 4 10 | tail)
    assertEquals 0 $?
    diff "${_tmpdir}/5.result" <(seq 5 10 | tail)
    assertEquals 0 $?
    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir}"/*.result

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "3" "3"
        wait_all_files_creation "${_tmpdir}"/{3,4,5}.result
        diff "${_tmpdir}/3.result" <(seq 3 10 | tail)
        assertEquals 0 $?
        diff "${_tmpdir}/4.result" <(seq 4 10 | tail)
        assertEquals 0 $?
        diff "${_tmpdir}/5.result" <(seq 5 10 | tail)
        assertEquals 0 $?
        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir}"/*.result
    }
}

# @case: 49
# @skip: 1.8,2.3
test_log_option() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
        echo "Because of following reasons." >&2
        echo "1. Logging feature does not work when tmux version 1.8 and tmux session is NOT attached. " >&2
        echo "2. If standard input is NOT a terminal, tmux session is NOT attached." >&2
        echo "3. As of March 2017, macOS machines on Travis CI does not have a terminal." >&2
        return 0
    fi
    if [[ "$(tmux_version_number)" == "2.3" ]];then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
        echo "Because of the bug (https://github.com/tmux/tmux/issues/594)." >&2
        return 0
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _log_file=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    mkdir -p "${_tmpdir}/fin"

    _cmd="XP_LOG_DIR=\"${_tmpdir}/logs\" ${EXEC} --log -I@ -S $_socket_file -c\"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA AAAA BBBB"
    printf "\\n$ %s\\n" "${_cmd}"
    # Execute command (slightly different)
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "3"
    wait_existing_file_number "${_tmpdir}/fin" "2"

    # Wait several seconds just in case.
    sleep 3
    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-1\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-2\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-2\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BBBB-1\.log\..*$'
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BBBB-1\.log\..*$')
    assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir}"/logs/*
    rmdir "${_tmpdir}"/logs
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        printf "\\nTMUX(%s)\\n" "${_cmd}"
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "3"
        wait_existing_file_number "${_tmpdir}/fin" "2"

        # Wait several seconds just in case.
        sleep 3
        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-1\.log\..*$')
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-2\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'AAAA-2\.log\..*$')
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BBBB-1\.log\..*$'
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_tmpdir}"/logs/* | grep -E 'BBBB-1\.log\..*$')
        assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

        close_tmux_session "$_socket_file"

        rm -f "${_tmpdir}"/logs/*
        rmdir "${_tmpdir}"/logs
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 50
# @skip: 1.8,2.3
test_log_format_option() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
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
    local _year
    _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    _cmd="${EXEC} --log=\"${_logdir}\" --log-format='[:ARG:]_%Y_[:ARG:]' -I@ -S $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA AAAA BBBB CCCC"
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

    # Wait several seconds just in case.
    sleep 3
    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
    assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
    assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

    close_tmux_session "$_socket_file"
    rm -f "${_logdir}"/*
    rmdir "${_logdir}"
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

        # Wait several seconds just in case.
        sleep 3
        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

        close_tmux_session "$_socket_file"
        rm -f "${_logdir}"/*
        rmdir "${_logdir}"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 51
# @skip: 1.8,2.3
test_log_format_env_var() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
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
    local _year
    mkdir -p "${_tmpdir}/fin"
    _year="$(date +%Y)$(date +%Y)"

    # Remove single quotation for --log-format.
    _cmd="TMUX_XPANES_LOG_FORMAT=\"[:ARG:]_%Y%Y_[:ARG:]\" XP_LOG_DIR=${_logdir} ${EXEC} --log -I@ -S $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA AAAA BBBB CCCC"
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

    # Wait several seconds just in case.
    sleep 3
    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
    assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
    assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

    close_tmux_session "$_socket_file"
    rm -f "${_logdir}"/*
    rmdir "${_logdir}"
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        _year="$(date +%Y)"

        ## Command line option is stronger than environment variable
        _cmd="export TMUX_XPANES_LOG_FORMAT=\"hage\"; XP_LOG_DIR=${_logdir} ${EXEC} --log --log-format=\"[:ARG:]_%Y_[:ARG:]\" -I@ -S $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA AAAA BBBB CCCC"
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

        # Reset just in case
        export TMUX_XPANES_LOG_FORMAT=

        # Wait several seconds just in case.
        sleep 3
        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

        close_tmux_session "$_socket_file"
        rm -f "${_logdir}"/*
        rmdir "${_logdir}"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 52
# @skip: 1.8,2.3
test_log_format_option2() {
    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
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
    local _year
    mkdir -p "${_tmpdir}/fin"
    _year="$(date +%Y)"

    # Remove single quotation for --log-format.
    _cmd="XP_LOG_DIR=${_logdir} ${EXEC} --log --log-format=[:ARG:]_%Y_[:ARG:] -I@ -S $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA AAAA BBBB CCCC"
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

    # Wait several seconds just in case.
    sleep 3
    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
    assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
    assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

    close_tmux_session "$_socket_file"
    rm -f "${_logdir}"/*
    rmdir "${_logdir}"
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

        # Wait several seconds just in case.
        sleep 3
        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

        close_tmux_session "$_socket_file"
        rm -f "${_logdir}"/*
        rmdir "${_logdir}"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 53
# @skip: 1.8,2.3
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
    local _year
    _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    # Remove single quotation for --log-format.
    _cmd="XP_LOG_DIR=\"${_logdir}\" ${EXEC} --log-format=[:ARG:]_%Y_[:ARG:] -I@ -dS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA AAAA BBBB CCCC"
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

    # Wait several seconds just in case.
    sleep 3
    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
    assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
    assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

    # Check synchronized or not
    echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
    ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
    assertEquals 1 $?

    close_tmux_session "$_socket_file"
    rm -f "${_logdir}"/*
    rmdir "${_logdir}"
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "3" # AAAA BBBB CCCC

        # Wait several seconds just in case.
        sleep 3
        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

        # Check synchronized or not
        echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        assertEquals 1 $?

        close_tmux_session "$_socket_file"
        rm -f "${_logdir}"/*
        rmdir "${_logdir}"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 54
# @skip: 1.8,2.3
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
    local _year
    _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    # Remove single quotation for --log-format.
    _cmd="echo AAAA AAAA BBBB CCCC | xargs -n 1 | XP_LOG_DIR=${_logdir} ${EXEC} --log-format=[:ARG:]_%Y_[:ARG:] --log -I@ -dS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\""

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
        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-2_${_year}_AAAA-2$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

        # Check synchronized or not
        echo "${TMUX_EXEC} -S $_socket_file list-windows -F '#{pane_synchronized}' | grep -q '^1$'"
        ${TMUX_EXEC} -S "${_socket_file}" list-windows -F '#{pane_synchronized}' | grep -q '^1$'
        assertEquals 1 $?

        close_tmux_session "$_socket_file"
        rm -f "${_logdir}"/*
        rmdir "${_logdir}"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 55
# @skip:
test_a_option_abort() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _exit_status
    mkdir -p "${_tmpdir}"

    _cmd="${EXEC} -S $_socket_file -a AAAA AAAA BBBB CCCC"
    eval "${_cmd}"
    # Run -a option with Normal mode1
    assertEquals 4 $?

    : "In TMUX session" && {
        _cmd="${_cmd} <<<n; echo \$? > ${_tmpdir}/status"
        echo $'\n'" $ TMUX($_cmd)"$'\n'

        create_tmux_session "$_socket_file"
        # Synchronize pane
        eval "${TMUX_EXEC} -S ${_socket_file} set-window-option synchronize-panes on"
        exec_tmux_session "$_socket_file" "$_cmd"

        # Wait several seconds just in case.
        sleep 1
        _exit_status="$(cat "${_tmpdir}/status")"
        assertEquals 30 "${_exit_status}"

        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir}/status"
    }
}

# @case: 56
# @skip: 1.8,2.3
test_a_option_with_log() {

    if [ "$(tmux_version_number)" == "1.8" ] ;then
        echo "Skip this test for $(${TMUX_EXEC} -V)." >&2
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
    local _year
    _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    # Remove single quotation for --log-format.
    _cmd="XP_LOG_DIR=\"${_logdir}\" ${EXEC} --log-format=\"[:ARG:]_%Y_[:ARG:]\" -I@ -dS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA BBBB"
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "2"
    wait_existing_file_number "${_tmpdir}/fin" "2" # AAAA BBBB

    # Append two more panes with log setting
    _cmd="${EXEC} -a --log-format=\"[:ARG:]_%Y_[:ARG:]\" -I@ -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" CCCC DDDD"
    exec_tmux_session "$_socket_file" "$_cmd"

    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "4" # AAAA BBBB CCCC DDDD
    divide_four_panes_impl "$_socket_file"

    # Wait several seconds just in case.
    sleep 3
    printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
    assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
    assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
    assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

    printf "%s\\n" "${_logdir}"/* | grep -E "DDDD-1_${_year}_DDDD-1$"
    assertEquals 0 $?
    _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "DDDD-1_${_year}_DDDD-1$")
    assertEquals 1 "$(grep -ac 'GEGE_DDDD_' < "${_log_file}")"

    close_tmux_session "$_socket_file"
    rm -f "${_logdir}"/*
    rmdir "${_logdir}"
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        _cmd="XP_LOG_DIR=\"${_logdir}\" ${EXEC} --log-format=\"[:ARG:]_%Y_[:ARG:]\" -I@ -dS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA BBBB"
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        wait_existing_file_number "${_tmpdir}/fin" "2" # AAAA BBBB

        # Append two more panes with log setting
        _cmd="XP_LOG_DIR=\"${_logdir}\" ${EXEC} -a --log-format=\"[:ARG:]_%Y_[:ARG:]\" -I@ -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" CCCC DDDD"
        exec_tmux_session "$_socket_file" "$_cmd"

        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "4" # AAAA BBBB CCCC DDDD
        divide_four_panes_impl "$_socket_file"

        # Wait several seconds just in case.
        sleep 3
        printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "AAAA-1_${_year}_AAAA-1$")
        assertEquals 1 "$(grep -ac 'GEGE_AAAA_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "BBBB-1_${_year}_BBBB-1$")
        assertEquals 1 "$(grep -ac 'GEGE_BBBB_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "CCCC-1_${_year}_CCCC-1$")
        assertEquals 1 "$(grep -ac 'GEGE_CCCC_' < "${_log_file}")"

        printf "%s\\n" "${_logdir}"/* | grep -E "DDDD-1_${_year}_DDDD-1$"
        assertEquals 0 $?
        _log_file=$(printf "%s\\n" "${_logdir}"/* | grep -E "DDDD-1_${_year}_DDDD-1$")
        assertEquals 1 "$(grep -ac 'GEGE_DDDD_' < "${_log_file}")"

        close_tmux_session "$_socket_file"
        rm -f "${_logdir}"/*
        rmdir "${_logdir}"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 57
# @skip:
test_a_option_with_pipe() {
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _year
    _year="$(date +%Y)"
    mkdir -p "${_tmpdir}/fin"

    # Remove single quotation for --log-format.
    _cmd="echo AAAA | ${EXEC} -d -S $_socket_file -c \"echo {} > ${_tmpdir}/fin/{}\""
    echo $'\n'" $ $_cmd"$'\n'
    # Execute command
    eval "$_cmd"
    wait_panes_separation "$_socket_file" "AAAA" "1"

    # Append two more panes with log setting
    _cmd="printf \"%s\\\\n\" \"echo BBBB > ${_tmpdir}/fin/BBBB\" \"echo CCCC > ${_tmpdir}/fin/CCCC\" | ${EXEC} -ae -lev -S $_socket_file"
    echo $'\n'" $ $_cmd"$'\n'
    exec_tmux_session "$_socket_file" "$_cmd"

    wait_panes_separation "$_socket_file" "AAAA" "3"
    wait_existing_file_number "${_tmpdir}/fin" "3"
    divide_three_panes_ev_impl "$_socket_file"

    # Wait several seconds just in case.
    sleep 3
    assertEquals "BBBB" "$(cat "${_tmpdir}/fin/BBBB")"
    assertEquals "CCCC" "$(cat "${_tmpdir}/fin/CCCC")"

    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        _cmd="echo AAAA | ${EXEC} -d -S $_socket_file -c \"echo {} > ${_tmpdir}/fin/{}\""
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "1"
        wait_existing_file_number "${_tmpdir}/fin" "1"

        # Append two more panes with log setting
        _cmd="printf \"%s\\\\n\" \"echo BBBB > ${_tmpdir}/fin/BBBB\" \"echo CCCC > ${_tmpdir}/fin/CCCC\" | ${EXEC} -a -S $_socket_file -l eh -e"
        exec_tmux_session "$_socket_file" "$_cmd"

        wait_panes_separation "$_socket_file" "AAAA" "3"
        wait_existing_file_number "${_tmpdir}/fin" "3"
        divide_three_panes_eh_impl "$_socket_file"

        # Wait several seconds just in case.
        sleep 3
        assertEquals "BBBB" "$(cat "${_tmpdir}/fin/BBBB")"
        assertEquals "CCCC" "$(cat "${_tmpdir}/fin/CCCC")"

        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 58
# @skip: 1.8,1.9,1.9a,2.0,2.1,2.2
test_t_and_a_option() {

    if (is_less_than "2.3");then
        echo "This test is better to be executed for $(tmux_version_number)." >&2
        echo 'Because -t option and "#{pane_title}" is not supported for this version.' >&2
        startSkipping
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _logdir="${_tmpdir}/hoge"
    mkdir -p "${_tmpdir}/fin"

    _cmd="TMUX_XPANES_PANE_BORDER_STATUS=top TMUX_XPANES_PANE_BORDER_FORMAT=\"[[[#T]]]\" ${EXEC} -t -I@ -dS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA BBBB"
    echo $'\n'" $ $_cmd"$'\n'
    eval "$_cmd"

    wait_panes_separation "$_socket_file" "AAAA" "2"
    wait_existing_file_number "${_tmpdir}/fin" "2" # AAAA BBBB

    assertEquals "AAAA@BBBB@" "$(eval "${TMUX_EXEC} -S ${_socket_file} list-panes -F '#{pane_title}'" | tr '\n' '@')"

    # Append two more panes with log setting
    _cmd="${EXEC} -a -I@ -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" CCCC DDDD"
    exec_tmux_session "$_socket_file" "$_cmd"

    wait_panes_separation "$_socket_file" "AAAA" "4"
    wait_existing_file_number "${_tmpdir}/fin" "4" # AAAA BBBB CCCC DDDD
    divide_four_panes_impl "$_socket_file"

    assertEquals "AAAA@BBBB@CCCC@DDDD@" "$(eval "${TMUX_EXEC} -S ${_socket_file} list-panes -F '#{pane_title}'" | tr '\n' '@')"

    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin

    : "In TMUX session" && {
        _cmd="${EXEC} -t -I@ -dS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" AAAA BBBB"
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        wait_existing_file_number "${_tmpdir}/fin" "2" # AAAA BBBB

        assertEquals "AAAA@BBBB@" "$(eval "${TMUX_EXEC} -S ${_socket_file} list-panes -F '#{pane_title}'" | tr '\n' '@')"

        # Append two more panes with log setting
        _cmd="${EXEC} -a -I@ -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@\" CCCC DDDD"
        exec_tmux_session "$_socket_file" "$_cmd"

        wait_panes_separation "$_socket_file" "AAAA" "4"
        wait_existing_file_number "${_tmpdir}/fin" "4" # AAAA BBBB CCCC DDDD
        divide_four_panes_impl "$_socket_file"

        assertEquals "AAAA@BBBB@CCCC@DDDD@" "$(eval "${TMUX_EXEC} -S ${_socket_file} list-panes -F '#{pane_title}'" | tr '\n' '@')"

        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 59
# @skip: 1.8,1.9,1.9a,2.0,2.1,2.2
test_t_and_a_option_pipe() {

    if (is_less_than "2.3");then
        echo "This test is better to be executed for $(tmux_version_number)." >&2
        echo 'Because -t option and "#{pane_title}" is not supported for this version.' >&2
        startSkipping
    fi

    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    local _logdir="${_tmpdir}/hoge"
    mkdir -p "${_tmpdir}/fin"

    : "In TMUX session" && {
        _cmd="printf \"%s\\\\n\" AAAA BBBB | ${EXEC} -I@ -tS $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\""
        echo $'\n'" $ TMUX($_cmd)"$'\n'
        mkdir -p "${_tmpdir}/fin"

        create_tmux_session "$_socket_file"
        exec_tmux_session "$_socket_file" "$_cmd"
        wait_panes_separation "$_socket_file" "AAAA" "2"
        wait_existing_file_number "${_tmpdir}/fin" "2"

        assertEquals "AAAA@BBBB@" "$(eval "${TMUX_EXEC} -S ${_socket_file} list-panes -F '#{pane_title}'" | tr '\n' '@')"

        close_tmux_session "$_socket_file"
        rm -f "${_tmpdir}"/fin/*
        rmdir "${_tmpdir}"/fin
    }
}

# @case: 60
# @skip: 2.3,2.4,2.5,2.6,2.7
test_t_option_warning() {
    if ! (is_less_than "2.3");then
        echo 'This tests checks -t option does not affect to other options' >&2
        echo "It is better to be executed less than 2.3." >&2
        return 0
    fi
    local _socket_file="${SHUNIT_TMPDIR}/.xpanes-shunit"
    local _cmd=""
    local _tmpdir="${SHUNIT_TMPDIR}"
    mkdir -p "${_tmpdir}/fin"

    _cmd="${EXEC} -t -lev -I@ -S $_socket_file -c \"echo HOGE_@_ | sed s/HOGE/GEGE/ && touch ${_tmpdir}/fin/@ && ${TMUX_EXEC} detach-client\" -- --AA BBBB CCCC"
    echo $'\n'" $ $_cmd"$'\n'
    eval "$_cmd" 2>&1 | grep 'Warning: -t option cannot be used by tmux version less than 2.3'
    assertEquals 0 $?   # Error message is properly shown

    wait_panes_separation "$_socket_file" "--AA" "3"
    wait_existing_file_number "${_tmpdir}/fin" "3"
    divide_three_panes_ev_impl "$_socket_file"
    close_tmux_session "$_socket_file"
    rm -f "${_tmpdir}"/fin/*
    rmdir "${_tmpdir}"/fin
}

###:-:-:END_TESTING:-:-:###

###:-:-:INSERT_TESTING:-:-:###

readonly TMUX_EXEC=$(get_tmux_full_path)
if [ -n "$BASH_VERSION" ]; then
  # This is bash
  echo "Testing for bash $BASH_VERSION"
  echo "tmux path: ${TMUX_EXEC}"
  echo "            $(${TMUX_EXEC} -V)"
  echo
fi

if [ -n "$TMUX" ]; then
 echo "[Error] Do NOT execute this test inside of TMUX session." >&2
 exit 1
fi

if [ -n "$TMUX_XPANES_LOG_FORMAT" ]; then
 echo "[Warning] TMUX_XPANES_LOG_FORMAT is defined." >&2
 echo "During the test, this variable is updated." >&2
 echo "    Executed: export TMUX_XPANES_LOG_FORMAT=" >&2
 echo "" >&2
 export TMUX_XPANES_LOG_FORMAT=
fi

if is_allow_rename_value_on; then
  echo "[Error] tmux's 'allow-rename' or 'automatic-rename' window option is now 'on'." >&2
  echo "Please make it off before starting testing." >&2
  echo "Execute this:
    echo 'set-window-option -g allow-rename off' >> ~/.tmux.conf
    echo 'set-window-option -g automatic-rename off' >> ~/.tmux.conf" >&2
  exit 1
fi

BIN_DIR="${THIS_DIR}/../bin/"
# Get repository name which equals to bin name.
# BIN_NAME="$(basename $(git rev-parse --show-toplevel))"
BIN_NAME="xpanes"
EXEC="./${BIN_NAME}"
check_version

# Test start
# shellcheck source=/dev/null
. "${THIS_DIR}/shunit2/source/2.1/src/shunit2"
