# failed: test_no_more_options test_divide_five_panes_pipe
sed -f <(cat test.sh | grep '^test_' | sed -n '1,/test_unsupported_version/p' | grep -oE '^[a-z_]*' | awk NF | awk '{print "s/^"$1"/_"$1"/"}') -i.bak test.sh # passed
sed -f <(cat test.sh | grep '^test_' | sed -n '/^test_invalid_args()/,/^test_unsupported_version()/p' | grep -oE '^[a-z0-9_]*' | awk NF | awk '{print "s/^"$1"()/_"$1"()/"}') test.sh | grep -E '^_?test_' # failed
sed -f <(cat test.sh | grep '^test_' | sed -n '/^test_invalid_layout()/,/^test_unsupported_version()/p' | grep -oE '^[a-z0-9_]*' | awk NF | awk '{print "s/^"$1"()/_"$1"()/"}')  -i.bak.bak test.sh | grep -E '^_?test_'
