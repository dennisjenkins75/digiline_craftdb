#!/bin/bash

set -e

busted .
luacheck --quiet .
