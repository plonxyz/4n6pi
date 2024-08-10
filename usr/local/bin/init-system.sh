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
LED_PATH="/sys/class/leds/ACT/brightness"
YAML_FILE="/mnt/usb/Imager_config.yaml"
LCD_WRITE_SCRIPT="/usr/local/bin/lcd-write.sh"

# Functions
led_control() {
    echo "$1" | sudo tee $LED_PATH > /dev/null
}

check_ethernet_connection() {
    nmcli -t -f TYPE,STATE connection show --active | grep "802-3-ethernet:activated"
}
lcd_write() {
    if [ -x "$LCD_WRITE_SCRIPT" ]; then
        $LCD_WRITE_SCRIPT "$1" > /dev/null 2>&1
    else
        echo "LCD message (not displayed): $1"
    fi
}

setup_ethernet() {
    local ip=$(ip addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
    lcd_write "   LAN active \n $ip"
    led_control 0
    gpio -g write 26 0
    gpio -g mode 6 out
    gpio -g write 6 1
}

setup_wifi() {
    local ssid=$(yq e '.system.network-config.SSID' $YAML_FILE)
    local password=$(yq e '.system.network-config.Password' $YAML_FILE)

    if [[ -z "$ssid" || -z "$password" ]]; then
        echo "Error: SSID or Password is missing in the YAML file."
        return 1
    fi

    nmcli dev wifi connect "$ssid" password "$password"
    if [[ $? -eq 0 ]]; then
        nmcli connection modify "$ssid" connection.autoconnect no
        local ip=$(ip addr show wlan0 | awk '/inet / {print $2}' | cut -d/ -f1)
        lcd_write "  WLAN active \n $ip"
        gpio -g write 26 0
        gpio -g mode 6 out
        gpio -g write 6 1
        led_control 0
        echo "Successfully connected to $ssid."
    else
        echo "Failed to connect to $ssid."
        gpio -g mode 26 out
        gpio -g write 26 1
        return 1
    fi
}

# Main script execution
main() {
    # Ensure NetworkManager is running
    sudo rm -rf /etc/NetworkManager/system-connections/*
    sudo rm -rf /root/.s3cfg
    sudo systemctl start NetworkManager
    sleep 8

    if check_ethernet_connection; then
        echo "Ethernet connection is active. No need to connect to Wi-Fi."
        setup_ethernet
    else
        echo "Waiting for Wi-Fi networks to be scanned..."
        sleep 10
        setup_wifi
    fi

    /usr/local/bin/add-ssh-identity.sh
    /usr/local/bin/connect_wireguard.sh
    /usr/local/bin/init-destination.sh
    lcd_write "     4n6pi \n SYSTEM READY"
    led_control 1

}

# Run the main function
main
