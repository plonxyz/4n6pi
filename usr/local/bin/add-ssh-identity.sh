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

yaml_file="/mnt/usb/Imager_config.yaml"
authorized_keys_file="/home/pi/.ssh/authorized_keys"
# Check if the YAML file exists
if [ ! -f "$yaml_file" ]; then
  echo "Imager-config.yaml not found."
  exit 1
fi

# Ensure the authorized_keys file exists
if [ ! -f "$authorized_keys_file" ]; then
  mkdir /home/pi/.ssh
  chown pi:pi /home/pi/.ssh
  chmod 700 /home/pi/.ssh
  touch "$authorized_keys_file"
  chown pi:pi "$authorized_keys_file"
  chmod 600 "$authorized_keys_file"
fi
authorized_keys_file="/home/pi/.ssh/authorized_keys"
# Extract the ssh-keys field as a multiline string
ssh_keys=$(yq e '.system."ssh-keys"' "$yaml_file")

# Check if ssh_keys variable is empty
if [ -z "$ssh_keys" ]; then
  echo "No SSH keys found in the .system.ssh-keys field."
else
  # Check if each SSH key is already in the authorized_keys file
  while IFS= read -r key; do
    if grep -qF "$key" "$authorized_keys_file"; then
      echo "Key already present: $key"
    else
      echo "$key" >> "$authorized_keys_file"
      echo "Added key to $authorized_keys_file: $key"
    fi
  done <<< "$ssh_keys"
fi
