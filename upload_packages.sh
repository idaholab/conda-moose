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

if ! [ -d "${CONDA_PREFIX}" ]; then
    printf "CONDA_PACKAGE: $CONDA_PACKAGE directory is not where I am expecting it to be. Did someone change CONDA_PACKAGE= in the recipe?\n"
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
export BZ2DIR="${CONDA_PREFIX}/conda-bld/${ARCH}"

# DARWIN ONLY: Delete any stale packages residing in rod:/raid/CONDA_MOOSE
if [ "$ARCH" = 'osx-64' ]; then
    ssh -oStrictHostKeyChecking=no -q rod.inl.gov "rm -rf /raid/CONDA_MOOSE/*.bz2"
    exitIfReturnCode $?
fi

for formula in ${FORMULAS}; do
    bz_file=$(basename $formula)
    printf "Uploading ${bz_file}...\n"
    # DARWIN ONLY (firewall rules prevent pb-catalina from access mooseframework.org)
    if [ "$ARCH" = 'osx-64' ]; then
        # print what should be happening for Darwin machines, instead of printing all these 'scp to rod first' stuff
        print_cmd "scp ${BZ2DIR}/${bz_file}"*.bz2 mooseframework.org:/var/moose/conda/moose/${ARCH}/

        scp -q "${BZ2DIR}/${bz_file}"*.bz2 rod.inl.gov:/raid/CONDA_MOOSE/
        exitIfReturnCode $?
        ssh -oStrictHostKeyChecking=no -q rod.inl.gov "scp -q /raid/CONDA_MOOSE/${bz_file}"*.bz2 mooseframework.org:/home/moosetest/
        exitIfReturnCode $?
    else
        print_and_run scp "${BZ2DIR}/${bz_file}"*.bz2 mooseframework.org:/var/moose/conda/moose/${ARCH}/
        exitIfReturnCode $?
    fi
done

# DARWIN ONLY:  Delete Darwin packages from rod, now that we are finished.
if [ "$ARCH" = 'osx-64' ]; then
    ssh -oStrictHostKeyChecking=no -q rod.inl.gov "rm -rf /raid/CONDA_MOOSE/*.bz2"
    exitIfReturnCode $?
fi
exit 0
