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

function beginswith()
{
  case $2 in "$1"*)
    true;;
  *)
    false;;
  esac
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
elif ! [ -d "${CONDA_PREFIX}" ]; then
    printf "CONDA_PREFIX: $CONDA_PREFIX directory is not where I am expecting it to be. Did someone change CIVET_CONDA_PACKAGES= in the recipe?\n"
    exit 1
fi

# Get a topological sort of formulas we need to build
FORMULAS=`./get_formulas.py`
exitIfReturnCode $?
if [ -z "${FORMULAS}" ]; then
    printf "Nothing to build\n"
    # Exit with 0 so we continue to allow this PR to run (something other than recipes has changed)
    exit 0
fi

if [ `uname` = 'Linux' ]; then
    ARCH='linux-64'
else
    ARCH='osx-64'
fi
export BZ2DIR="${CONDA_PREFIX}/conda-bld/${ARCH}"

# PR's -copy binaries to HPCSC
if beginswith "Pull" "$CIVET_EVENT_CAUSE"; then
    printf "Uploading to HPC for further testing...\n"
    ssh -oStrictHostKeyChecking=no -q hpcsc.hpc.inl.gov mkdir -p /data/ssl/conda_packages/moose/${ARCH}
    print_and_run rsync -raz "$BZ2DIR" hpcsc.hpc.inl.gov:/data/ssl/conda_packages/moose/
    exitIfReturnCode $?

# Merges to devel -copy binaries to MOOSEFRAMEWORK.ORG
else
    printf "Uploading to mooseframework.org...\n"
    # Darwin machines (firewall rules prevent direct access to mooseframework.org)
    if [ "$ARCH" = 'osx-64' ]; then
        # Clean the hand off directory
        ssh -oStrictHostKeyChecking=no -q rod.inl.gov "rm -rf /raid/CONDA_MOOSE/${ARCH}"
        exitIfReturnCode $?
        rsync -raz "$BZ2DIR" rod.inl.gov:/raid/CONDA_MOOSE/
        exitIfReturnCode $?
        ssh -oStrictHostKeyChecking=no -q rod.inl.gov "ssh -q mooseframework.org mkdir -p /var/moose/conda/moose/${ARCH}; rsync -raz /raid/CONDA_MOOSE/${ARCH} mooseframework.org:/var/moose/conda/moose/"
        exitIfReturnCode $?

    # Rod (a linux machine with direct access to mooseframework.org)
    else
        ssh -oStrictHostKeyChecking=no -q mooseframework.org mkdir -p /var/moose/conda/moose/${ARCH}
        rsync -raz "$BZ2DIR" mooseframework.org:/var/moose/conda/moose/
        exitIfReturnCode $?
    fi
fi
exit 0
