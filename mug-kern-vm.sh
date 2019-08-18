#!/bin/bash

set -eux

if [[ ! -d arch ]]; then
    echo "ERROR: This script should be executed in a linux directory"
    exit 1
fi

DIST=buster
IMG=$HOME/vm/"debian-${DIST}-fai".img
IMG_SIZE=10G
ISO=$HOME/vm/fai-debian-buster.iso
MNT=$HOME/vm/vm_mount
LOCK_FILE=../mount.lock
SHARE=../vm-share.dir
KERNEL=arch/x86_64/boot/bzImage

KVM="qemu-system-x86_64 -enable-kvm"
# KVM="/usr/bin/qemu-system-x86_64 -enable-kvm"

# PACKAGES TO INCLUDE IN THE IMG
# Base configuration
PKGS=openssh-server,xauth,xwayland
# Dev tools
PKGS=${PKGS},git,vim
# v4l-utils build dependencies
PKGS=${PKGS},dh-autoreconf,autotools-dev,gettext,graphviz,libasound2-dev,libtool,libjpeg-dev,qtbase5-dev,libudev-dev,libx11-dev,pkg-config,udev,qt5-default

function finish {
    echo "Gracefully finishing this script..."
    if [[ -f ${LOCK_FILE} ]]; then
        vm_umount
    fi
}

function check_lock {
    if [[ -f ${LOCK_FILE} ]]; then
        echo "Lock file exists, please umount the image before using it again"
        exit 1
    fi
}

function vm_mount {
    check_lock
    if [[ ! -d ${MNT} ]]; then
        echo "Creating folder ${MNT} to mount the image when required"
        mkdir ${MNT}
    fi

    if [ ! -n "$*" ]
    then
        local EXTRA_ARGS="-wi"
    fi

    while [ -n "$*" ]
    do
        if [ "new" = "$1" ]
        then
            sudo LIBGUESTFS_BACKEND=direct guestmount -a ${IMG} ${MNT} --rw -o dev -o exec -o nonempty
        fi

        shift
    done

    guestmount -a ${IMG} ${EXTRA_ARGS} ${MNT}

    local SUCCESS=$?
    if (( SUCCESS == 0 ))
    then
        echo "$IMG mounted at ${MNT}"
        touch ${LOCK_FILE}
    else
        echo "Something wrong happened when mounting ${MNT}"
    fi
}

function vm_umount {
    guestunmount ${MNT}
    local SUCCESS=$?
    if (( SUCCESS == 0 ))
    then
        echo "$IMG umounted from ${MNT}"
        rm -f $LOCK_FILE
        echo "Lock file removed"
    else
        echo "Something wrong happened when umounting ${MNT}"
    fi
}

function vmaker {
    sudo LIBGUESTFS_BACKEND=direct guestfish -a "$IMG" run   \
        : part-disk /dev/sda mbr        \
        : pvcreate /dev/sda1            \
        : vgcreate vmsys /dev/sda1      \
        : lvcreate root vmsys 5120      \
        : mkfs ext4 /dev/vmsys/root     \
        : mount /dev/vmsys/root /       \
        : mkdir-p /var/log              \
        : lvcreate varlog vmsys 2048    \
        : mkfs ext4 /dev/vmsys/varlog

    sudo LIBGUESTFS_BACKEND=direct guestmount -a "$IMG"      \
        -m /dev/vmsys/root              \
        -m /dev/vmsys/varlog:/var/log   \
        --rw -o dev "$MNT" -o nonempty
    }

function create_img {
    trap finish EXIT

    if [[ -f ${IMG} ]]; then
        echo "${IMG} already exists, nothing to do"
        exit 1
    fi

    sudo qemu-img create "${IMG}" "${IMG_SIZE}"
    #mkfs.ext4 -F "${IMG}"

    #vmaker
    vm_mount new

    #sudo debootstrap --include=${PKGS} ${DIST} ${MNT} http://deb.debian.org/debian/
    docker exec -it bootstrap vmdebootstrap --verbose --image=${IMG} --size=10g --distribution=${DIST} --grub --enable-dhcp --package=${PKGS} --owner=$USER

    sudo chown $USER ${IMG}
}

