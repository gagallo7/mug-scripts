#!/bin/bash

# This shell module generates a graph with dot tool from graph-viz to represent
# the current VIMC topology

function findDot()
{
  which dot > /dev/null

  if (($? > 0))
  then
    echo "Please install graphviz in order to acquire the dot binary."
    exit 1
  fi
}

function main()
{
  set -x
  DEV=/dev/media0
  [ "$(whoami)" == "root" ] || SUDO='sudo env "PATH=$PATH"'
  rm /tmp/uvc.dot
  rm /tmp/uvc.ps
  ${SUDO} media-ctl -d $DEV --print-dot > /tmp/uvc.dot
  dot -Tps -o /tmp/uvc.ps /tmp/uvc.dot
  evince /tmp/uvc.ps &
  set -x
}

findDot
main $*
