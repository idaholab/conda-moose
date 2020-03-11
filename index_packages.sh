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

if beginswith "Pull" "$CIVET_EVENT_CAUSE"; then
  printf "Executing cleaning command on hpcsc..."
  ssh -oStrictHostKeyChecking=no -q hpcsc.hpc.inl.gov "source /etc/profile; /data/ssl/conda_packages/clear_channel.sh"
  printf "Executing indexing command on hpcsc..."
  ssh -oStrictHostKeyChecking=no -q hpcsc.hpc.inl.gov "source /etc/profile; /data/ssl/conda_packages/index_channels.sh"
  exitIfReturnCode $?
else
  printf "Executing indexing command on mooseframework.org..."
  ssh -oStrictHostKeyChecking=no -q mooseframework.org "source /etc/profile; /var/moose/conda/index_channels.sh"
  exitIfReturnCode $?
fi
exit 0
