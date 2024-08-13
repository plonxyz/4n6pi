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
GPIO_PIN_LED=5
GPIO_PIN_OK=6
LED_PATH="/sys/class/leds/ACT/brightness"
LOGFILE="/var/log/acquire.log"
USBPORT1_PATH_TAG_USB2="platform-xhci-hcd_1-usb-0_1_3_1_0-scsi-0_0_0_0"
USBPORT1_PATH_TAG_USB3="platform-xhci-hcd_1-usb-0_1_1_0-scsi-0_0_0_0"
SEGMENT_SIZE="2199023255552"
LCD_WRITE_SCRIPT="/usr/local/bin/lcd-write.sh"

# Create log file and set permissions


# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $RUN_ID - $1" >> "$LOGFILE" 2>&1
}

led_control() {
    echo "$1" | sudo tee $LED_PATH > /dev/null
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

blink_led() {
    local interval=$1
    while true; do
        led_control 1
        gpio -g write $GPIO_PIN_LED 1
        sleep $interval
        led_control 0
        gpio -g write $GPIO_PIN_LED 0
        sleep $interval
    done
}

static_led_ok() {
    gpio -g write $GPIO_PIN_OK 1
    led_control 1
}
lcd_write() {
    if [ -x "$LCD_WRITE_SCRIPT" ]; then
        $LCD_WRITE_SCRIPT "$1" "$2" > /dev/null 2>&1
    else
        echo "LCD message (not displayed): $1"
    fi
}
update_lcd() {
    local acquired_gb=$1
    local total_gb=$2
    local speed=$3

    lcd_write "$(printf "ACQUIRE NFS-MODE \n %5s/%5s %7s" "${acquired_gb}" "${total_gb}" "${speed}")"
}

get_yaml_value() {
    local key=$1
    local value

    # Try the new structure first
    value=$(yq e ".system.$key" "$YAML_FILE")
    
    # If empty, try the old structure
    if [ -z "$value" ] || [ "$value" = "null" ]; then
        value=$(yq e ".$key" "$YAML_FILE")
    fi

    echo "$value"
}

mount_nfs() {
    local nfs_server=$(get_yaml_value "system.nfs-config.server")
    local nfs_share=$(get_yaml_value "system.nfs-config.share")
    local mount_point=$(get_yaml_value "system.nfs-config.mount_point")

    log "NFS Server: $nfs_server"
    log "NFS Share: $nfs_share"
    log "Mount Point: $mount_point"

    if [ -z "$nfs_server" ] || [ -z "$nfs_share" ] || [ -z "$mount_point" ]; then
        log "NFS configuration is incomplete in YAML file"
        lcd_write "ACQUIRE NFS-MODE\nCONFIG ERROR"
        return 1
    fi

    # Always attempt to create the mount point
    log "Attempting to create mount point directory: $mount_point"
    mkdir_output=$(sudo mkdir -p "$mount_point" 2>&1)
    mkdir_status=$?
    log "mkdir command output: $mkdir_output"
    log "mkdir command exit status: $mkdir_status"

    if [ $mkdir_status -ne 0 ]; then
        log "Failed to create mount point directory"
        lcd_write "ACQUIRE NFS-MODE\nMNT DIR FAILED"
        return 1
    fi
    log "Mount point directory created or already exists"

    # Check if already mounted
    if mountpoint -q "$mount_point"; then
        log "NFS share already mounted at $mount_point"
        return 0
    fi

    log "Mounting NFS share $nfs_server:$nfs_share to $mount_point"
    lcd_write "ACQUIRE NFS-MODE\nMOUNTING..."
    
    mount_output=$(sudo mount -t nfs "$nfs_server:$nfs_share" "$mount_point" 2>&1)
    mount_status=$?
    
    log "Mount command output: $mount_output"
    log "Mount command exit status: $mount_status"

    if [ $mount_status -ne 0 ]; then
        log "Failed to mount NFS share"
        lcd_write "ACQUIRE NFS-MODE\nMOUNT FAILED"
        return 1
    else
        log "Successfully mounted NFS share"
    fi

    return 0
}

acquire_image() {
    ewfacquire -C "$CASE_NUMBER" -E "$EVIDENCE_NUMBER" -D "$DESCRIPTION" \
               -e "$EXAMINER_NAME" -u -t "$NFS_IMAGE_PATH" -S "$SEGMENT_SIZE" "$DEVICE" 2>&1 | \
    while IFS= read -r line
    do
        echo "$line" | sudo tee -a "$LOGFILE"
        if [[ $line =~ Status:\ at\ ([0-9]+)% ]]; then
            acquired_gb=$(echo "$line" | grep -oP 'acquired \K[0-9.]+ GiB')
            total_gb=$(echo "$line" | grep -oP 'of total \K[0-9.]+ GiB')
            speed=$(echo "$line" | grep -oP '[0-9.]+ MiB/s')
            update_lcd "$acquired_gb" "$total_gb" "$speed"
        fi
    done
}

# Main execution
main() {
    RUN_ID=$(date '+%Y%m%d%H%M%S')
    YAML_FILE="/mnt/usb/Imager_config.yaml"
    log "Script started"

    gpio -g mode $GPIO_PIN_LED out
    gpio -g mode $GPIO_PIN_OK out
    gpio -g write $GPIO_PIN_OK 0

    SOURCE_DEVICE=$(get_block_device_path "$USBPORT1_PATH_TAG_USB2" "$USBPORT1_PATH_TAG_USB3")
    log "Source device found: $SOURCE_DEVICE"

    if [ -z "$SOURCE_DEVICE" ]; then
        log "No source device found. Aborting."
        lcd_write "NO SOURCE\nDEVICE FOUND"
        exit 1
    fi

    DEVICE="$SOURCE_DEVICE"

    if [ -z "$YAML_FILE" ]; then
        log "No USB drive with YAML file found. Aborting."
        lcd_write "NO CONFIG\nFILE FOUND"
        exit 1
    fi

    UPLOAD_METHOD=$(get_yaml_value "upload_method")
    IMAGE_NAME=$(get_yaml_value "imager-config.image_name")
    NFS_MOUNT_POINT=$(get_yaml_value "system.nfs-config.mount_point")
    NFS_IMAGE_PATH="${NFS_MOUNT_POINT}/${IMAGE_NAME}"
    CASE_NUMBER=$(get_yaml_value "imager-config.case_number")
    EVIDENCE_NUMBER=$(get_yaml_value "imager-config.evidence_number")
    EXAMINER_NAME=$(get_yaml_value "imager-config.examiner_name")
    DESCRIPTION=$(get_yaml_value "imager-config.description")
    log "Upload method: $UPLOAD_METHOD"
    log "Image name: $IMAGE_NAME"
    log "NFS mount point: $NFS_MOUNT_POINT"
    log "NFS image path: $NFS_IMAGE_PATH"

    if mount_nfs; then
        lcd_write "ACQUIRE NFS-MODE\nINITIALIZING..."
        blink_led 0.1 &
        BLINK_LED_PID=$!

        if acquire_image; then
            lcd_write "ACQUIRE NFS-MODE\nSUCCESSFUL"
            log "Successfully acquired image for $DEVICE directly to NFS mount $NFS_MOUNT_POINT"
        else
            log "Failed to acquire image for $DEVICE to NFS mount"
            kill "$BLINK_LED_PID"
            gpio -g write $GPIO_PIN_LED 0
            lcd_write "ACQUIRE NFS-MODE\nFAILED"
            exit 1
        fi

        kill "$BLINK_LED_PID"
        gpio -g write $GPIO_PIN_LED 0

        static_led_ok
        echo "DONE"
    else
        log "Failed to mount NFS share. Aborting."
        exit 1
    fi

    # Cleanup
    umount $NFS_MOUNT_POINT
    rm -rf $NFS_MOUNT_POINT
}

# Run the main function
main
