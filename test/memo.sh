sed -f <(cat test.sh | grep '^test_' | sed -n '1,/test_unsupported_version/p' | grep -oE '^[a-z_]*' | awk NF | awk '{print "s/^"$1"/_"$1"/"}') -i.bak test.sh
