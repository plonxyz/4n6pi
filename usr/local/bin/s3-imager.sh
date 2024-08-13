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
USB_MOUNT_PATH="/mnt/usb"
YAML_FILE="$USB_MOUNT_PATH/Imager_config.yaml"
S3_CONFIG_FILE="/root/.s3cfg"
SEGMENT_SIZE="2199023255552"
LCD_WRITE_SCRIPT="/usr/local/bin/lcd-write.sh"

# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $RUN_ID - $1" >> $LOGFILE 2>&1
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

acquire_image() {
    ewfacquire -C "$CASE_NUMBER" -E "$EVIDENCE_NUMBER" -D "$DESCRIPTION" \
               -e "$EXAMINER_NAME" -u -t "$IMAGE_PATH" -S "$SEGMENT_SIZE" "$DEVICE" >> "$LOGFILE" 2>&1
}

upload_to_s3() {
    s3cmd put "$IMAGE_PATH.E01" "s3://$BUCKET_NAME/" >> "$LOGFILE" 2>&1
}
lcd_write() {
    if [ -x "$LCD_WRITE_SCRIPT" ]; then
        $LCD_WRITE_SCRIPT "$1" "$2" > /dev/null 2>&1
    else
        echo "LCD message (not displayed): $1"
    fi
}
# Main execution
main() {
    RUN_ID=$(date '+%Y%m%d%H%M%S')
    log "Script started"

    gpio -g mode $GPIO_PIN_LED out
    gpio -g mode $GPIO_PIN_OK out
    gpio -g write $GPIO_PIN_OK 0

    SOURCE_DEVICE=$(get_block_device_path "$USBPORT1_PATH_TAG_USB2" "$USBPORT1_PATH_TAG_USB3")
    log "Source device found: $SOURCE_DEVICE"

    if [ -z "$SOURCE_DEVICE" ]; then
        log "No source device found. Aborting."
        lcd_write "   NO SOURCE\n  DEVICE FOUND "
        exit 1
    fi

    DEVICE="$SOURCE_DEVICE"
    IMAGE_NAME=$(yq e '.imager-config.image_name' $YAML_FILE)
    BASE_PATH=$(yq e '.imager-config.base_path' $YAML_FILE)
    IMAGE_PATH="${BASE_PATH}/${IMAGE_NAME}"
    BUCKET_NAME=$(yq e '.system.s3-config.bucketname' $YAML_FILE)
    CASE_NUMBER=$(yq e '.imager-config.case_number' $YAML_FILE)
    EVIDENCE_NUMBER=$(yq e '.imager-config.evidence_number' $YAML_FILE)
    EXAMINER_NAME=$(yq e '.imager-config.examiner_name' $YAML_FILE)
    DESCRIPTION=$(yq e '.imager-config.description' $YAML_FILE)

    if [ -f "$S3_CONFIG_FILE" ]; then
        lcd_write "ACQUIRE S3-MODE \n  IN PROGRESS  " true
        blink_led 0.1 &
        BLINK_LED_PID=$!

        if acquire_image; then
            log "Successfully acquired image for $DEVICE, starting upload to s3 Bucket $BUCKET_NAME"
            lcd_write "   UPLOAD S3\n  IN PROGRESS  " true
            if upload_to_s3; then
                lcd_write "   UPLOAD S3\n   SUCCESSFUL  " true
                log "Successfully uploaded image for $IMAGE_PATH.E01 to S3 bucket $BUCKET_NAME"
                rm -rf "$IMAGE_PATH.E01"
            else
                lcd_write "   UPLOAD S3\n     FAILED    " true
                log "Failed to upload image for $IMAGE_PATH.E01 to S3 bucket $BUCKET_NAME"
                exit 1
            fi
        else
            log "Failed to acquire image for $DEVICE"
            kill "$BLINK_LED_PID"
            gpio -g write $GPIO_PIN_LED 0
            lcd_write "  ACQUISITION\n     FAILED    " true
            exit 1
        fi

        kill "$BLINK_LED_PID"
        gpio -g write $GPIO_PIN_LED 0
        static_led_ok
        echo "DONE"
    else
        lcd_write "   S3 CONFIG\n   NOT FOUND   "
        log "s3 config file not found. abort"
        exit 1
    fi
}

# Run the main function
main
