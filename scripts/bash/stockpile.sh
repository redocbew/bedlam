#!/bin/bash

# By Dan "redocbew" Fogle
# Automate network configuration on the laptop at boot
# Licensed under GPLv2

# Placed in /etc/network/if-up.d
# If I had to do this again I might just use systemd, but at least on Debian this works.

# mount shared network storage if available
if nc -z stockpile.home 22 2>/dev/null && !($(findmnt -M "/media/shared")); then
  mount -t cifs -o uid=redocbew,credentials=/home/redocbew/.smb,noperm //stockpile.home/shared /media/shared
fi
