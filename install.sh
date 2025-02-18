#!/usr/bin/env bash
set -ue

# shellcheck disable=SC2155
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
readonly BINMODE=755
readonly DOCMODE=644
readonly PREFIX="${1:-/usr/local}"
readonly PREFIX_BIN="${PREFIX}/bin"
readonly PREFIX_MAN="${PREFIX}/share/man/man1"

set -x

# Install (bin)
install -d "${PREFIX_BIN}"
install -m "${BINMODE}" "${THIS_DIR}/bin/xpanes" "${PREFIX_BIN}/xpanes"
install -m "${BINMODE}" "${THIS_DIR}/bin/tmux-xpanes" "${PREFIX_BIN}/tmux-xpanes"

# Install (man)
install -d "${PREFIX_MAN}"
install -m "${DOCMODE}" "${THIS_DIR}/man/xpanes.1" "${PREFIX_MAN}/xpanes.1"
install -m "${DOCMODE}" "${THIS_DIR}/man/tmux-xpanes.1" "${PREFIX_MAN}/tmux-xpanes.1"
