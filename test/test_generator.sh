#!/bin/bash
set -eu
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")" && pwd)"

(
  cd "${THIS_DIR}"
  sed '/###:-:-:START_TESTING:-:-:###/,/###:-:-:END_TESTING:-:-:###/d' cases_all.sh > template.sh
  echo "$1" | tr , '\n' | sed 's/^/@case:\\s*/' | perl -nle 'print "perl -nle \"print if /$_\$/../^}/\" cases_all.sh"' | sh > cases.sh
  sed "/###:-:-:INSERT_TESTING:-:-:###/r ${THIS_DIR}/cases.sh" template.sh
  printf "\\033[32;1m \\n%s\\n%s\\n\\033[0m" "//////// FOLLOWING TEST CASES WILL BE EXECUTED ////////" "$(grep '@case:' -A2 cases.sh)" >&2
  rm cases.sh
  rm template.sh
)
