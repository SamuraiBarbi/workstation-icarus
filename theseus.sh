#!/bin/bash

tmp=$(virsh list --all | grep " theseus " | awk '{ print $3}')
if ([ "x$tmp" == "shut" ] || [ "x$tmp" != "xrunning" ])
then
    sudo rm -f /dev/shm/looking-glass
    touch /dev/shm/looking-glass
    sudo chown owner:kvm /dev/shm/looking-glass
    sudo chmod 660 /dev/shm/looking-glass
    virsh start theseus
    sleep 25
fi
$HOME/.virtualmachine/LookingGlass/client/build/looking-glass-client app:shmFile=/dev/shm/looking-glass win:showFPS=yes win:keepAspect=yes win:maximize=yes win:size=4096x2160 win:borderless=yes win:title=Theseus >/dev/null 2>&1 &
$HOME/.virtualmachine/Scream/Receivers/unix/client/build/scream -v -i virbr0 >/dev/null 2>&1 &
wait -n
pkill -P $$
