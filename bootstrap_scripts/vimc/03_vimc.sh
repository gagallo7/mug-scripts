echo "

if modprobe vimc;
then
    export PATH=$PATH:/home/guilherme/usr/bin
    export PATH=$PATH:$PWD
    cd mug-scripts
    ./mug-config_topology.py total_top
    cd -
else
    echo 'Cannot install module vimc.'
    echo 'Cannot install module vimc.' >> /var/log/system
fi

" >> ~/.profile

source ~/.profile
