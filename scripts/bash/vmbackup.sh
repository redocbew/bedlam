#!/usr/bin/bash

: '
Collect VM disk images and configuration and copy them elsewhere for easier backup.
'

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

  mkdir -p /tank/vmbackups/$vm;
  virsh dumpxml $vm > /tank/vmbackups/$vm/$vm.xml;

  if [ $israw = 1 ]; then
    qemu-img convert -f raw -O qcow2 $vmdisk /tank/vmbackups/$vm/$vm.qcow2;
  else
    cp $vmdisk /tank/vmbackups/$vm/$vm.qcow2;
  fi

  if [ "$startvm" = true ]; then
    virsh start $vm;
  fi
done
