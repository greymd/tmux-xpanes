#!/bin/bash
set -ue

readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%N}}")" && pwd)"
readonly BINMODE=755
readonly DOCMODE=644
readonly PREFIX="${1:-/usr/local}"
readonly PREFIX_BIN="${PREFIX}/bin"
readonly PREFIX_MAN="${PREFIX}/share/man/man1"

# Install (bin)
mkdir -p "${PREFIX_BIN}"
echo install -m "${BINMODE}" "${THIS_DIR}/bin/xpanes" "${PREFIX_BIN}/xpanes"
install -m "${BINMODE}" "${THIS_DIR}/bin/xpanes" "${PREFIX_BIN}/xpanes"
echo install -m "${BINMODE}" "${THIS_DIR}/bin/tmux-xpanes" "${PREFIX_BIN}/tmux-xpanes"
install -m "${BINMODE}" "${THIS_DIR}/bin/tmux-xpanes" "${PREFIX_BIN}/tmux-xpanes"

# Install (man)
mkdir -p "${PREFIX_MAN}"
echo install -m "${BINMODE}" "${THIS_DIR}/man/xpanes.1" "${PREFIX_MAN}/xpanes.1"
install -m "${BINMODE}" "${THIS_DIR}/man/xpanes.1" "${PREFIX_MAN}/xpanes.1"
echo install -m "${BINMODE}" "${THIS_DIR}/man/tmux-xpanes.1" "${PREFIX_MAN}/tmux-xpanes.1"
install -m "${BINMODE}" "${THIS_DIR}/man/tmux-xpanes.1" "${PREFIX_MAN}/tmux-xpanes.1"
