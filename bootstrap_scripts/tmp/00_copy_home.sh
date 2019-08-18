#!/bin/bash

if [[ ! "$USER" =~ "guilherme" ]]
then
    echo "HEY"
    cp -r /home/guilherme/tmp/kvm_user/ -T ~/
else
    echo "Do not touch host account."
fi
