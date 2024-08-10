#!/bin/bash
# 4n6pi - Forensic Imager for Raspberry Pi
# Copyright (C) 2024 plonxyz
# https://github.com/plonxyz/4n6pi
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Root check
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

echo "While creating the config stick, it'll be formatted to FAT32"
read -p "Enter the disk-partition (e.g., sda1, sdb1, sdc1): " DISK
if [ ! -b /dev/$DISK ]; then
  echo "Disk /dev/$DISK does not exist."
  exit 1
fi
umount /dev/${DISK}* 2>/dev/null
echo "Formatting /dev/$DISK as FAT32..."
mkfs.vfat -F 32 /dev/$DISK
UUID="937C-8BC2"
echo "Setting UUID..."
printf "\x${UUID:7:2}\x${UUID:5:2}\x${UUID:2:2}\x${UUID:0:2}" \
| dd bs=1 seek=67 count=4 conv=notrunc of=/dev/$DISK
MOUNT_POINT="/mnt/usb"
mkdir -p $MOUNT_POINT
mount /dev/$DISK $MOUNT_POINT
echo "Writing configuration to the disk..."
cat <<EOL | tee $MOUNT_POINT/Imager_config.yaml > /dev/null
imager-config:
  base_path: "/home/pi" #needed for s3-mode only, image will be created and pushed to s3
  image_name: "IMAGE" #name of the .E01
  case_number: "1234"
  evidence_number: "001"
  examiner_name: "John Doe"
  description: "Automated Acquisition"
  
system:
  upload_method: "disk" # s3 or disk or nfs
  network-config:
    SSID: "SSID"
    Password: "PASSWORD"
    
  ssh-keys: |  
    ssh-rsa AAAAB
    ssh-rsa AAAAB3
    
  s3-config:
    access-key: "ACCESSKEY"
    secret-key: "SECRETKEY"
    s3-server: "S3-SERVER"
    bucketname: "BUCKETNAME"
    bucketlocation: "na" # set bucketlocation if needed
    use-https: "True" #or False
    
  nfs-config:
    server: "nfs-server"
    share: "share-path"
    mount_point: /mnt/nfs-share


EOL
# Unmount the disk
umount $MOUNT_POINT
sleep 5
# Cleanup
rmdir $MOUNT_POINT
echo "Stick setup completed successfully."
