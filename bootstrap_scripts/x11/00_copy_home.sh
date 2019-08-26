#!/bin/bash

if [[ ! "$USER" =~ "guilherme" ]]
then
    echo "HEY"
    #cp -r /home/guilherme/tmp/kvm_user/ -T ~/

    #echo "/tmp/roothome/ /home/guilherme/tmp/kvm_user/ bind 0 0"
    #rm -Rf /tmp/roothome
    #ln -s /home/kvm_user/ /tmp/roothome
    su kvm_user
else
    echo "Do not touch host account."
fi
