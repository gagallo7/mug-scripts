#!/bin/bash

echo "
insmod hello-1.ko

dmesg -w -H
" >> ~/.bashrc

urxvt
