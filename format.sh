#!/bin/bash

FORMAT="${HOME}/.luarocks/bin/lua-format"
TARGETS=$(find . -name "*.lua" -type f | sort)

[[ -x ${FORMAT} ]] && {
  ${FORMAT} \
    --in-place --indent-width=2 --no-use-tab \
    --no-keep-simple-control-block-one-line \
    --no-keep-simple-function-one-line \
    --extra-sep-at-table-end \
    ${TARGETS}
}
