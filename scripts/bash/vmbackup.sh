#!/usr/bin/bash

: '
Collect VM disk images and configuration and copy them elsewhere for easier backup.
'

if ! [[ $(findmnt -M "/media/backups") ]]; then
    mount -t nfs stockpile.home:/mnt/stockpile/backups /media/backups
fi

if ! [[ $(findmnt -M "/media/backups") ]]; then
    exit 1
fi

# Copy vm configuration and images to a single location on local storage for easier backup
for vm in $(virsh list --name --all)
do
  vmstate=$(virsh domstate $vm);
  startvm=false;

  if [[ $vmstate == "running" ]]; then
      virsh shutdown $vm;
      startvm=true;
  fi

  vmdisk=$(virsh domblklist $vm --details | awk '/disk/{print $4}');
  israw=$(echo $vmdisk | grep -c ^/dev/);

  virsh dumpxml $vm > /media/backups/$vm/$vm.xml;

  if [ $israw = 1 ]; then
    qemu-img convert -f raw -O qcow2 $vmdisk /media/backups/$vm/$vm.qcow2;
  else
    cp $vmdisk /media/backups/$vm/$vm.qcow2;
  fi

  if [ "$startvm" = true ]; then
    virsh start $vm;
  fi
done

