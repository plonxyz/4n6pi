
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

# Define the source and destination paths
SOURCE_PATH="/mnt/usb/wg0.conf"
DEST_PATH="/etc/wireguard/wg0.conf"

# Check if the wg0.conf file exists in the source path
if [ -f "$SOURCE_PATH" ]; then
  echo "wg0.conf found, copying to $DEST_PATH"
  
  # Copy the file to the destination path
  cp "$SOURCE_PATH" "$DEST_PATH"
  
  # Start WireGuard
  echo "Starting WireGuard"
  wg-quick up wg0
else
  echo "wg0.conf not found, doing nothing"
fi
