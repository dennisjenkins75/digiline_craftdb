#!/bin/bash

set -e

~/.luarocks/bin/mineunit --coverage --quiet
~/.luarocks/bin/mineunit --report
