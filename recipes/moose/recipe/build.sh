#!/bin/bash
set -eu
install -d $PREFIX/share
install -m 644 moose-env $PREFIX/share/moose
