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

LOGFILE="/var/log/4n6pi/acquire-$(date '+%Y%m%d%H%M%S').log"
USB_MOUNT_PATH="/mnt/usb"
YAML_FILE="$USB_MOUNT_PATH/Imager_config.yaml"
LED_PATH="/sys/class/leds/ACT/brightness"
GPIO_PIN_LED=5
GPIO_PIN_OK=6
SEGMENT_SIZE="2199023255552"
LCD_WRITE_SCRIPT="/usr/local/bin/lcd-write.sh"

# Ensure logging directory exists
mkdir -p "$(dirname "$LOGFILE")"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE" 2>&1
}

lcd_write() {
    if [ -x "$LCD_WRITE_SCRIPT" ]; then
        "$LCD_WRITE_SCRIPT" "$1" "$2" > /dev/null 2>&1
    else
        echo "LCD: $1"
    fi
}

led_control() {
    echo "$1" | sudo tee "$LED_PATH" > /dev/null
}

blink_led() {
    local interval=$1
    while true; do
        led_control 1
        gpio -g write $GPIO_PIN_LED 1
        sleep "$interval"
        led_control 0
        gpio -g write $GPIO_PIN_LED 0
        sleep "$interval"
    done
}

static_led_ok() {
    led_control 1
    gpio -g write $GPIO_PIN_OK 1
    sleep 5
    led_control 0
    gpio -g write $GPIO_PIN_OK 0
}

make_device_readonly() {
    hdparm -r1 "$1" >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to set $1 to read-only mode."
        lcd_write "ACQUISITION ABORTED" true
        exit 1
    fi
}

acquire_image() {
    ewfacquire -C "$CASE_NUMBER" -E "$EVIDENCE_NUMBER" -D "$DESCRIPTION" \
               -e "$EXAMINER_NAME" -u -t "$1" -S "$SEGMENT_SIZE" "$DEVICE" >> "$LOGFILE" 2>&1
    return $?
}

process_disk_mode() {
    lcd_write "ACQUIRING IMAGE \n IN PROGRESS" true
    if acquire_image "$DESTINATION"; then
        log "SUCCESS: Acquired image for $DEVICE"
        lcd_write "DISKMODE \n SUCCESS" true
        lcd_write "sha256sum \n IN PROGRESS" true
        sha256sum "$DESTINATION.E01" > "$DESTINATION.E01.sha256"
        log "SHA256: $(cat "$DESTINATION.E01.sha256")"
        lcd_write "DISKMODE \n SUCCESS" true
        return 0
    else
        lcd_write "DISKMODE \n ERROR" true
        log "ERROR: Acquisition failed for $DEVICE"
        return 1
    fi
}

main() {
    trap '[[ -n "$BLINK_LED_PID" ]] && kill "$BLINK_LED_PID" 2>/dev/null' EXIT

    gpio -g mode $GPIO_PIN_LED out
    gpio -g mode $GPIO_PIN_OK out
    gpio -g write $GPIO_PIN_OK 0

    DEVICE=$(yq e '.imager-config.device' "$YAML_FILE")
    DEST_DIR=$(yq e '.imager-config.destination_dir' "$YAML_FILE")
    IMAGE_NAME=$(yq e '.imager-config.image_name' "$YAML_FILE")
    DESTINATION="$DEST_DIR/$IMAGE_NAME"
    CASE_NUMBER=$(yq e '.imager-config.case_number' "$YAML_FILE")
    EVIDENCE_NUMBER=$(yq e '.imager-config.evidence_number' "$YAML_FILE")
    EXAMINER_NAME=$(yq e '.imager-config.examiner_name' "$YAML_FILE")
    DESCRIPTION=$(yq e '.imager-config.description' "$YAML_FILE")

    [[ -z "$DEVICE" || -z "$DEST_DIR" || -z "$IMAGE_NAME" ]] && {
        log "ERROR: Required fields missing in YAML."
        lcd_write "INVALID CONFIG" true
        exit 1
    }

    make_device_readonly "$DEVICE"
    log "Imaging started for device $DEVICE"
    blink_led 0.1 &
    BLINK_LED_PID=$!

    process_disk_mode
    if [ $? -eq 0 ]; then
        static_led_ok
        log "Imaging complete: $DESTINATION.E01"
    else
        gpio -g write 26 1
        exit 1
    fi
}

main
