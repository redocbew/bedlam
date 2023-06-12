#!/usr/bin/bash

: '
Collect VM disk images and configuration and copy them elsewhere for easier backup.
'

# 1. Copy vm configuration and images to a single location on local storage for easier backup
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

  mkdir -p /tank/vmbackup/$vm;
  virsh dumpxml $vm > /tank/vmbackup/$vm/$vm.xml;

  if [ $israw = 1 ]; then
    qemu-img convert -f raw -O qcow2 $vmdisk /tank/vmbackup/$vm/$vm.qcow2;
  else
    cp $vmdisk /tank/vmbackup/$vm/$vm.qcow2;
  fi

  if [ "$startvm" = true ]; then
    virsh start $vm;
  fi
done

# 2. Create a new snapshot, and prune old snapshots so they don't get out of hand.
now="$(date +'%m-%d-%Y-%H-%M')"
newsnapshot="weekly-${now}"

zfs snapshot tank/vmbackup@$newsnapshot

keep=8
num_snaps=$(zfs list -t snapshot -o name -S creation | uniq | wc -l)
num_snaps="$((num_snaps-1))"
printf "Found %d snapshots. Configured to keep %d.\n" $num_snaps $keep
if [[ $num_snaps -le $keep ]]; then
    printf "no need to prune.\n"
    exit 0
fi

num_to_prune=$(( num_snaps - keep ))
if [[ $num_to_prune -le 0 ]]; then
    printf "Error - no snapshots to prune.\n"
    exit 127
fi

if [[ $num_to_prune -ge $num_snaps ]]; then
    printf "Error - won't remove all snapshots.\n"
    exit 127
fi

# I only have one pool at the moment which requires snapshotting.  This will need revision should that change.
for snapshot in $(zfs list -t snapshot -o name -S creation | uniq | tail -n $num_to_prune); do
    zfs destroy $snapshot
done

# 3. Wait for the NAS to pick up the new snapshot in its replication task.
# 4. Be happy.  :)
