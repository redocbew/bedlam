#!/bin/bash

# Placed in /etc/network/if-up.d

# mount shared network storage if available
if nc -z stockpile.home 22 2>/dev/null; then
    mount -t cifs -o uid=redocbew,credentials=/home/redocbew/.smb,noperm //stockpile.home/shared /media/shared
fi

# disable network bridge when interface has no link
if /sbin/ethtool eno1 | grep -q "Link detected: no"; then
    ip link set dev br0 down
fi