function config_img {
    vm_mount

  # Add host folder to mount automatically
  if [[ ! -d ${SHARE} ]]; then
      echo "Creating folder ${SHARE} to share files with the guest"
      mkdir -p ${SHARE}
      echo "This is a shared folder between the host and guest" > ${SHARE}/README
  fi
  echo "host-code /root/host 9p rw,sync,dirsync,relatime,access=client,trans=virtio 0 0" >> ${MNT}/etc/fstab

  # Add ssh key
  if [[ ! -f ~/.ssh/kern-vm-key ]]; then
      ssh-keygen -t rsa -N "" -f ~/.ssh/kern-vm-key -C root
  fi

  if [[ ! -d ${MNT}/root/.ssh ]]; then
      mkdir ${MNT}/root/.ssh
  fi
  cat ~/.ssh/kern-vm-key.pub >> ${MNT}/root/.ssh/authorized_keys

  # Enable X forward
  touch ${MNT}/root/.Xauthority

  vm_umount
}

function vm_launch_native {
    check_lock
    # Launch VM with the kernel it is already installed
    ${KVM} -hda ${IMG} \
        -fsdev local,id=fs1,path=${SHARE},security_model=none \
        -device virtio-9p-pci,fsdev=fs1,mount_tag=host-code \
        -net nic -net user,hostfwd=tcp::5555-:22 \
        -m size=4G
    }

function vm_launch_fai {
    check_lock
    # Launch VM with custom kernel
    ${KVM} \
        -fsdev local,id=fs1,path=${SHARE},security_model=none \
        -cdrom ${ISO} \
        -boot d \
        -device virtio-9p-pci,fsdev=fs1,mount_tag=host-code \
        -s \
        -smp 1 \
        -nographic \
        -net nic -net user,hostfwd=tcp::5555-:22 \
        -hda ${IMG} \
        -m size=4G
    }

function vm_launch {
    check_lock
    # Launch VM with custom kernel
    ${KVM} -drive format=raw,file=$IMG,if=virtio \
        -fsdev local,id=fs1,path=${SHARE},security_model=none \
        -device virtio-9p-pci,fsdev=fs1,mount_tag=host-code \
        -s \
        -smp 1 \
        -nographic \
        -kernel ${KERNEL} \
        -append "root=/dev/vda1 console=ttyS0" \
        -net nic -net user,hostfwd=tcp::5555-:22 \
        -m size=4G \
        -vnc :0
    }

function vm_launch_debug {
    check_lock
    # Launch VM with custom kernel
    ${KVM} -drive format=raw,file=$IMG,if=virtio \
        -fsdev local,id=fs1,path=${SHARE},security_model=none \
        -device virtio-9p-pci,fsdev=fs1,mount_tag=host-code \
        -s -S \
        -smp 1 \
        -nographic \
        -kernel ${KERNEL} \
        -append "root=/dev/vda1 console=ttyS0" \
        -net nic -net user,hostfwd=tcp::5555-:22 \
        -m size=4G \
        -vnc :0
    }

function vm_launch_graphical {
    check_lock
    # Launch VM with custom kernel
    ${KVM} -drive format=raw,file=${IMG},if=virtio \
        -fsdev local,id=fs1,path=${SHARE},security_model=none \
        -device virtio-9p-pci,fsdev=fs1,mount_tag=host-code \
        -kernel arch/x86_64/boot/bzImage \
        -append "root=/dev/vda1" \
        -netdev user,id=network0 \
        -device e1000,netdev=network0,mac=52:54:00:12:34:56 \
        -redir tcp:5555::22 \
        -vga virtio \
        -usb -device usb-tablet \
        -m size=4G
    }

trap finish INT

case "${1-}" in
    mount)
        vm_mount "${@}"
        ;;
    umount)
        vm_umount
        ;;
    install)
        vm_mount
        make modules_install install INSTALL_MOD_PATH=$MNT INSTALL_PATH=$MNT
        vm_umount
        ;;
    modinstall)
        vm_mount
        make modules_install INSTALL_MOD_PATH=$MNT
        vm_umount
        ;;
    launch)
        vm_launch
        ;;
    fai)
        vm_launch_fai
        ;;
    debug)
        vm_launch_debug
        ;;
    run)
        vm_launch_graphical
        ;;
    launch-native)
        vm_launch_native
        ;;
    create-raw)
        create_img
        config_img
        ;;
    config-raw)
        config_img
        ;;
    *)
        echo "Usage: $0 {mount|umount|install|modinstall|launch|debug|launch-native|run|create-raw|config_img}"
        echo "Requirements: libguestfs-tools ${KVM} vmdebootstrap"
        exit 1
esac
