#!/bin/bash

# In bash,
# Use md2man (https://github.com/sunaku/md2man) to generate man file like this.
# Replace 'BOX DRAWINGS LIGHT VERTICAL' (U+2502) to Pipe 'VERTICAL LINE' (U+007C)
# Because of md2man's bug, Pipe may be replaced to another character.
md2man-roff man.md | tr $'\xe2\x94\x82' $'\x7c' > xpanes.1
