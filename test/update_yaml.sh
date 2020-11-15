#!/usr/bin/env bash
set -eu
readonly THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

sed -i '/START_INSERT/,/END_INSERT/d' "$THIS_DIR"/../.github/workflows/test.yml
pict "$THIS_DIR"/config.pict | sed 1d | sort -k1,2 -k3n | awk '{a[$1" "$2]=a[$1" "$2]" "$3}END{for(k in a){print k"    "a[k]}}' | sort -k1,1 | perl -anle 'print "- bash: \"$F[0]\"\n  tmux: \"$F[1]\"\n  cases: @{[join \",\", @F[2..$#F]]}"' | sed 's/^/          /' | sed -e '1i###START_INSERT###' -e '$a###END_INSERT###' > "$THIS_DIR"/tmp
sed -i "/include:/ r tmp" "$THIS_DIR"/../.github/workflows/test.yml
rm -f "$THIS_DIR"/tmp
