#!/bin/bash

set -e

luacheck ./
~/.luarocks/bin/mineunit --coverage --quiet
~/.luarocks/bin/mineunit --report
