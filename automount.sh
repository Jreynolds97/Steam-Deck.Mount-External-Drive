#!/bin/bash
#Steam Deck Mount External Drive by scawp
#License: DBAD: https://github.com/jreynolds97/Steam-Deck.Mount-External-Drive/blob/main/LICENSE.md
#Source: https://github.com/jreynolds97/Steam-Deck.Mount-External-Drive
# Use at own Risk!
urlencode() {
  /usr/bin/python3 -c "import urllib.parse; print(urllib.parse.quote(input()))" <<< $1
}

unmount_drive() {
  label="$(lsblk -l -noLABEL $1)"
  if [ -z "$label" ]; then
    label="$(lsblk -l -noUUID $1)"
  fi

  if [ -d "/run/media/[[USER]]/$label" ]; then
    umount "/run/media/[[USER]]/$label"
    rmdir "/run/media/[[USER]]/$label"
  fi
}

mount_drive() {
  label="$(lsblk -l -noLABEL $1)"
  fs_type="$(lsblk -l -noFSTYPE $1)"

  if [ -z "$label" ]; then
    label="$(lsblk -l -noUUID $1)"
    echo "No label found, using UUID as label"
  fi

  # Check if the drive is already mounted
  mount_point="$(lsblk -l -noMOUNTPOINT $1)"
  if [ ! -z "$mount_point" ]; then
    echo "Drive $1 is already mounted at $mount_point"
    return 0
  fi

  # Create the mount directory and set permissions
  mkdir -p "/run/media/[[USER]]/$label"
  chown [[USER]]:[[USER]] "/run/media/[[USER]]"
  chown [[USER]]:[[USER]] "/run/media/[[USER]]/$label"

  # Mount the drive
  if [ "$fs_type" = "ntfs" ]; then
    echo "Attempting to mount as NTFS using lowntfs-3g"
    mount.lowntfs-3g "$1" "/run/media/[[USER]]/$label" -ouid=1000,gid=1000,user
  elif [ "$fs_type" = "btrfs" ]; then
      echo "Attempting to mount as BTRFS with compression"
      mount -t btrfs -o defaults,compress=zstd "$1" "/run/media/[[USER]]/$label"
  else
    echo "Attempting to mount as $fs_type"
    mount "$1" "/run/media/[[USER]]/$label"
  fi

  # Check if the mount was successful
  mount_point="$(lsblk -l -noMOUNTPOINT $1)"
  if [ -z "$mount_point" ];then
    echo "Failed to mount $1 at /run/media/[[USER]]/$label"
  else
    echo "Mounted $1 at $mount_point"
    mount_point="$mount_point/SteamLibrary"
    echo "$mount_point"

    url=$(urlencode "${mount_point}")

    echo "$url"
    if pgrep -x "steam" > /dev/null; then
        systemd-run -M 1000@ --user --collect --wait sh -c "steam steam://addlibraryfolder/${url@Q}"
    fi
  fi
}

if [ "$1" = "remove" ]; then
  unmount_drive "/dev/$2"
else
# Get a list of all external drives
external_drives=$(lsblk -l | awk '/^sd[a-z]/ && $7 == "" {print $1}')

# Iterate through all external drives
for drive in $external_drives; do
  # Call the mount_drive function for each drive
  mount_drive "/dev/$drive"
done
fi

exit 0

