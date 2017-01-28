#!/bin/bash

myfunc () {
    local repstr="$1" ;shift
    local cmd="$1" ;shift
    local hosts=($@)
    local num=$(($# - 1))
    local i=0

    echo "repstr:$repstr"
    echo "cmd:$cmd"
    echo "hosts:$hosts"
    echo "num:$num"
    echo "\$@:$@"

    for host in "$@"
    do
        echo "$(($((i++)) + 1)):"${cmd//$repstr/$host}
    done
}

myfunc "@" "echo @ hoge" "watashi" "anata" "ka na ta" "HANASE" "kin\"kin"
