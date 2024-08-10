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
LOGFILE="/var/log/acquire.log"
USB_MOUNT_PATH="/mnt/usb"
YAML_FILE="$USB_MOUNT_PATH/Imager_config.yaml"
LED_PATH="/sys/class/leds/ACT/brightness"
GPIO_PIN_LED=5
GPIO_PIN_OK=6
SEGMENT_SIZE="2199023255552"
LCD_WRITE_SCRIPT="/usr/local/bin/lcd-write.sh"

# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $RUN_ID - $1" >> $LOGFILE 2>&1
}

led_control() {
    echo "$1" | sudo tee $LED_PATH > /dev/null
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
    led_control 1
    gpio -g write $GPIO_PIN_OK 1
    sleep 5
    led_control 0
    gpio -g write $GPIO_PIN_OK 0
}

acquire_image() {
    ewfacquire -C "$CASE_NUMBER" -E "$EVIDENCE_NUMBER" -D "$DESCRIPTION" \
               -e "$EXAMINER_NAME" -u -t "$1" -S "$SEGMENT_SIZE" "$DEVICE" >> $LOGFILE 2>&1
}

lcd_write() {
    if [ -x "$LCD_WRITE_SCRIPT" ]; then
        $LCD_WRITE_SCRIPT "$1" "$2" > /dev/null 2>&1
    else
        echo "LCD message (not displayed): $1"
    fi
}

process_disk_mode() {
    lcd_write "ACQUIRE DISKMODE \n  IN PROGRESS  " true
    if acquire_image "$DESTINATION"; then
        log "Successfully acquired image for $DEVICE"
        lcd_write "ACQUIRE DISKMODE \n   SUCCESSFUL  " true
        log "Successfully saved image to $DESTINATION.E01 using copy-to-disk"
        return 0
    else
        lcd_write "ACQUIRE DISKMODE \n     ERROR     " true
        log "Failed to acquire image for $DEVICE"
        return 1
    fi
}

# Main execution
main() {
    RUN_ID=$(date '+%Y%m%d%H%M%S')
    
    # Initialize GPIO
    gpio -g write $GPIO_PIN_OK 0
    gpio -g mode $GPIO_PIN_LED out
    gpio -g mode $GPIO_PIN_OK out

    # Read configuration from YAML
    DEVICE="/dev/source_disk"
    DEVICE2="/mnt/destination"
    IMAGE_NAME=$(yq e '.imager-config.image_name' $YAML_FILE)
    MOUNT_POINT="${DEVICE2}/"
    DESTINATION="${MOUNT_POINT}/${IMAGE_NAME}"
    CASE_NUMBER=$(yq e '.imager-config.case_number' $YAML_FILE)
    EVIDENCE_NUMBER=$(yq e '.imager-config.evidence_number' $YAML_FILE)
    EXAMINER_NAME=$(yq e '.imager-config.examiner_name' $YAML_FILE)
    DESCRIPTION=$(yq e '.imager-config.description' $YAML_FILE)

    log "Script started for device: $DEVICE"
    log "Starting acquisition for device: $DEVICE"

    blink_led 0.1 &
    BLINK_LED_PID=$!

    process_disk_mode
    result=$?

    kill $BLINK_LED_PID
    gpio -g write $GPIO_PIN_LED 0

    if [ $result -eq 0 ]; then
        static_led_ok
        echo "DONE"
    else
        gpio -g write 26 1
        exit 1
    fi

    log "Imaged $DEVICE and saved to $DESTINATION.E01"
}

# Run the main function
main
