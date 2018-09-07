#!/bin/bash

set -eux

if [[ ! -d arch ]]; then
  echo "ERROR: This script should be executed in a linux directory"
  exit 1
fi

DIST=sid
IMG=../deb-${DIST}-vm.img
MNT=../deb-${DIST}-vm-mount.dir
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
  guestmount -a ${IMG} -i ${MNT}
  local SUCCESS=$?
  if (( $SUCCESS == 0 ))
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
  if (( $SUCCESS == 0 ))
  then
    echo "$IMG umounted from ${MNT}"
    rm -f $LOCK_FILE
    echo "Lock file removed"
  else
    echo "Something wrong happened when umounting ${MNT}"
  fi
}

function create_img {
  if [[ -f ${IMG} ]]; then
    echo "${IMG} already exists, nothing to do"
    exit 1
  fi

  sudo vmdebootstrap --verbose --image=${IMG} --size=10g --distribution=${DIST} --grub --enable-dhcp --package=${PKGS} --owner=$USER
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
  ${KVM} -hda $IMG \
    -fsdev local,id=fs1,path=${SHARE},security_model=none \
    -device virtio-9p-pci,fsdev=fs1,mount_tag=host-code \
    -net nic -net user,hostfwd=tcp::5555-:22 \
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
    -m size=4G
}

function vm_launch_graphical {
  check_lock
  # Launch VM with custom kernel
  ${KVM} -drive format=raw,file=${IMG},if=virtio \
    -fsdev local,id=fs1,path=${SHARE},security_model=none \
    -device virtio-9p-pci,fsdev=fs1,mount_tag=host-code \
    -kernel arch/x86_64/boot/bzImage \
    -append "root=/dev/vda1" \
    -device e1000,netdev=net0 \
    -net nic -net user,hostfwd=tcp::5555-:22 \
    -m size=4G
}

case "${1-}" in
  mount)
    vm_mount
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
    echo "Usage: $0 {mount|umount|install|modinstall|launch|launch-native|run|create-raw|config_img}"
    echo "Requirements: libguestfs-tools ${KVM} vmdebootstrap"
    exit 1
esac
