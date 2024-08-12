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
LOG_FILE="/var/log/handler.log"
CONFIG_FILE="/mnt/usb/Imager_config.yaml"
LCD_WRITE_SCRIPT="/usr/local/bin/lcd-write.sh"

# Functions
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

get_upload_method() {
    if [ -f "$CONFIG_FILE" ] && command -v yq &> /dev/null; then
        yq eval '.system.upload_method' "$CONFIG_FILE"
    else
        echo ""
    fi
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

lcd_write() {
    if [ -x "$LCD_WRITE_SCRIPT" ]; then
        $LCD_WRITE_SCRIPT "$1" > /dev/null 2>&1
    else
        echo "LCD message (not displayed): $1"
    fi
}

run_imager_script() {
    if [ -x "$1" ]; then
        "$1"
        return $?
    else
        log_message "Error: Script $1 not found or not executable"
        return 1
    fi
}

mount_nfs_share() {
    local nfs_server=$(yq eval '.system.nfs-config.server' "$CONFIG_FILE")
    local nfs_share=$(yq eval '.system.nfs-config.share' "$CONFIG_FILE")
    local mount_point=$(yq eval '.system.nfs-config.mount_point' "$CONFIG_FILE")

    if [ ! -d "$mount_point" ]; then
        sudo mkdir -p "$mount_point"
    fi

    if ! mountpoint -q "$mount_point"; then
        sudo mount -t nfs "$nfs_server:$nfs_share" "$mount_point"
        if [ $? -eq 0 ]; then
            log_message "Mounted NFS share $nfs_server:$nfs_share to $mount_point"
        else
            log_message "Failed to mount NFS share $nfs_server:$nfs_share"
            return 1
        fi
    fi
}

# Main execution
main() {
    UPLOAD_METHOD=$(get_upload_method)
    log_message "Upload method: $UPLOAD_METHOD"
    SOURCE_DEVICE=$(get_block_device_path "$USBPORT1_PATH_TAG_USB2" "$USBPORT1_PATH_TAG_USB3")
    DESTINATION_DEVICE=$(get_block_device_path "$USBPORT2_PATH_TAG_USB2" "$USBPORT2_PATH_TAG_USB3")

    case "$UPLOAD_METHOD" in
        "s3")
            lcd_write "     4n6pi \n S3-MODE"
            if [ -n "$SOURCE_DEVICE" ]; then
                if run_imager_script "/usr/local/bin/s3-imager.sh"; then
                    log_message "s3-imager.sh completed successfully"
                else
                    log_message "Error: s3-imager.sh failed"
                    lcd_write "     ERROR \n S3 IMAGER FAIL"
                fi
            else
                log_message "USB port 1 is not connected for S3 mode"
                lcd_write "     ERROR \n NO SOURCE USB"
            fi
            ;;
        "disk")
            lcd_write "     4n6pi \n IMAGE TO DISK "
            if [ -n "$SOURCE_DEVICE" ] && [ -n "$DESTINATION_DEVICE" ]; then
                if run_imager_script "/usr/local/bin/disk_mount.sh"; then
                    log_message "disk_mount.sh completed successfully"
                else
                    log_message "Error: disk_mount.sh failed"
                    lcd_write "     ERROR \n COPY FAILED"
                fi
            else
                log_message "Both USB ports are not connected. USB port 1: $SOURCE_DEVICE, USB port 2: $DESTINATION_DEVICE"
                lcd_write "     ERROR \n USB MISSING"
            fi
            ;;
        "nfs")
            lcd_write "     4n6pi \n NFS-TARGET MODE"
            if [ -n "$SOURCE_DEVICE" ]; then
                if mount_nfs_share; then
                    log_message "Starting nfs-imager.sh, USB port 1 connected and mounted, NFS share mounted"
                    run_imager_script "/usr/local/bin/nfs-imager.sh"
                else
                    log_message "Failed to mount NFS share"
                    lcd_write "  NFS ERROR \n MOUNT FAILED "
                fi
            else
                log_message "USB port 1 is not connected for NFS-target mode"
                lcd_write "  USB ERROR \n NOT CONNECTED"
            fi
            ;;
        *)
            log_message "Unknown upload method or config file not found"
            lcd_write "     ERROR \n UNKNOWN MODE "
            ;;    
    esac
}

# Run the main function
main
