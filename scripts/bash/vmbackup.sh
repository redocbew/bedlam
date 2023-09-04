#!/usr/bin/bash

# By Dan "redocbew" Fogle
# Collect VM disk images and configuration and copy them elsewhere for easier backup.
# Licensed under GPLv2

# in case the backup share was already mounted for some other reason unmount it,
# and remount with nobrl. qemu-img requires this to play nice with CIFS
if [[ $(findmnt -M "/media/backups") ]]; then
  echo "unmounting backup share"
  # TODO: Collect params before unmounting so I can leave things how I found them?
  umount /media/backups
fi

echo "mounting with nobrl"
mount -t cifs -o uid=libvirt-qemu,credentials=/home/redocbew/.smb,nobrl //stockpile.home/backups /media/backups
if ! [[ $(findmnt -M "/media/backups") ]]; then
  echo "findmnt failed, exiting"
  exit 1
fi

for vm in $(virsh list --name --all)
do
  echo "beginning backup job for $vm"
  vmstate=$(virsh domstate $vm);
  startvm=false;

  if [[ $vmstate == "running" ]]; then
    virsh shutdown $vm;
    startvm=true;
  fi

  vmdisk=$(virsh domblklist $vm --details | awk '/disk/{print $4}');
  israw=$(echo $vmdisk | grep -c ^/dev/);
  echo "dumping xml"
  mkdir -p /media/backups/$vm
  virsh dumpxml $vm > /media/backups/$vm/$vm.xml;

  if [ $israw = 1 ]; then
    echo "writing disk image to backup share"
    qemu-img convert -f raw -O qcow2 $vmdisk /media/backups/$vm/$vm.qcow2;
  else
    echo "copying qcow2 to backup share"
    cp $vmdisk /media/backups/$vm/$vm.qcow2;
  fi

  if [ "$startvm" = true ]; then
    virsh start $vm;
  fi
done

# nobrl can cause more trouble than its worth if overused, so unmount share when we're done
echo "unmounting backup share"
umount /media/backups
