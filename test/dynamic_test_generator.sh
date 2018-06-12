#!/bin/bash
sed '/###:-:-:START_TESTING:-:-:###/,/###:-:-:END_TESTING:-:-:###/d' test.sh > template.sh
echo 'test_append_arg_to_utility_pipe test_divide_four_panes test_divide_two_panes test_divide_two_panes_ev test_help test_invalid_args test_invalid_layout test_keep_allow_rename_opt test_maximum_window_name test_n_option test_start_separation test_tmux_path_invalid test_version' | fmt -1 | sed 's/^/@test: /' | perl -nle 'print "perl -nle \"print if /$_/../^}/\" test.sh"' | sh > cases.sh
sed '/###:-:-:INSERT_TESTING:-:-:###/r cases.sh' template.sh > tests4case.sh
rm cases.sh
rm template.sh
