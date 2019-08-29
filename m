#!/bin/bash

BRANCH=$(git symbolic-ref --short HEAD)
if [[ "${BRANCH}" =~ frame ]]; then
    /usr/bin/make O=../output/vimc-frame-rate "$@"
else
    /usr/bin/make "$@"
fi
