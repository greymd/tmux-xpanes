#!/bin/bash
set -ue

readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
readonly PREFIX="${1:-/usr/local}"
readonly PREFIX_BIN="${PREFIX}/bin"
readonly PREFIX_MAN="${PREFIX}/share/man/man1"

# Uninstall (bin)
echo rm -f "${PREFIX_BIN}/xpanes"
rm -f "${PREFIX_BIN}/xpanes"
echo rm -f "${PREFIX_BIN}/tmux-xpanes"
rm -f "${PREFIX_BIN}/tmux-xpanes"

# Uninstall (man)
echo rm -f "${PREFIX_MAN}/xpanes.1"
rm -f "${PREFIX_MAN}/xpanes.1"
echo rm -f "${PREFIX_MAN}/tmux-xpanes.1"
rm -f "${PREFIX_MAN}/tmux-xpanes.1"
