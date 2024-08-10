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

# Configuration
USBPORT1_PATH_TAG_USB2="platform-xhci-hcd_1-usb-0_1_3_1_0-scsi-0_0_0_0"
USBPORT1_PATH_TAG_USB3="platform-xhci-hcd_1-usb-0_1_1_0-scsi-0_0_0_0"
USBPORT2_PATH_TAG_USB2="platform-xhci-hcd_1-usb-0_1_2_1_0-scsi-0_0_0_0"
USBPORT2_PATH_TAG_USB3="platform-xhci-hcd_0-usb-0_1_1_0-scsi-0_0_0_0"
MOUNT_POINT="/mnt/destination"
LOGFILE="/var/log/copy_usb.log"

# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOGFILE
}

cleanup() {
    log "Starting cleanup..."
    if mountpoint -q "$MOUNT_POINT"; then
        umount "$MOUNT_POINT"
        log "Unmounted $MOUNT_POINT"
    fi
    rm -f /dev/source_disk /dev/destination_disk /dev/destination_disk1 $MOUNT_POINT
    log "Removed symlinks"
    log "Cleanup completed"
}

get_block_device_path() {
    local path_tag_usb2=$1
    local path_tag_usb3=$2
    for device in $(lsblk -lno NAME,TYPE | grep -E "\<disk\>" | awk '{print $1}'); do
        if udevadm info --query=all --name="/dev/$device" | grep -qE "ID_PATH_TAG=$path_tag_usb2|ID_PATH_TAG=$path_tag_usb3"; then
            echo "/dev/$device"
            return
        fi
    done
}

create_symlink() {
    local device=$1
    local link_name=$2
    ln -sf "$device" "$link_name"
    log "Created symbolic link: $link_name -> $device"
}

mount_destination() {
    if [ ! -d "$MOUNT_POINT" ]; then
        mkdir -p "$MOUNT_POINT"
        log "Created mount point: $MOUNT_POINT"
    fi
    if ! mountpoint -q "$MOUNT_POINT"; then
        mount -t exfat /dev/destination_disk1 "$MOUNT_POINT"
        log "Mounted /dev/destination_disk1 to $MOUNT_POINT"
    else
        log "$MOUNT_POINT is already mounted."
    fi
}

# Main script execution
main() {
    log "Script started"
    
    # Run cleanup before starting
    cleanup
    
    log "Finding source device..."
    SOURCE_DEVICE=$(get_block_device_path "$USBPORT1_PATH_TAG_USB2" "$USBPORT1_PATH_TAG_USB3")
    log "Source device found: $SOURCE_DEVICE"
    
    log "Finding destination device..."
    DESTINATION_DEVICE=$(get_block_device_path "$USBPORT2_PATH_TAG_USB2" "$USBPORT2_PATH_TAG_USB3")
    log "Destination device found: $DESTINATION_DEVICE"

    if [ -z "$SOURCE_DEVICE" ] || [ -z "$DESTINATION_DEVICE" ]; then
        log "Error: One or both devices not found."
        exit 1
    fi

    create_symlink "$SOURCE_DEVICE" "/dev/source_disk"
    create_symlink "$DESTINATION_DEVICE" "/dev/destination_disk"

    DESTINATION_PARTITION=$(lsblk -lno NAME,TYPE | grep -E "^${DESTINATION_DEVICE##*/}[0-9]" | awk '{print $1}' | tail -n 1)
    if [ -z "$DESTINATION_PARTITION" ]; then
        log "Error: Destination partition not found."
        exit 1
    fi

    create_symlink "/dev/$DESTINATION_PARTITION" "/dev/destination_disk1"

    if [ -L /dev/source_disk ] && [ -L /dev/destination_disk ] && [ -L /dev/destination_disk1 ]; then
        log "All symbolic links created successfully. Running imager script..."
        mount_destination
        if mountpoint -q "$MOUNT_POINT"; then
            log "Starting imager.sh"
            /usr/local/bin/imager.sh
            IMAGER_EXIT_CODE=$?
            log "imager.sh completed with exit code $IMAGER_EXIT_CODE"
            
            if [ $IMAGER_EXIT_CODE -eq 0 ]; then
                log "Imaging completed successfully. Unmounting..."
                cleanup
            else
                log "Error: imager.sh failed with exit code $IMAGER_EXIT_CODE"
                cleanup
                exit 1
            fi
        else
            log "Error: Failed to mount the destination partition."
            cleanup
            exit 1
        fi
    else
        log "Error: One or both USB sticks are missing or not recognized."
        cleanup
        exit 1
    fi
    rm -rf $MOUNT_POINT
}

# Run the main function
main