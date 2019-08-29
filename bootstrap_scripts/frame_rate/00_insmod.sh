#!/bin/bash

echo "
modprobe vimc
su - kvm_user
" >> ~/.profile

. ~/.profile
