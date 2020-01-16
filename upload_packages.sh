#!/bin/bash
function exitIfReturnCode()
{
  if [ "$1" != "0" ]; then
    echo "ERROR: exiting with code $1"
    exit $1
  fi
}
function print_cmd()
{
  local p="$PWD/"
  local b="$BUILD_ROOT/"
  local cwd=${p/#$b/BUILD_ROOT/}
  # Use terminal color codes. 33 is yellow. 32 is green
  printf "\e[33m$cwd\e[0m: \e[32m$*\e[0m\n"
}

function print_and_run()
{
  print_cmd $*
  "$@"
}

##### Sanity checks #####
if ! conda build --help > /dev/null 2>&1; then
    printf "conda build not available\n"
    exit 1
fi

if ! [ -d "recipes" ]; then
    printf "recipes directory not found. This script must be executed while in the staged-recipes repository.\n"
    exit 1
fi

if [ -z "$CONDA_PREFIX" ]; then
    printf "CONDA_PREFIX not set.\n"
    exit 1
fi

# Get a topological sort of formulas we need to build
FORMULAS=`./get_formulas.py`
exitIfReturnCode $?
NECESSARY=`./get_formulas.py -d`
exitIfReturnCode $?
if [ -z "${FORMULAS}" ]; then
    printf "Nothing to build\n"
    # Exit with 0 so we continue to allow this PR to enter the Devel branch (changes to something other
    # than formulas detected)
    exit 0
fi

if [ `uname` = 'Linux' ]; then
    ARCH='linux-64'
else
    ARCH='osx-64'
fi

for formula in ${FORMULAS}; do
    printf "Uploading ${formula}...\n"
    print_and_run scp "${CONDA_PREFIX}/conda-bld/${ARCH}/${formula}"*.bz2 mooseframework.org:/var/moose/conda/moose/${ARCH}/
    exitIfReturnCode $?
done
